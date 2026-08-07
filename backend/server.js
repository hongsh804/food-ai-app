import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import multer from 'multer';
import { pathToFileURL } from 'node:url';
import { GoogleGenAI, Type } from '@google/genai';
import {
  CalibrationStore,
  addNoCalibration,
  applyCalibration,
} from './calibration_store.js';

dotenv.config();

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const MAX_BODY_BYTES = 12 * 1024 * 1024;
const rawGeminiApiKey = process.env.GEMINI_API_KEY || '';
const GEMINI_API_KEY =
  rawGeminiApiKey === '내_Gemini_API_키' ? '' : rawGeminiApiKey;
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
const ai = GEMINI_API_KEY ? new GoogleGenAI({ apiKey: GEMINI_API_KEY }) : null;
const calibrationStore = new CalibrationStore();

export function createApp({
  aiClient = ai,
  calibrationRepository = calibrationStore,
  identifyFoodHandler = identifyFood,
  analyzeMealHandler = analyzeMeal,
  geminiModel = GEMINI_MODEL,
} = {}) {
  const app = express();
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: MAX_BODY_BYTES },
  });

  app.use(cors());
  app.use(express.json({ limit: `${MAX_BODY_BYTES}b` }));

  app.get('/', (req, res) => {
    res.type('html').send(`<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>GlucoLog Gemini API 서버</title>
    <style>
      body {
        margin: 0;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #fff8ed;
        color: #211b14;
      }
      main {
        max-width: 720px;
        margin: 0 auto;
        padding: 56px 24px;
      }
      .badge {
        display: inline-flex;
        padding: 8px 12px;
        border: 1px solid #f0d8b4;
        border-radius: 999px;
        background: #fff;
        color: #a55b00;
        font-weight: 800;
      }
      h1 {
        margin: 18px 0 12px;
        font-size: 34px;
      }
      p {
        line-height: 1.6;
        color: #695f54;
        font-weight: 650;
      }
      code {
        display: inline-block;
        padding: 4px 8px;
        border-radius: 8px;
        background: #fff;
        border: 1px solid #f0d8b4;
        color: #211b14;
      }
    </style>
  </head>
  <body>
    <main>
      <span class="badge">Gemini API 서버 정상 실행 중</span>
      <h1>GlucoLog Gemini API 서버</h1>
      <p>이 주소는 앱 화면이 아니라 Flutter 앱이 호출하는 백엔드 서버입니다.</p>
      <p>상태 확인: <code>/health</code></p>
      <p>Android Emulator 앱은 기본으로 <code>http://10.0.2.2:${PORT}</code> 를 호출합니다.</p>
    </main>
  </body>
</html>`);
  });

  app.get('/health', (req, res) => {
    res.json({
      ok: true,
      provider: 'gemini',
      model: geminiModel,
      hasGeminiKey: Boolean(aiClient),
    });
  });

  app.get('/api/calibrations/catalog', async (req, res) => {
    const profiles = await calibrationRepository.getCatalog();
    res.json({ profiles });
  });

  app.post('/api/identify-food', upload.none(), async (req, res) => {
    const [profiles, suggestedProfileId] = await Promise.all([
      calibrationRepository.getCatalog(),
      calibrationRepository.findSuggestedProfileId(req.body.imageBase64),
    ]);
    const calibrationContext = { profiles, suggestedProfileId };

    if (!aiClient) {
      res.json({
        candidates: mockCandidates(),
        source: 'mock',
        ...calibrationContext,
      });
      return;
    }

    try {
      const result = await identifyFoodHandler(req.body);
      res.json({ ...result, source: 'gemini', ...calibrationContext });
    } catch (error) {
      console.error('Gemini identify fallback:', error);
      res.json({
        candidates: mockCandidates(),
        source: 'mock',
        ...calibrationContext,
      });
    }
  });

  app.post('/api/analyze-meal', upload.none(), async (req, res) => {
    const foodName = String(req.body.foodName || '').trim();
    const calibrationProfileId = String(
      req.body.calibrationProfileId || '',
    ).trim();

    if (!foodName) {
      res.status(400).json({ error: 'foodName is required' });
      return;
    }

    if (!aiClient) {
      res.json({
        ...addNoCalibration(
          mockAnalysis(foodName),
          calibrationProfileId
            ? 'Gemini 응답이 없어 요청한 보정 프로필을 적용하지 않았습니다.'
            : '',
        ),
        source: 'mock',
      });
      return;
    }

    try {
      const result = await analyzeMealHandler(req.body);
      const calibratedResult = await resolveCalibration({
        analysis: result,
        foodName,
        calibrationProfileId,
        calibrationRepository,
      });
      res.json({ ...calibratedResult, source: 'gemini' });
    } catch (error) {
      console.error('Gemini analysis fallback:', error);
      res.json({
        ...addNoCalibration(
          mockAnalysis(foodName),
          calibrationProfileId
            ? 'Gemini 처리 실패로 요청한 보정 프로필을 적용하지 않았습니다.'
            : '',
        ),
        source: 'mock',
      });
    }
  });

  app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
  });

  app.use((error, req, res, next) => {
    console.error(error);
    res.status(500).json({
      error: 'Server error',
      detail: error instanceof Error ? error.message : String(error),
    });
  });

  return app;
}

