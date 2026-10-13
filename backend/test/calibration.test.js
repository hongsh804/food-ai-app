import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  CalibrationStore,
  addNoCalibration,
  applyCalibration,
  mealBurdenLevelFromScore,
  sha256ImageBase64,
} from '../calibration_store.js';
import {
  createApp,
  normalizeAnalysis,
  normalizeIdentificationResult,
} from '../server.js';

const baseAnalysis = Object.freeze({
  foodName: '김밥',
  mealBurdenScore: 60,
  mealBurdenLevel: 'medium',
  mealBurdenDescription: '사진 기반 식사 부담 가이드',
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
    note: '등록 제품 영양정보 기준',
    active: true,
    approved: true,
    version: 1,
    ...overrides,
  };
}

test('fixed mode replaces meal burden score and recomputes level', () => {
  const result = applyCalibration(baseAnalysis, profile());

  assert.equal(result.mealBurdenScore, 80);
  assert.equal(result.mealBurdenLevel, 'high');
  assert.equal(
    result.mealBurdenDescription,
    '등록 제품의 원재료·영양정보 반영',
  );
  assert.deepEqual(result.calibration, {
    applied: true,
    ruleId: 'gimbap-rule',
    ruleName: '김밥 보정',
    matchType: 'explicit_profile',
    mode: 'fixed',
    rawMealBurdenScore: 60,
    adjustedMealBurdenScore: 80,
    sampleCount: 12,
    note: '등록 제품의 원재료·영양정보 반영',
  });
});

test('delta mode adds to the raw meal burden score', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ mode: 'delta', adjustmentValue: 20 }),
  );

  assert.equal(result.mealBurdenScore, 80);
  assert.equal(result.mealBurdenLevel, 'high');
});

test('multiplier mode rounds and recomputes low level', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ mode: 'multiplier', adjustmentValue: 0.5 }),
  );

  assert.equal(result.mealBurdenScore, 30);
  assert.equal(result.mealBurdenLevel, 'low');
});

test('explicit score override wins over derived score', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ scoreOverride: 72 }),
  );

  assert.equal(result.mealBurdenScore, 72);
  assert.equal(result.mealBurdenLevel, 'high');
});

test('inactive or missing profile does not change the result', () => {
  const result = applyCalibration(
    baseAnalysis,
    profile({ active: false }),
  );

  assert.equal(result.mealBurdenScore, 60);
  assert.equal(result.mealBurdenLevel, 'medium');
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
  assert.equal(unapproved.mealBurdenScore, 60);
  assert.equal(undersampled.mealBurdenScore, 60);
});

test('no-calibration metadata retains the raw meal burden score', () => {
  const result = addNoCalibration(baseAnalysis, 'not selected');

  assert.equal(result.calibration.rawMealBurdenScore, 60);
  assert.equal(result.calibration.adjustedMealBurdenScore, 60);
  assert.equal(result.calibration.note, 'not selected');
});

test('meal burden level uses the public score thresholds', () => {
  assert.equal(mealBurdenLevelFromScore(0), 'low');
  assert.equal(mealBurdenLevelFromScore(39), 'low');
  assert.equal(mealBurdenLevelFromScore(40), 'medium');
  assert.equal(mealBurdenLevelFromScore(69), 'medium');
  assert.equal(mealBurdenLevelFromScore(70), 'high');
  assert.equal(mealBurdenLevelFromScore(100), 'high');
});

test('analysis normalization exposes only meal burden guidance', () => {
  const result = normalizeAnalysis(
    {
      foodName: '김밥',
      mealBurdenScore: 69,
      mealBurdenLevel: 'high',
      mealBurdenDescription: '예상 혈당 상승폭은 35 mg/dL입니다.',
      estimatedGlucoseRise: 35,
      estimatedPeakMinutes: 60,
      glucoseRisk: 'high',
      glucoseSpikeScore: 90,
      glucoseDescription: '과거 형식',
    },
    '알 수 없는 음식',
  );

  assert.equal(result.mealBurdenScore, 69);
  assert.equal(result.mealBurdenLevel, 'medium');
  assert.match(result.mealBurdenDescription, /식사 부담 가이드/);
  assert.doesNotMatch(result.mealBurdenDescription, /mg\s*\/\s*dL|예상 혈당/);
  for (const legacyField of [
    'estimatedGlucoseRise',
    'estimatedPeakMinutes',
    'glucoseRisk',
    'glucoseSpikeScore',
    'glucoseDescription',
  ]) {
    assert.equal(legacyField in result, false);
  }
});

test('all model-provided public text fields reject medical prediction copy', () => {
  const result = normalizeAnalysis(
    {
      foodName: '혈당 180 mg/dL 식단',
      mealBurdenScore: 55,
      mealBurdenLevel: 'medium',
      mealBurdenDescription: '당뇨 개선을 예측합니다.',
      portionDescription: '예상 혈당 피크 60분',
      ingredients: [
        {
          name: '당뇨 개선 샐러드',
          amount: '혈당 -30 mg/dL',
          note: '개인 혈당 반응',
        },
      ],
    },
    '혈당 180 mg/dL 식단',
  );

  assert.equal(result.foodName, '확인한 음식');
  assert.match(result.portionDescription, /약 1인분/);
  assert.match(result.mealBurdenDescription, /식사 부담 가이드/);
  assert.deepEqual(result.ingredients, []);
  assert.doesNotMatch(JSON.stringify(result), /mg\s*\/\s*dL|혈당|당뇨/);
});

test('food candidates containing medical prediction copy are excluded', () => {
  const result = normalizeIdentificationResult({
    candidates: ['김밥', '혈당 낮추는 국수', '당뇨 개선 샐러드'],
  });

  assert.deepEqual(result.candidates, ['김밥']);
});

test('mock analyze response follows the meal burden contract', async (t) => {
  const app = createApp({ aiClient: null });
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
  const response = await fetch(
    `http://127.0.0.1:${address.port}/api/analyze-meal`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ foodName: '라면' }),
    },
  );
  const result = await response.json();

  assert.equal(result.mealBurdenScore, 88);
  assert.equal(result.mealBurdenLevel, 'high');
  assert.match(result.mealBurdenDescription, /식사 부담/);
  for (const legacyField of [
    'estimatedGlucoseRise',
    'estimatedPeakMinutes',
    'glucoseRisk',
    'glucoseSpikeScore',
    'glucoseDescription',
  ]) {
    assert.equal(legacyField in result, false);
  }
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
    path.join(os.tmpdir(), 'low42-calibration-'),
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
    path.join(os.tmpdir(), 'low42-menu-rule-'),
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
  assert.equal(automatic.mealBurdenScore, 80);
  assert.equal(automatic.mealBurdenLevel, 'high');
  for (const legacyField of [
    'estimatedGlucoseRise',
    'estimatedPeakMinutes',
    'glucoseRisk',
    'glucoseSpikeScore',
    'glucoseDescription',
  ]) {
    assert.equal(legacyField in automatic, false);
  }
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
  assert.equal(explicit.mealBurdenScore, 50);
  assert.equal(explicit.mealBurdenLevel, 'medium');
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
  assert.match(invalid.calibration.note, /제품 가이드가 없거나 비활성/);
  assert.equal(invalid.mealBurdenScore, 60);
  assert.equal(menuLookupCount, 1);
});
