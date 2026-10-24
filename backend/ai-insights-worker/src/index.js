// PWESTADO AI Insights proxy (Cloudflare Worker).
//
// The phone app never holds the Gemini key. It POSTs minimal, structured
// evidence here; this Worker validates it, enforces abuse and spending
// limits, calls Gemini with a fixed prompt and JSON schema, validates the
// answer, and returns only that validated JSON.
//
// Bindings / settings (see wrangler.toml and README.md):
//   GEMINI_API_KEY   secret  (wrangler secret put GEMINI_API_KEY)
//   GEMINI_MODEL     var     default "gemini-3.1-flash-lite"
//   CLIENT_IDS       secret  optional comma list of accepted X-Pwestado-Client values
//   DAILY_LIMIT      var     max Gemini calls per UTC day (default 200)
//   USAGE            KV      daily counter (required: fails closed without it)
//   RATE_LIMITER     rate limit binding, per client IP (optional but recommended)

import { buildGeminiRequest } from './prompt.js';
import { LIMITS, ValidationError, validateInsight, validateRequest } from './validate.js';

export const DEFAULT_MODEL = 'gemini-3.1-flash-lite';
const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';
const GEMINI_TIMEOUT_MS = 20_000;
const MODEL_PATTERN = /^[a-z0-9.\-]{3,64}$/;

function json(status, body, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
      ...extraHeaders,
    },
  });
}

const error = (status, code, message, headers) => json(status, { error: { code, message } }, headers);

/** Constant-time string comparison for the optional client id check. */
function safeEqual(a, b) {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

function clientAllowed(request, env) {
  const ids = (env.CLIENT_IDS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (ids.length === 0) return true;
  const sent = request.headers.get('x-pwestado-client') ?? '';
  return ids.some((id) => safeEqual(sent, id));
}

async function hashIp(ip) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`pwestado:${ip}`));
  return [...new Uint8Array(digest).slice(0, 12)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Reserves one call in today's budget. Returns false when the cap is reached. */
async function reserveDailyCall(env, now) {
  const limit = Number.parseInt(env.DAILY_LIMIT ?? '200', 10);
  const key = `calls:${now.toISOString().slice(0, 10)}`;
  const used = Number.parseInt((await env.USAGE.get(key)) ?? '0', 10);
  if (!Number.isFinite(limit) || used >= limit) return false;
  // KV is eventually consistent, so this cap is approximate (it can overshoot
  // slightly under bursts). Google AI Studio's project spend cap is the hard
  // backstop; see README.
  await env.USAGE.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
  return true;
}

async function callGemini(evidence, env, fetchImpl) {
  const model = MODEL_PATTERN.test(env.GEMINI_MODEL ?? '') ? env.GEMINI_MODEL : DEFAULT_MODEL;
  const maxOutputTokens = Math.min(Number.parseInt(env.MAX_OUTPUT_TOKENS ?? '1024', 10) || 1024, 2048);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);
  let response;
  try {
    response = await fetchImpl(`${GEMINI_BASE}/${model}:generateContent`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
      body: JSON.stringify(buildGeminiRequest(evidence, { maxOutputTokens })),
      signal: controller.signal,
    });
  } catch (e) {
    if (e?.name === 'AbortError') return { failure: error(504, 'timeout', 'The AI took too long to answer.') };
    return { failure: error(502, 'upstream_unreachable', 'Could not reach the AI service.') };
  } finally {
    clearTimeout(timer);
  }

  // Upstream bodies are never forwarded: they are not part of our contract.
  if (response.status === 429) {
    return { failure: error(429, 'quota', 'The AI service quota is exhausted. Try again later.') };
  }
  if (response.status === 401 || response.status === 403) {
    console.log(`gemini auth failure ${response.status}`);
    return { failure: error(503, 'ai_misconfigured', 'AI Insights is temporarily unavailable.') };
  }
  if (!response.ok) {
    console.log(`gemini error ${response.status}`);
    return { failure: error(502, 'upstream_error', 'The AI service returned an error.') };
  }

  let text;
  try {
    const data = await response.json();
    const candidate = data?.candidates?.[0];
    if (candidate?.finishReason && !['STOP', 'MAX_TOKENS'].includes(candidate.finishReason)) {
      return { failure: error(502, 'invalid_output', 'The AI answer was blocked or incomplete.') };
    }
    text = candidate?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
    const insight = validateInsight(JSON.parse(text));
    return { insight, model };
  } catch {
    return { failure: error(502, 'invalid_output', 'The AI answer could not be validated.') };
  }
}

export async function handleRequest(request, env, deps = {}) {
  const fetchImpl = deps.fetch ?? fetch;
  const now = deps.now ?? new Date();
  const url = new URL(request.url);

  if (url.pathname === '/health' && request.method === 'GET') {
    return json(200, { ok: true });
  }
  if (url.pathname !== '/v1/insights') return error(404, 'not_found', 'Not found.');
  if (request.method !== 'POST') return error(405, 'method_not_allowed', 'Use POST.', { allow: 'POST' });

  if (!env.GEMINI_API_KEY || !env.USAGE) {
    // Fail closed: never call Gemini without the daily spending guard.
    return error(503, 'not_configured', 'AI Insights is not configured on the server.');
  }
  if (!clientAllowed(request, env)) return error(401, 'unauthorized', 'This client is not allowed.');

  const contentType = request.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    return error(415, 'unsupported_media_type', 'Send JSON.');
  }
  const declared = Number.parseInt(request.headers.get('content-length') ?? '0', 10);
  if (declared > LIMITS.maxBodyBytes) return error(413, 'too_large', 'Request too large.');

  if (env.RATE_LIMITER) {
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    const { success } = await env.RATE_LIMITER.limit({ key: await hashIp(ip) });
    if (!success) return error(429, 'rate_limited', 'Too many requests. Wait a minute.', { 'retry-after': '60' });
  }

  let evidence;
  try {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).length > LIMITS.maxBodyBytes) {
      return error(413, 'too_large', 'Request too large.');
    }
    evidence = validateRequest(JSON.parse(raw));
  } catch (e) {
    const message = e instanceof ValidationError ? e.message : 'Body is not valid JSON.';
    return error(400, 'bad_request', message);
  }

  if (!(await reserveDailyCall(env, now))) {
    return error(429, 'daily_limit', 'Daily AI limit reached. Try again tomorrow.');
  }

  const started = Date.now();
  const result = await callGemini(evidence, env, fetchImpl);
  console.log(`insights mode=${evidence.mode} ok=${!result.failure} ms=${Date.now() - started}`);
  if (result.failure) return result.failure;
  return json(200, { insight: result.insight, model: result.model, demo: evidence.demo });
}

export default {
  fetch: (request, env) => handleRequest(request, env),
};
