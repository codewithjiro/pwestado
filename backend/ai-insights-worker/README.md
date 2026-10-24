# PWESTADO AI Insights proxy

> **Not used by the app (October 2026).** For private demos the owner chose to
> call Gemini directly from the app with a local, untracked key (see the root
> README). This Worker is kept for reference if the app is ever shared beyond
> private demos, which would require moving the key back to a server.

A small Cloudflare Worker that lets the PWESTADO app ask Gemini to explain a location analysis **without the Gemini API key ever leaving the server**.

```
Phone app ──HTTPS──▶ Worker (/v1/insights) ──x-goog-api-key──▶ Gemini generateContent
          evidence only        validate · rate limit · daily cap · validate answer
```

## Why a proxy

An APK can be unpacked, so any key inside it (source, assets, `--dart-define`, `.env`) is public. The key lives only in the Worker's encrypted secret store. The app sends only structured evidence: counts, distances, the 40/30/30 score, the data source and the time it was retrieved. It never sends coordinates, business names, road names or anything about the user.

## What the Worker enforces

| Control | How |
|---|---|
| Secret handling | `GEMINI_API_KEY` set as a Wrangler secret, sent to Google only in the `x-goog-api-key` header, never logged or returned |
| Input allowlist | Strict schema (`src/validate.js`): known business types, radii, enums, numeric ranges. Unknown fields are dropped. 8 KB body cap |
| Prompt injection | The only free text is the area label (80 chars, stripped of `<>{}` and control characters), passed as JSON data under a system instruction that treats it as data |
| Evidence gate | Requests without a complete deterministic score are refused (no "creative" explanations of missing data) |
| Burst limit | Cloudflare Rate Limiting binding: 5 requests / 60 s per hashed client IP |
| Spending cap | Daily call ceiling (`DAILY_LIMIT`, default 200) in KV. **Fails closed**: without the KV binding, Gemini is never called |
| Output cap | `maxOutputTokens` (default 1024, max 2048), temperature 0.4, 20 s timeout |
| Output validation | Structured JSON via `responseMimeType` + `responseSchema`, then re-validated. Points with invented peso amounts, population/customer counts or guarantees are dropped. A quick assessment containing one rejects the whole answer |
| Optional client gate | `CLIENT_IDS` secret: comma list of accepted `X-Pwestado-Client` values. Easy to rotate, but extractable from the APK, so it is only a speed bump, not authentication |
| Error hygiene | Upstream error bodies are never forwarded. The app gets stable codes: `rate_limited`, `daily_limit`, `quota`, `timeout`, `invalid_output`, `ai_misconfigured`, `bad_request` |

**Honest limit:** without user accounts (out of scope for PWESTADO), nothing can prove that a request came from the genuine app. The rate limit, daily cap and Google-side spend cap are what keep abuse cheap and bounded.

## Model

The default is `gemini-3.1-flash-lite`: the lowest-cost stable text model on Google's models and pricing pages as of 2026-10-24 ($0.25 per 1M input tokens, $1.50 per 1M output tokens, free tier available). Change it without redeploying code by setting `GEMINI_MODEL` (for example `gemini-3.5-flash-lite`). Check https://ai.google.dev/gemini-api/docs/models and the deprecations page before changing it.

A typical request is about 1,500 input tokens and at most 1,024 output tokens, so 200 calls a day cost at most about $0.40 on the paid tier.

## Deploy (owner, about 10 minutes)

Requires a free Cloudflare account and Node 18 or newer.

```bash
cd backend/ai-insights-worker
npx wrangler login
npx wrangler kv namespace create USAGE      # paste the id into wrangler.toml
npx wrangler secret put GEMINI_API_KEY      # paste the key from Google AI Studio
npx wrangler secret put CLIENT_IDS          # optional, e.g. a random 24-char string
npx wrangler deploy                         # prints https://pwestado-ai-insights.<you>.workers.dev
curl https://pwestado-ai-insights.<you>.workers.dev/health   # {"ok":true}
```

Then build the app with the public URL (not a secret):

```powershell
flutter build apk --release --dart-define=ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN `
  --dart-define=AI_INSIGHTS_URL=https://pwestado-ai-insights.<you>.workers.dev `
  --dart-define=AI_CLIENT_ID=<same value as CLIENT_IDS, if set>
```

Without `AI_INSIGHTS_URL`, the app shows "AI Insights isn't set up in this version" and everything else keeps working.

## Google-side spending controls (do these too)

1. In Google AI Studio, open **Spend** and set a **Monthly spend cap** on the project (for example $5).
2. Use a dedicated Google Cloud project for PWESTADO, separate from ELIXR or anything else.
3. Restrict the API key to the Generative Language API.
4. Rotate the key if it is ever exposed: `npx wrangler secret put GEMINI_API_KEY`.

## Tests

```bash
npm test   # node --test; Gemini, KV and the rate limiter are faked, no network
```