export async function resolveCalibration({
  analysis,
  foodName,
  calibrationProfileId,
  calibrationRepository,
}) {
  if (calibrationProfileId) {
    const profile = await calibrationRepository.getActiveProfile(
      calibrationProfileId,
    );
    return profile
      ? applyCalibration(analysis, profile)
      : addNoCalibration(
          analysis,
          '요청한 보정 프로필이 없거나 비활성 상태입니다.',
        );
  }

  const menuRule = await calibrationRepository.findMenuRule(foodName);
  return menuRule
    ? applyCalibration(analysis, menuRule, { matchType: 'menu' })
    : addNoCalibration(analysis);
}

export function startServer(app = createApp()) {
  return app.listen(PORT, HOST, () => {
    const displayHost = HOST === '0.0.0.0' ? '127.0.0.1' : HOST;
    console.log(
      `GlucoLog Gemini API server listening on http://${displayHost}:${PORT}`,
    );
    console.log(
      GEMINI_API_KEY
        ? `Gemini model: ${GEMINI_MODEL}`
        : 'GEMINI_API_KEY is missing. Server will return mock responses.',
    );
  });
}

if (
  process.argv[1] &&
  pathToFileURL(process.argv[1]).href === import.meta.url
) {
  startServer();
}

async function identifyFood(body) {
  const responseJson = await callGeminiJson({
    imageBase64: body.imageBase64,
    mimeType: body.mimeType,
    responseSchema: {
      type: Type.OBJECT,
      properties: {
        candidates: {
          type: Type.ARRAY,
          items: { type: Type.STRING },
        },
      },
      required: ['candidates'],
    },
    prompt:
      '음식 사진을 보고 가능한 한국어 음식명 또는 한 끼 구성명을 1~5개 제안하세요. ' +
      '사진에 한 그릇 음식이 뚜렷하면 첫 번째 후보는 가장 구체적인 메뉴명이어야 합니다. 예: 짬뽕, 해물 짬뽕, 돈코츠 라멘. ' +
      '사진에 식판, 백반, 도시락처럼 밥/국/반찬/샐러드가 여러 개 보이면 하나의 메뉴로 억지 분류하지 말고 "한식 식판", "구내식당 식판", "밥+국+반찬 한 끼"처럼 전체 식사 후보를 먼저 제안하세요. ' +
      '가능하면 눈에 띄는 구성도 후보명에 짧게 포함하세요. 예: "한식 식판(밥, 국, 김치, 양배추 샐러드)". ' +
      '확실하지 않으면 "알 수 없는 음식" 대신 사진에서 보이는 일반적인 음식군을 반환하세요. ' +
      '반드시 {"candidates":["음식명"]} JSON 형식만 반환하세요.',
  });

  const candidates = Array.isArray(responseJson.candidates)
    ? responseJson.candidates
        .map((candidate) => String(candidate).trim())
        .filter(Boolean)
        .slice(0, 5)
    : [];

  return {
    candidates: candidates.length ? candidates : mockCandidates(),
  };
}

