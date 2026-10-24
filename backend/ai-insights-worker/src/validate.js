// Strict allowlist validation for PWESTADO AI Insights requests and
// Gemini responses. Pure functions: no I/O, easy to unit test.

export const LIMITS = Object.freeze({
  maxBodyBytes: 8 * 1024,
  maxSites: 2,
  maxDistances: 10,
  maxAreaLength: 80,
  maxKinds: 8,
  maxWarnings: 6,
  maxSentence: 400,
  maxPoint: 280,
});

const BUSINESS_TYPES = new Set([
  'Coffee Shop',
  'Restaurant',
  'Sari-Sari / Convenience',
  'Laundry Shop',
  'Bakery',
]);
const RADII = new Set([500, 1000, 2000]);
const SOURCES = new Set(['live', 'cached', 'sample']);
const CRITERIA = new Set(['competition', 'complementary_places', 'mapped_road_access']);
const WARNINGS = new Set([
  'sparse_map_coverage',
  'competitor_list_may_be_cut_off',
  'sample_demo_data',
  'cached_copy',
]);
const MISSING = new Set(['complementary_places_and_roads']);
const LABELS = new Set(['Selected location', 'Site A', 'Site B']);
const BLOCKERS = new Set([
  'missingAnalysis',
  'sameSite',
  'settingsMismatch',
  'settingsChanged',
  'mixedSources',
  'insufficientData',
]);
const KIND_PATTERN = /^[a-z_]{2,32}$/;
const ROAD_KIND_PATTERN = /^[a-z_]{2,24}$/;

export class ValidationError extends Error {}

function fail(message) {
  throw new ValidationError(message);
}

function num(v, min, max, field, { nullable = false, integer = false } = {}) {
  if (v === null || v === undefined) {
    if (nullable) return null;
    fail(`${field} is required`);
  }
  if (typeof v !== 'number' || !Number.isFinite(v)) fail(`${field} must be a number`);
  if (integer && !Number.isInteger(v)) fail(`${field} must be an integer`);
  if (v < min || v > max) fail(`${field} out of range`);
  return v;
}

function bool(v, field) {
  if (typeof v !== 'boolean') fail(`${field} must be boolean`);
  return v;
}

function oneOf(v, set, field) {
  if (typeof v !== 'string' || !set.has(v)) fail(`${field} is not allowed`);
  return v;
}

function list(v, field, max) {
  if (!Array.isArray(v)) fail(`${field} must be a list`);
  if (v.length > max) fail(`${field} has too many items`);
  return v;
}

