import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  CalibrationStore,
  addNoCalibration,
  applyCalibration,
  sha256ImageBase64,
} from '../calibration_store.js';
import { createApp } from '../server.js';

const baseAnalysis = Object.freeze({
  foodName: '김밥',
  estimatedGlucoseRise: 60,
  glucoseRisk: 'high',
  glucoseSpikeScore: 88,
});

function profile(overrides = {}) {
  return {
    id: 'gimbap-rule',
    name: '김밥 보정',
    description: '테스트 규칙',
    sampleCount: 12,
    mode: 'fixed',
    adjustmentValue: 80,
    scoreOverride: null,
    note: '등록 측정값 기준',
    active: true,
    approved: true,
    version: 1,
    ...overrides,
  };
}

test('fixed mode replaces rise and recomputes risk and score', () => {
  const result = applyCalibration(baseAnalysis, profile());

  assert.equal(result.estimatedGlucoseRise, 80);
  assert.equal(result.glucoseRisk, 'high');
  assert.equal(result.glucoseSpikeScore, 100);
  assert.deepEqual(result.calibration, {
    applied: true,
    ruleId: 'gimbap-rule',
    ruleName: '김밥 보정',
    matchType: 'explicit_profile',
    mode: 'fixed',
    rawEstimatedGlucoseRise: 60,
    adjustedEstimatedGlucoseRise: 80,
    sampleCount: 12,
    note: '등록 측정값 기준',
  });
});

test('delta mode adds to the raw estimate', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ mode: 'delta', adjustmentValue: 20 }),
  );

  assert.equal(result.estimatedGlucoseRise, 80);
  assert.equal(result.glucoseSpikeScore, 100);
});

test('multiplier mode rounds and recomputes medium risk', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ mode: 'multiplier', adjustmentValue: 0.5 }),
  );

  assert.equal(result.estimatedGlucoseRise, 30);
  assert.equal(result.glucoseRisk, 'medium');
  assert.equal(result.glucoseSpikeScore, 48);
});

test('explicit score override wins over derived score', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ scoreOverride: 72 }),
  );

  assert.equal(result.glucoseSpikeScore, 72);
});

test('inactive or missing profile does not change the result', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ active: false }),
  );

  assert.equal(result.estimatedGlucoseRise, 60);
  assert.equal(result.glucoseSpikeScore, 88);
  assert.equal(result.calibration.applied, false);
});

test('unapproved or undersampled rules never change the result', () => {
  const unapproved = applyCalibration(
    baseAnalysis,
    profile({ approved: false }),
  );
  const undersampled = applyCalibration(
    baseAnalysis,
    profile({ sampleCount: 2 }),
  );

  assert.equal(unapproved.calibration.applied, false);
  assert.equal(undersampled.calibration.applied, false);
  assert.equal(unapproved.estimatedGlucoseRise, 60);
  assert.equal(undersampled.estimatedGlucoseRise, 60);
});

test('no-calibration metadata retains the raw estimate', () => {
  const result = addNoCalibration(baseAnalysis, 'not selected');

  assert.equal(result.calibration.rawEstimatedGlucoseRise, 60);
  assert.equal(result.calibration.adjustedEstimatedGlucoseRise, 60);
  assert.equal(result.calibration.note, 'not selected');
});

test('image matching hash is exact over decoded bytes', () => {
  const first = Buffer.from('same image bytes').toString('base64');
  const same = `data:image/jpeg;base64,${first}`;
  const different = Buffer.from('different image bytes').toString('base64');

  assert.equal(sha256ImageBase64(first), sha256ImageBase64(same));
  assert.notEqual(sha256ImageBase64(first), sha256ImageBase64(different));
  assert.equal(sha256ImageBase64('not valid ***'), null);
});

