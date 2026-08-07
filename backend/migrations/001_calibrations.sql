BEGIN;

CREATE TABLE IF NOT EXISTS calibration_profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  sample_count INTEGER NOT NULL DEFAULT 0 CHECK (sample_count >= 0),
  mode TEXT NOT NULL CHECK (mode IN ('fixed', 'delta', 'multiplier')),
  adjustment_value DOUBLE PRECISION NOT NULL,
  score_override INTEGER CHECK (score_override BETWEEN 0 AND 100),
  note TEXT NOT NULL DEFAULT '',
  active BOOLEAN NOT NULL DEFAULT FALSE,
  approved_at TIMESTAMPTZ,
  approved_by TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (mode <> 'multiplier' OR adjustment_value >= 0),
  CHECK (
    NOT active OR (
      sample_count >= 3
      AND approved_at IS NOT NULL
      AND NULLIF(BTRIM(approved_by), '') IS NOT NULL
    )
  )
);

CREATE TABLE IF NOT EXISTS calibration_image_hashes (
  sha256 CHAR(64) PRIMARY KEY CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  profile_id TEXT NOT NULL REFERENCES calibration_profiles(id) ON DELETE CASCADE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS calibration_image_hashes_profile_id_idx
  ON calibration_image_hashes(profile_id);

CREATE TABLE IF NOT EXISTS calibration_menu_rules (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  aliases TEXT[] NOT NULL DEFAULT '{}',
  sample_count INTEGER NOT NULL DEFAULT 0 CHECK (sample_count >= 0),
  mode TEXT NOT NULL CHECK (mode IN ('fixed', 'delta', 'multiplier')),
  adjustment_value DOUBLE PRECISION NOT NULL,
  score_override INTEGER CHECK (score_override BETWEEN 0 AND 100),
  note TEXT NOT NULL DEFAULT '',
  priority INTEGER NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  approved_at TIMESTAMPTZ,
  approved_by TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (mode <> 'multiplier' OR adjustment_value >= 0),
  CHECK (
    NOT active OR (
      sample_count >= 3
      AND approved_at IS NOT NULL
      AND NULLIF(BTRIM(approved_by), '') IS NOT NULL
    )
  )
);

CREATE INDEX IF NOT EXISTS calibration_menu_rules_active_priority_idx
  ON calibration_menu_rules(active, priority DESC);

CREATE TABLE IF NOT EXISTS calibration_measurements (
  id BIGSERIAL PRIMARY KEY,
  profile_id TEXT REFERENCES calibration_profiles(id) ON DELETE RESTRICT,
  menu_rule_id TEXT REFERENCES calibration_menu_rules(id) ON DELETE RESTRICT,
  user_code TEXT NOT NULL CHECK (NULLIF(BTRIM(user_code), '') IS NOT NULL),
  measured_at TIMESTAMPTZ NOT NULL,
  portion_description TEXT NOT NULL
    CHECK (NULLIF(BTRIM(portion_description), '') IS NOT NULL),
  pre_glucose_mg_dl INTEGER NOT NULL
    CHECK (pre_glucose_mg_dl BETWEEN 0 AND 1000),
  peak_glucose_mg_dl INTEGER NOT NULL
    CHECK (peak_glucose_mg_dl BETWEEN 0 AND 1000),
  peak_minutes INTEGER NOT NULL CHECK (peak_minutes BETWEEN 0 AND 360),
  ai_estimated_rise INTEGER CHECK (ai_estimated_rise BETWEEN 0 AND 300),
  activity_after TEXT NOT NULL DEFAULT '',
  medication_changed BOOLEAN NOT NULL DEFAULT FALSE,
  notes TEXT NOT NULL DEFAULT '',
  source_image_name TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK ((profile_id IS NOT NULL) <> (menu_rule_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS calibration_measurements_profile_id_idx
  ON calibration_measurements(profile_id, measured_at DESC);

CREATE INDEX IF NOT EXISTS calibration_measurements_menu_rule_id_idx
  ON calibration_measurements(menu_rule_id, measured_at DESC);

COMMIT;