/** Free text from a geocoder: treated strictly as data, never as instructions. */
export function cleanArea(v) {
  if (v === undefined || v === null) return null;
  if (typeof v !== 'string') fail('area must be text');
  const t = v
    .replace(/[\u0000-\u001f\u007f<>{}`]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, LIMITS.maxAreaLength);
  return t.length ? t : null;
}

function site(raw, index) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) fail(`sites[${index}] must be an object`);
  const f = (name) => `sites[${index}].${name}`;
  const score = raw.score ?? fail(f('score') + ' is required');
  const competitors = raw.competitors ?? fail(f('competitors') + ' is required');
  const retrievedAt = raw.retrievedAt;
  if (typeof retrievedAt !== 'string' || Number.isNaN(Date.parse(retrievedAt)) || retrievedAt.length > 40) {
    fail(f('retrievedAt') + ' must be an ISO date');
  }

  const criteria = list(score.criteria, f('score.criteria'), 3).map((c, i) => ({
    id: oneOf(c?.id, CRITERIA, `${f('score.criteria')}[${i}].id`),
    weightPercent: num(c?.weightPercent, 0, 100, 'weightPercent', { integer: true }),
    score: num(c?.score, 0, 100, 'criterion score', { nullable: true }),
  }));

  const comp = raw.complementary;
  const roads = raw.roads;
  return {
    label: oneOf(raw.label, LABELS, f('label')),
    area: cleanArea(raw.area),
    businessType: oneOf(raw.businessType, BUSINESS_TYPES, f('businessType')),
    radiusMeters: (() => {
      const r = num(raw.radiusMeters, 0, 5000, f('radiusMeters'), { integer: true });
      if (!RADII.has(r)) fail(f('radiusMeters') + ' is not allowed');
      return r;
    })(),
    source: oneOf(raw.source, SOURCES, f('source')),
    retrievedAt,
    score: {
      total: num(score.total, 0, 100, f('score.total'), { nullable: true }),
      lowConfidence: bool(score.lowConfidence, f('score.lowConfidence')),
      criteria,
    },
    competitors: {
      count: num(competitors.count, 0, 5000, 'competitors.count', { integer: true }),
      within250m: num(competitors.within250m, 0, 5000, 'within250m', { integer: true }),
      nearestMeters: num(competitors.nearestMeters, 0, 10000, 'nearestMeters', { nullable: true }),
      distancesMeters: list(competitors.distancesMeters, 'distancesMeters', LIMITS.maxDistances).map((d) =>
        num(d, 0, 10000, 'distance'),
      ),
      possiblyTruncated: bool(competitors.possiblyTruncated, 'possiblyTruncated'),
    },
    complementary:
      comp === null || comp === undefined
        ? null
        : {
            count: num(comp.count, 0, 10000, 'complementary.count', { integer: true }),
            byKind: Object.fromEntries(
              Object.entries(comp.byKind ?? {})
                .slice(0, LIMITS.maxKinds)
                .map(([k, v]) => {
                  if (!KIND_PATTERN.test(k)) fail('complementary kind not allowed');
                  return [k, num(v, 0, 10000, 'kind count', { integer: true })];
                }),
            ),
          },
    roads:
      roads === null || roads === undefined
        ? null
        : {
            count: num(roads.count, 0, 10000, 'roads.count', { integer: true }),
            nearestMeters: num(roads.nearestMeters, 0, 10000, 'roads.nearestMeters', { nullable: true }),
            nearestKind:
              roads.nearestKind === null || roads.nearestKind === undefined
                ? null
                : ROAD_KIND_PATTERN.test(roads.nearestKind)
                  ? roads.nearestKind
                  : fail('road kind not allowed'),
            nearestMajorMeters: num(roads.nearestMajorMeters, 0, 10000, 'nearestMajorMeters', {
              nullable: true,
            }),
          },
    missingEvidence: list(raw.missingEvidence ?? [], 'missingEvidence', 2).map((m) =>
      oneOf(m, MISSING, 'missingEvidence'),
    ),
    warnings: list(raw.warnings ?? [], 'warnings', LIMITS.maxWarnings).map((w) => oneOf(w, WARNINGS, 'warning')),
  };
}

/**
 * Validates and normalizes a request body. Unknown fields are dropped, so
 * nothing unexpected (like extra free text) ever reaches the model.
 */
export function validateRequest(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) fail('body must be an object');
  if (body.version !== 1) fail('unsupported version');
  const mode = oneOf(body.mode, new Set(['site', 'compare']), 'mode');
  const sites = list(body.sites, 'sites', LIMITS.maxSites).map(site);
  if (mode === 'site' && sites.length !== 1) fail('site mode needs one site');
  if (mode === 'compare' && sites.length !== 2) fail('compare mode needs two sites');
  // Evidence-based insights need a complete deterministic score.
  for (const s of sites) if (s.score.total === null) fail('a complete score is required');

  let comparison = null;
  if (mode === 'compare' && body.comparison) {
    const c = body.comparison;
    comparison = {
      comparable: bool(c.comparable, 'comparison.comparable'),
      higher: c.higher === null || c.higher === undefined ? null : oneOf(c.higher, new Set(['Site A', 'Site B']), 'higher'),
      differencePoints: num(c.differencePoints, -100, 100, 'differencePoints', { nullable: true }),
      blockers: list(c.blockers ?? [], 'blockers', 6).map((b) => oneOf(b, BLOCKERS, 'blocker')),
    };
    if (!comparison.comparable) fail('sites are not comparable');
  }
  const demo = sites.some((s) => s.source === 'sample');
  return { mode, sites, comparison, demo };
}

// Claims the evidence can never support. A point that makes one is dropped;
// a quick assessment that makes one rejects the whole answer.
const UNSUPPORTED = [
  /(?:₱|\bphp\s?)\s?\d/i, // peso amounts (rent, sales, income)
  /\b\d[\d,.]*\s*(?:customers|residents|people|households|visitors|pesos)\b/i,
  /\b(?:guarantee[ds]?|sure to succeed|will definitely|siguradong kikita)\b/i,
  /\b\d{1,3}\s?%\s*(?:chance|probability|success|profit|growth)/i,
];

export function hasUnsupportedClaim(text) {
  return UNSUPPORTED.some((re) => re.test(text));
}

function cleanText(v) {
  return String(v)
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, '')
    .replace(/[*_`#]{1,3}/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Validates the model's JSON against the contract the app expects. */
export function validateInsight(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) fail('insight must be an object');
  const qa = typeof raw.quickAssessment === 'string' ? cleanText(raw.quickAssessment) : '';
  if (!qa || qa.length > LIMITS.maxSentence) fail('quickAssessment invalid');
  if (hasUnsupportedClaim(qa)) fail('quickAssessment makes an unsupported claim');

  const points = (field, max, min = 0) => {
    const v = raw[field];
    if (!Array.isArray(v)) fail(`${field} must be a list`);
    const out = v
      .filter((p) => typeof p === 'string')
      .map(cleanText)
      .filter((p) => p.length > 0 && p.length <= LIMITS.maxPoint && !hasUnsupportedClaim(p))
      .slice(0, max);
    if (out.length < min) fail(`${field} needs at least ${min} item(s)`);
    return out;
  };

  return {
    quickAssessment: qa,
    promising: points('promising', 3),
    watchOuts: points('watchOuts', 3),
    nextSteps: points('nextSteps', 4, 1),
    limitations: points('limitations', 3, 1),
  };
}