test('JSON store exposes active catalog entries and suggests exact hash only', async (t) => {
  const temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), 'glucolog-calibration-'),
  );
  t.after(() => rm(temporaryDirectory, { recursive: true, force: true }));
  const jsonPath = path.join(temporaryDirectory, 'calibrations.json');
  const registeredImage = Buffer.from('registered image bytes').toString(
    'base64',
  );
  const registeredHash = sha256ImageBase64(registeredImage);
  await writeFile(
    jsonPath,
    JSON.stringify({
      profiles: [profile(), profile({ id: 'inactive', active: false })],
      imageHashes: [
        {
          sha256: registeredHash,
          profileId: 'gimbap-rule',
          active: true,
        },
      ],
    }),
  );
  const store = new CalibrationStore({ databaseUrl: '', jsonPath });

  assert.deepEqual(await store.getCatalog(), [
    {
      id: 'gimbap-rule',
      name: '김밥 보정',
      description: '테스트 규칙',
      sampleCount: 12,
    },
  ]);
  assert.equal(
    await store.findSuggestedProfileId(registeredImage),
    'gimbap-rule',
  );
  assert.equal(
    await store.findSuggestedProfileId(
      Buffer.from('new photo bytes').toString('base64'),
    ),
    null,
  );
});

test('menu rules use exact normalized name or alias and highest priority', async (t) => {
  const temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), 'glucolog-menu-rule-'),
  );
  t.after(() => rm(temporaryDirectory, { recursive: true, force: true }));
  const jsonPath = path.join(temporaryDirectory, 'calibrations.json');
  await writeFile(
    jsonPath,
    JSON.stringify({
      profiles: [],
      imageHashes: [],
      menuRules: [
        {
          ...profile({ id: 'low-priority', name: '김밥' }),
          aliases: ['일반 김밥'],
          priority: 1,
        },
        {
          ...profile({ id: 'high-priority', name: '김밥' }),
          aliases: ['일반 김밥'],
          priority: 20,
        },
        {
          ...profile({ id: 'inactive-high', name: '김밥', active: false }),
          aliases: ['일반 김밥'],
          priority: 999,
        },
      ],
    }),
  );
  const store = new CalibrationStore({ databaseUrl: '', jsonPath });

  assert.equal((await store.findMenuRule('김밥')).id, 'high-priority');
  assert.equal(
    (await store.findMenuRule('  일반   김밥 ')).id,
    'high-priority',
  );
  assert.equal(await store.findMenuRule('김밥 세트'), null);
  assert.equal(await store.findMenuRule('비빔밥'), null);
});

test('analyze route applies menu rule unless an explicit profile id is sent', async (t) => {
  let menuLookupCount = 0;
  const menuRule = profile({
    id: 'automatic-menu',
    name: '김밥 자동 보정',
    mode: 'fixed',
    adjustmentValue: 80,
  });
  const explicitProfile = profile({
    id: 'explicit-product',
    name: '저당밀가루 제품',
    mode: 'delta',
    adjustmentValue: -10,
  });
  const repository = {
    async findMenuRule(foodName) {
      menuLookupCount += 1;
      return foodName === '김밥' ? menuRule : null;
    },
    async getActiveProfile(profileId) {
      return profileId === explicitProfile.id ? explicitProfile : null;
    },
  };
  const app = createApp({
    aiClient: {},
    calibrationRepository: repository,
    analyzeMealHandler: async () => ({ ...baseAnalysis }),
  });
  const server = await new Promise((resolve, reject) => {
    const listeningServer = app.listen(0, '127.0.0.1', () => {
      resolve(listeningServer);
    });
    listeningServer.on('error', reject);
  });
  t.after(
    () => new Promise((resolve) => server.close(() => resolve())),
  );
  const address = server.address();
  const endpoint = `http://127.0.0.1:${address.port}/api/analyze-meal`;

  const automaticResponse = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ foodName: '김밥' }),
  });
  const automatic = await automaticResponse.json();
  assert.equal(automatic.calibration.applied, true);
  assert.equal(automatic.calibration.matchType, 'menu');
  assert.equal(automatic.estimatedGlucoseRise, 80);
  assert.equal(menuLookupCount, 1);

  const explicitResponse = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      foodName: '김밥',
      calibrationProfileId: 'explicit-product',
    }),
  });
  const explicit = await explicitResponse.json();
  assert.equal(explicit.calibration.applied, true);
  assert.equal(explicit.calibration.matchType, 'explicit_profile');
  assert.equal(explicit.estimatedGlucoseRise, 50);
  assert.equal(menuLookupCount, 1);

  const invalidResponse = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      foodName: '김밥',
      calibrationProfileId: 'missing-product',
    }),
  });
  const invalid = await invalidResponse.json();
  assert.equal(invalid.calibration.applied, false);
  assert.match(invalid.calibration.note, /없거나 비활성/);
  assert.equal(invalid.estimatedGlucoseRise, 60);
  assert.equal(menuLookupCount, 1);
});
