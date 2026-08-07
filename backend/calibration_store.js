import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const moduleDirectory = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_JSON_PATH = path.join(
  moduleDirectory,
  'data',
  'calibrations.json',
);
const ALLOWED_MODES = new Set(['fixed', 'delta', 'multiplier']);

export class CalibrationStore {
  constructor({
    databaseUrl = process.env.DATABASE_URL || '',
    databaseSsl = process.env.DATABASE_SSL,
    jsonPath = process.env.CALIBRATIONS_JSON_PATH || DEFAULT_JSON_PATH,
    logger = console,
  } = {}) {
    this.databaseUrl = String(databaseUrl).trim();
    this.databaseSsl = databaseSsl;
    this.jsonPath = jsonPath;
    this.logger = logger;
    this.poolPromise = null;
    this.jsonPromise = null;
    this.lastDatabaseWarning = '';
  }

  async getCatalog() {
    const databaseRows = await this.queryDatabase(
      `SELECT id, name, description, sample_count, mode, adjustment_value,
              score_override, note, active, approved_at, approved_by, version
         FROM calibration_profiles
        WHERE active = TRUE
          AND sample_count >= 3
          AND approved_at IS NOT NULL
          AND NULLIF(BTRIM(approved_by), '') IS NOT NULL
        ORDER BY name ASC`,
    );
    const profiles = databaseRows === null
      ? (await this.loadJson()).profiles
      : databaseRows;

    return profiles
      .map(normalizeProfile)
      .filter(isEligibleRule)
      .map(toCatalogProfile);
  }

  async getActiveProfile(profileId) {
    const normalizedId = String(profileId || '').trim();
    if (!normalizedId) return null;

    const databaseRows = await this.queryDatabase(
      `SELECT id, name, description, sample_count, mode, adjustment_value,
              score_override, note, active, approved_at, approved_by, version
         FROM calibration_profiles
        WHERE id = $1
          AND active = TRUE
          AND sample_count >= 3
          AND approved_at IS NOT NULL
          AND NULLIF(BTRIM(approved_by), '') IS NOT NULL
        LIMIT 1`,
      [normalizedId],
    );
    const rows = databaseRows === null
      ? (await this.loadJson()).profiles
      : databaseRows;

    return (
      rows
        .map(normalizeProfile)
        .find(
          (profile) => isEligibleRule(profile) && profile.id === normalizedId,
        ) || null
    );
  }

  async findMenuRule(foodName) {
    const menuKey = normalizeMenuKey(foodName);
    if (!menuKey) return null;

    const databaseRows = await this.queryDatabase(
      `SELECT id, name, aliases, sample_count, mode, adjustment_value,
              score_override, note, priority, active, approved_at,
              approved_by, version
         FROM calibration_menu_rules
        WHERE active = TRUE
          AND sample_count >= 3
          AND approved_at IS NOT NULL
          AND NULLIF(BTRIM(approved_by), '') IS NOT NULL
        ORDER BY priority DESC, name ASC`,
    );
    const rows = databaseRows === null
      ? (await this.loadJson()).menuRules
      : databaseRows;

    return (
      rows
        .map(normalizeMenuRule)
        .filter(
          (rule) =>
            isEligibleRule(rule) &&
            [rule.name, ...rule.aliases]
              .map(normalizeMenuKey)
              .includes(menuKey),
        )
        .sort(
          (left, right) =>
            right.priority - left.priority || left.name.localeCompare(right.name),
        )[0] || null
    );
  }

  async findSuggestedProfileId(imageBase64) {
    const imageHash = sha256ImageBase64(imageBase64);
    if (!imageHash) return null;

    const databaseRows = await this.queryDatabase(
      `SELECT p.id
         FROM calibration_image_hashes AS h
         JOIN calibration_profiles AS p ON p.id = h.profile_id
        WHERE h.sha256 = $1
          AND h.active = TRUE
          AND p.active = TRUE
          AND p.sample_count >= 3
          AND p.approved_at IS NOT NULL
          AND NULLIF(BTRIM(p.approved_by), '') IS NOT NULL
        LIMIT 1`,
      [imageHash],
    );
    if (databaseRows !== null) {
      return databaseRows.length ? String(databaseRows[0].id) : null;
    }

    const json = await this.loadJson();
    const match = json.imageHashes.find(
      (entry) =>
        entry?.active !== false &&
        String(entry?.sha256 || '').toLowerCase() === imageHash,
    );
    if (!match) return null;

    const profile = json.profiles
      .map(normalizeProfile)
      .find(
        (candidate) =>
          isEligibleRule(candidate) &&
          candidate.id === String(match.profileId || ''),
      );
    return profile?.id || null;
  }