async function analyzeMeal(body) {
  const foodName = String(body.foodName || '').trim();
  const responseJson = await callGeminiJson({
    imageBase64: body.imageBase64,
    mimeType: body.mimeType,
    responseSchema: {
      type: Type.OBJECT,
      properties: {
        foodName: { type: Type.STRING },
        calories: { type: Type.INTEGER },
        carbs: { type: Type.INTEGER },
        protein: { type: Type.INTEGER },
        fat: { type: Type.INTEGER },
        sugar: { type: Type.INTEGER },
        portionDescription: { type: Type.STRING },
        ingredients: {
          type: Type.ARRAY,
          items: {
            type: Type.OBJECT,
            properties: {
              name: { type: Type.STRING },
              amount: { type: Type.STRING },
              note: { type: Type.STRING },
            },
            required: ['name', 'amount', 'note'],
          },
        },
        glucoseRisk: {
          type: Type.STRING,
          enum: ['low', 'medium', 'high'],
        },
        glucoseSpikeScore: { type: Type.INTEGER },
        estimatedGlucoseRise: { type: Type.INTEGER },
        estimatedPeakMinutes: { type: Type.INTEGER },
        glucoseDescription: { type: Type.STRING },
      },
      required: [
        'foodName',
        'calories',
        'carbs',
        'protein',
        'fat',
        'sugar',
        'portionDescription',
        'ingredients',
        'glucoseRisk',
        'glucoseSpikeScore',
        'estimatedGlucoseRise',
        'estimatedPeakMinutes',
        'glucoseDescription',
      ],
    },
    prompt:
      `사용자가 확인한 음식명은 "${foodName}"입니다. ` +
      '사진과 음식명을 바탕으로 보이는 재료, 각 재료의 대략적인 양, 전체 분량을 추정하세요. ' +
      '사진이 식판/백반/도시락처럼 여러 음식이 함께 있는 한 끼라면 밥, 국, 주반찬, 김치, 샐러드, 소스처럼 보이는 구성품을 각각 나누어 추정하세요. ' +
      '이 경우 foodName은 전체 식사를 설명하는 이름으로 정하고, ingredients에는 단일 재료뿐 아니라 "밥", "국", "김치", "양배추 샐러드" 같은 구성품을 포함하세요. ' +
      '예: 계란 1/2개, 대파 약간, 면 약 180g, 밥 약 2/3공기처럼 사용자가 이해하기 쉬운 한국어 양 표현을 사용하세요. ' +
      '사진에서 양이 명확하지 않으면 "약", "~정도", "추정" 같은 표현을 사용하세요. ' +
      '계란이 3개인지 1개인지, 면/밥 양이 많은지 적은지, 소스/당류가 많은지 같은 분량 차이를 칼로리와 혈당 상승폭에 반영하세요. ' +
      'portionDescription에는 전체 음식 양을 한 문장으로 적으세요. ingredients에는 보이는 주요 재료를 3~8개 넣으세요. ' +
      '사진과 음식명을 바탕으로 예상 칼로리와 영양 정보를 한국어 앱에 넣을 JSON으로 추정하세요. ' +
      '이 결과는 AI 추정값이며 실제 혈당 측정값이 아닙니다. ' +
      '진단, 치료, 투약 결정을 대체하지 않습니다. ' +
      'estimatedGlucoseRise는 식후 혈당이 얼마나 상승할 수 있는지에 대한 AI 추정 상승폭이며 단위는 mg/dL입니다. 현재 혈당값이나 진단 수치가 아닙니다. ' +
      'glucoseSpikeScore는 내부 색상 분류용 0~100 영향 점수입니다. glucoseRisk는 estimatedGlucoseRise와 탄수화물/당류를 바탕으로 low, medium, high 중 하나로 정하세요. ' +
      'glucoseDescription은 한국어 1~2문장으로, 왜 그런 예상 상승폭으로 추정했는지와 식사 팁을 포함하세요. JSON만 반환하세요.',
  });

  return normalizeAnalysis(responseJson, foodName);
}

async function callGeminiJson({
  imageBase64,
  mimeType,
  prompt,
  responseSchema,
}) {
  const parts = [{ text: prompt }];
  if (imageBase64) {
    parts.push({
      inlineData: {
        mimeType: mimeType || 'image/jpeg',
        data: imageBase64,
      },
    });
  }

  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: [{ role: 'user', parts }],
    config: {
      responseMimeType: 'application/json',
      responseSchema,
      temperature: 0.2,
    },
  });

  return parseJsonText(response.text);
}

function parseJsonText(text) {
  if (!text) {
    throw new Error('Gemini response did not include text.');
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) throw error;
    return JSON.parse(match[0]);
  }
}

function normalizeAnalysis(json, fallbackFoodName) {
  const inputRisk = ['low', 'medium', 'high'].includes(json.glucoseRisk)
    ? json.glucoseRisk
    : 'medium';
  const score = clampInt(
    json.glucoseSpikeScore,
    0,
    100,
    riskScore(inputRisk),
  );
  const estimatedRise = clampInt(
    json.estimatedGlucoseRise,
    0,
    140,
    riseFromScore(score),
  );
  const risk = riskFromRise(estimatedRise);

  return {
    foodName: String(json.foodName || fallbackFoodName || '알 수 없는 음식'),
    dateLabel: '오늘 식사',
    glucoseSpikeScore: score,
    estimatedGlucoseRise: estimatedRise,
    estimatedPeakMinutes: clampInt(
      json.estimatedPeakMinutes,
      15,
      180,
      risk === 'high' ? 60 : risk === 'medium' ? 75 : 90,
    ),
    calories: clampInt(json.calories, 0, 2500, 620),
    carbs: clampInt(json.carbs, 0, 300, 72),
    protein: clampInt(json.protein, 0, 200, 26),
    fat: clampInt(json.fat, 0, 200, 20),
    sugar: clampInt(json.sugar, 0, 200, 12),
    portionDescription: String(
      json.portionDescription || '사진 기준 1인분 추정',
    ),
    ingredients: normalizeIngredients(json.ingredients),
    glucoseRisk: risk,
    glucoseDescription: String(
      json.glucoseDescription ||
        '사진과 메뉴명을 바탕으로 한 AI 추정값입니다. 실제 조리법과 섭취량에 따라 식후 혈당 상승폭은 달라질 수 있습니다.',
    ),
  };
}

function mockCandidates() {
  return [];
}

function mockAnalysis(foodName) {
  if (/라멘|라면|ramen/i.test(foodName)) {
    return {
      foodName,
      dateLabel: '오늘 식사',
      glucoseSpikeScore: 88,
      estimatedGlucoseRise: 55,
      estimatedPeakMinutes: 75,
      calories: 780,
      carbs: 82,
      protein: 30,
      fat: 34,
      sugar: 6,
      portionDescription: '라멘 1그릇 기준 추정',
      ingredients: [
        {
          name: '라멘 면',
          amount: '약 180g',
          note: '혈당 상승의 주 요인',
        },
        {
          name: '차슈',
          amount: '2~3장',
          note: '단백질/지방',
        },
        {
          name: '계란',
          amount: '1/2~1개',
          note: '보이는 양 기준',
        },
        {
          name: '파/숙주',
          amount: '약간',
          note: '채소류',
        },
      ],
      glucoseRisk: 'high',
      glucoseDescription:
        '면류는 정제 탄수화물 비중이 높아 식후 혈당 상승폭이 크게 추정됩니다. 차슈, 계란, 채소를 먼저 먹고 면 양을 조절하면 부담을 낮추는 데 도움이 됩니다.',
    };
  }

  return {
    foodName,
    dateLabel: '오늘 식사',
    glucoseSpikeScore: 62,
    estimatedGlucoseRise: 34,
    estimatedPeakMinutes: 70,
    calories: 620,
    carbs: 72,
    protein: 26,
    fat: 20,
    sugar: 12,
    portionDescription: '사진 또는 메뉴명 기준 1인분 추정',
    ingredients: [
      {
        name: '주재료',
        amount: '1인분',
        note: '사진 기준 추정',
      },
      {
        name: '탄수화물/소스',
        amount: '양 추정 필요',
        note: '혈당 상승폭에 영향',
      },
    ],
    glucoseRisk: 'medium',
    glucoseDescription:
      '사진과 메뉴명을 바탕으로 식후 혈당 상승폭이 중간 정도로 추정됩니다. 실제 조리법, 양, 소스에 따라 결과는 달라질 수 있습니다.',
  };
}

function riskFromRise(rise) {
  if (rise >= 45) return 'high';
  if (rise >= 25) return 'medium';
  return 'low';
}

function riseFromScore(score) {
  if (score >= 70) return 55;
  if (score >= 40) return 34;
  return 18;
}

function normalizeIngredients(value) {
  if (!Array.isArray(value)) return [];

  return value
    .map((item) => ({
      name: String(item?.name || '').trim(),
      amount: String(item?.amount || '').trim(),
      note: String(item?.note || '').trim(),
    }))
    .filter((item) => item.name && item.amount)
    .slice(0, 8);
}

function riskScore(risk) {
  if (risk === 'high') return 88;
  if (risk === 'low') return 30;
  return 62;
}

function clampInt(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(min, Math.min(max, Math.round(number)));
}