  async queryDatabase(sql, parameters = []) {
    if (!this.databaseUrl) return null;

    try {
      const pool = await this.getPool();
      if (!pool) return null;
      const result = await pool.query(sql, parameters);
      return result.rows;
    } catch (error) {
      this.warnDatabaseFallback(error);
      return null;
    }
  }

  async getPool() {
    if (!this.databaseUrl) return null;
    if (!this.poolPromise) {
      this.poolPromise = import('pg').then(({ Pool }) => {
        const ssl = this.databaseSsl === 'false'
          ? false
          : { rejectUnauthorized: false };
        return new Pool({ connectionString: this.databaseUrl, ssl });
      });
    }
    return this.poolPromise;
  }

  async loadJson() {
    if (!this.jsonPromise) {
      this.jsonPromise = readFile(this.jsonPath, 'utf8')
        .then((text) => JSON.parse(text))
        .then((json) => ({
          profiles: Array.isArray(json.profiles) ? json.profiles : [],
          imageHashes: Array.isArray(json.imageHashes)
            ? json.imageHashes
            : [],
          menuRules: Array.isArray(json.menuRules) ? json.menuRules : [],
        }))
        .catch((error) => {
          this.logger.error(
            `Calibration JSON could not be loaded: ${safeErrorMessage(error)}`,
          );
          return { profiles: [], imageHashes: [], menuRules: [] };
        });
    }
    return this.jsonPromise;
  }

  warnDatabaseFallback(error) {
    const message = safeErrorMessage(error);
    if (message === this.lastDatabaseWarning) return;
    this.lastDatabaseWarning = message;
    this.logger.warn(
      `Calibration database unavailable; using JSON fallback: ${message}`,
    );
  }
}

export function sha256ImageBase64(imageBase64) {
  if (typeof imageBase64 !== 'string') return null;
  const payload = imageBase64.includes(',')
    ? imageBase64.slice(imageBase64.indexOf(',') + 1)
    : imageBase64;
  const normalized = payload.replace(/\s+/g, '');
  if (
    !normalized ||
    normalized.length % 4 === 1 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(normalized)
  ) {
    return null;
  }

  const bytes = Buffer.from(normalized, 'base64');
  if (!bytes.length) return null;
  return createHash('sha256').update(bytes).digest('hex');
}

export function addNoCalibration(analysis, note = '') {
  const rawRise = clampInteger(analysis?.estimatedGlucoseRise, 0, 140, 0);
  return {
    ...analysis,
    calibration: {
      applied: false,
      ruleId: null,
      ruleName: null,
      matchType: 'none',
      mode: null,
      rawEstimatedGlucoseRise: rawRise,
      adjustedEstimatedGlucoseRise: rawRise,
      sampleCount: 0,
      note: String(note || ''),
    },
  };
}

export function applyCalibration(
  analysis,
  profile,
  { matchType = 'explicit_profile' } = {},
) {
  const normalizedProfile = normalizeProfile(profile);
  if (!isEligibleRule(normalizedProfile)) {
    return addNoCalibration(analysis);
  }

  const rawRise = clampInteger(analysis?.estimatedGlucoseRise, 0, 140, 0);
  let adjustedRise;
  switch (normalizedProfile.mode) {
    case 'fixed':
      adjustedRise = normalizedProfile.adjustmentValue;
      break;
    case 'delta':
      adjustedRise = rawRise + normalizedProfile.adjustmentValue;
      break;
    case 'multiplier':
      adjustedRise = rawRise * normalizedProfile.adjustmentValue;
      break;
    default:
      return addNoCalibration(analysis);
  }

  adjustedRise = clampInteger(adjustedRise, 0, 140, rawRise);
  const score = normalizedProfile.scoreOverride ?? clampInteger(
    adjustedRise * 1.6,
    0,
    100,
    0,
  );

  return {
    ...analysis,
    estimatedGlucoseRise: adjustedRise,
    glucoseRisk: glucoseRiskFromRise(adjustedRise),
    glucoseSpikeScore: score,
    glucoseDescription:
      `AI 원본 예상 상승폭 +${rawRise} mg/dL에 승인된 측정자료 ` +
      `${normalizedProfile.sampleCount}건을 적용해 +${adjustedRise} mg/dL로 ` +
      '보정했습니다. 이 값은 실제 혈당 실측치가 아닌 보정된 예상값입니다.',
    calibration: {
      applied: true,
      ruleId: normalizedProfile.id,
      ruleName: normalizedProfile.name,
      matchType,
      mode: normalizedProfile.mode,
      rawEstimatedGlucoseRise: rawRise,
      adjustedEstimatedGlucoseRise: adjustedRise,
      sampleCount: normalizedProfile.sampleCount,
      note: normalizedProfile.note,
    },
  };
}

export function glucoseRiskFromRise(rise) {
  const normalizedRise = clampInteger(rise, 0, 140, 0);
  if (normalizedRise >= 45) return 'high';
  if (normalizedRise >= 25) return 'medium';
  return 'low';
}

export function normalizeMenuKey(value) {
  return String(value || '')
    .normalize('NFKC')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function normalizeProfile(value) {
  if (!value || typeof value !== 'object') return null;
  const id = String(value.id || '').trim();
  const name = String(value.name || '').trim();
  const mode = String(value.mode || '').trim();
  const adjustmentValue = Number(
    value.adjustmentValue ?? value.adjustment_value,
  );
  if (
    !id ||
    !name ||
    !ALLOWED_MODES.has(mode) ||
    !Number.isFinite(adjustmentValue) ||
    (mode === 'multiplier' && adjustmentValue < 0)
  ) {
    return null;
  }

  const rawScoreOverride = value.scoreOverride ?? value.score_override;
  const parsedScoreOverride = rawScoreOverride === null ||
      rawScoreOverride === undefined ||
      rawScoreOverride === ''
    ? null
    : clampInteger(rawScoreOverride, 0, 100, null);

  return {
    id,
    name,
    description: String(value.description || ''),
    sampleCount: clampInteger(
      value.sampleCount ?? value.sample_count,
      0,
      Number.MAX_SAFE_INTEGER,
      0,
    ),
    mode,
    adjustmentValue,
    scoreOverride: parsedScoreOverride,
    note: String(value.note || ''),
    active: value.active === true,
    approved:
      value.approved === true ||
      (value.approved === undefined &&
        Boolean(value.approved_at) &&
        String(value.approved_by || '').trim().length > 0),
    version: clampInteger(value.version, 1, Number.MAX_SAFE_INTEGER, 1),
  };
}

function normalizeMenuRule(value) {
  const profile = normalizeProfile({
    ...value,
    description: value?.description || '',
  });
  if (!profile) return null;
  return {
    ...profile,
    aliases: Array.isArray(value.aliases)
      ? value.aliases
          .map((alias) => String(alias || '').trim())
          .filter(Boolean)
      : [],
    priority: clampInteger(
      value.priority,
      Number.MIN_SAFE_INTEGER,
      Number.MAX_SAFE_INTEGER,
      0,
    ),
  };
}

function toCatalogProfile(profile) {
  return {
    id: profile.id,
    name: profile.name,
    description: profile.description,
    sampleCount: profile.sampleCount,
  };
}

function isEligibleRule(rule) {
  return Boolean(
    rule?.active && rule.approved && Number(rule.sampleCount) >= 3,
  );
}

function clampInteger(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(min, Math.min(max, Math.round(number)));
}

function safeErrorMessage(error) {
  if (error instanceof Error) return error.message;
  return String(error);
}
