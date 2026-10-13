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
    <title>LOW42 Gemini API 서버</title>
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
      <h1>LOW42 Gemini API 서버</h1>
      <p>이 주소는 앱 화면이 아니라 Flutter 앱이 호출하는 백엔드 서버입니다.</p>
      <p>상태 확인: <code>/health</code></p>
      <p>Flutter 앱은 설정된 HTTPS 백엔드 주소로 이 서버를 호출합니다.</p>
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
      const result = normalizeIdentificationResult(
        await identifyFoodHandler(req.body),
      );
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
            ? 'Gemini 응답이 없어 요청한 제품 가이드를 적용하지 않았습니다.'
            : '',
        ),
        source: 'mock',
      });
      return;
    }

    try {
      const result = normalizeAnalysis(
        await analyzeMealHandler(req.body),
        foodName,
      );
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
            ? 'Gemini 처리 실패로 요청한 제품 가이드를 적용하지 않았습니다.'
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
          '요청한 제품 가이드가 없거나 비활성 상태입니다.',
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
      `LOW42 Gemini API server listening on http://${displayHost}:${PORT}`,
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

  return normalizeIdentificationResult(responseJson);
}

export function normalizeIdentificationResult(value) {
  const candidates = Array.isArray(value?.candidates)
    ? value.candidates
        .map((candidate) => sanitizePublicText(candidate, '', 120))
        .filter(Boolean)
        .slice(0, 5)
    : [];

  return { candidates: candidates.length ? candidates : mockCandidates() };
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
        mealBurdenLevel: {
          type: Type.STRING,
          enum: ['low', 'medium', 'high'],
        },
        mealBurdenScore: { type: Type.INTEGER },
        mealBurdenDescription: { type: Type.STRING },
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
        'mealBurdenLevel',
        'mealBurdenScore',
        'mealBurdenDescription',
      ],
    },
    prompt:
      `사용자가 확인한 음식명은 "${foodName}"입니다. ` +
      '사진과 음식명을 바탕으로 보이는 재료, 각 재료의 대략적인 양, 전체 분량을 추정하세요. ' +
      '사진이 식판/백반/도시락처럼 여러 음식이 함께 있는 한 끼라면 밥, 국, 주반찬, 김치, 샐러드, 소스처럼 보이는 구성품을 각각 나누어 추정하세요. ' +
      '이 경우 foodName은 전체 식사를 설명하는 이름으로 정하고, ingredients에는 단일 재료뿐 아니라 "밥", "국", "김치", "양배추 샐러드" 같은 구성품을 포함하세요. ' +
      '예: 계란 1/2개, 대파 약간, 면 약 180g, 밥 약 2/3공기처럼 사용자가 이해하기 쉬운 한국어 양 표현을 사용하세요. ' +
      '사진에 숟가락, 젓가락, 포크, 컵, 접시처럼 크기 기준이 될 물체가 보이면 음식과의 상대 비율을 이용해 분량을 추정하세요. ' +
      '숟가락과 젓가락은 제품마다 실제 크기가 다르므로 절대 측정 도구로 단정하지 말고, 접시 크기와 함께 교차 확인한 뒤 "약" 또는 범위로 표현하세요. ' +
      '크기 기준 물체가 보이지 않으면 일반적인 접시나 공기 크기를 참고하되 불확실성을 분명히 적으세요. ' +
      '사진에서 양이 명확하지 않으면 "약", "~정도", "추정" 같은 표현을 사용하세요. ' +
      '같은 메뉴라도 계란이 3개인지 1개인지, 면/밥 양이 많은지 적은지, 소스/당류가 많은지에 따라 칼로리, 영양 정보와 식사 부담 점수가 달라져야 합니다. 사진마다 임의로 값을 바꾸지 말고 관찰 가능한 분량 차이에 근거하세요. ' +
      'portionDescription에는 전체 음식 양을 한 문장으로 적으세요. ingredients에는 보이는 주요 재료를 3~8개 넣으세요. ' +
      '사진과 음식명을 바탕으로 예상 칼로리와 영양 정보를 한국어 앱에 넣을 JSON으로 추정하세요. ' +
      '이 결과는 LOW42 식사 부담 가이드를 위한 AI 참고값이며 개인 혈당 수치나 혈당 상승폭을 산출하지 않습니다. ' +
      '진단, 치료, 투약 결정을 대체하지 않습니다. ' +
      'mealBurdenScore는 추정 분량, 탄수화물과 당류의 양, 단백질·지방·식이섬유의 구성을 함께 고려한 0~100 식사 부담 점수입니다. ' +
      '양이 많거나 정제 탄수화물·첨가당 비중이 높으면 점수를 높이고, 적정 분량에 단백질과 식이섬유가 균형 있게 포함되면 낮추세요. 지방은 에너지 밀도와 전체 식사 구성을 고려하되 혈당 반응으로 환산하지 마세요. ' +
      'mealBurdenLevel은 mealBurdenScore가 40 미만이면 low, 40 이상 70 미만이면 medium, 70 이상이면 high로 정하세요. ' +
      'mealBurdenDescription은 한국어 1~2문장으로, 사진에서 확인한 분량과 영양 구성 때문에 식사 부담을 그렇게 분류한 이유 및 일반적인 식사 팁을 설명하세요. ' +
      'mg/dL, 예상 혈당, 혈당 상승폭, 개인별 혈당 반응이나 도달 시간을 생성하거나 설명하지 마세요. JSON만 반환하세요.',
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

export function normalizeAnalysis(json, fallbackFoodName) {
  const inputLevel = ['low', 'medium', 'high'].includes(json.mealBurdenLevel)
    ? json.mealBurdenLevel
    : 'medium';
  const score = clampInt(
    json.mealBurdenScore,
    0,
    100,
    burdenScoreFallback(inputLevel),
  );
  const level = mealBurdenLevelFromScore(score);

  return {
    foodName:
      sanitizePublicText(fallbackFoodName, '', 100) ||
      sanitizePublicText(json.foodName, '확인한 음식', 100),
    dateLabel: '오늘 식사',
    mealBurdenScore: score,
    mealBurdenLevel: level,
    calories: clampInt(json.calories, 0, 2500, 620),
    carbs: clampInt(json.carbs, 0, 300, 72),
    protein: clampInt(json.protein, 0, 200, 26),
    fat: clampInt(json.fat, 0, 200, 20),
    sugar: clampInt(json.sugar, 0, 200, 12),
    portionDescription: sanitizePublicText(
      json.portionDescription,
      '사진 기준 약 1인분 추정',
      120,
    ),
    ingredients: normalizeIngredients(json.ingredients),
    mealBurdenDescription: normalizeMealBurdenDescription(
      json.mealBurdenDescription,
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
      mealBurdenScore: 88,
      mealBurdenLevel: 'high',
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
          note: '식사 부담의 주 요인',
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
      mealBurdenDescription:
        '면류는 정제 탄수화물 비중과 추정 분량이 커 식사 부담이 높게 분류됐습니다. 차슈, 계란, 채소를 먼저 먹고 면 양을 조절해보세요.',
    };
  }

  return {
    foodName,
    dateLabel: '오늘 식사',
    mealBurdenScore: 62,
    mealBurdenLevel: 'medium',
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
        note: '식사 부담에 영향',
      },
    ],
    mealBurdenDescription:
      '사진과 메뉴명, 추정 분량을 바탕으로 식사 부담이 보통으로 분류됐습니다. 실제 조리법, 양, 소스에 따라 결과는 달라질 수 있습니다.',
  };
}

function mealBurdenLevelFromScore(score) {
  if (score >= 70) return 'high';
  if (score >= 40) return 'medium';
  return 'low';
}

function normalizeMealBurdenDescription(value) {
  return sanitizePublicText(
    value,
    '사진과 메뉴명, 추정 분량을 바탕으로 만든 식사 부담 가이드입니다. 실제 조리법과 섭취량에 따라 결과는 달라질 수 있습니다.',
    360,
  );
}

function normalizeIngredients(value) {
  if (!Array.isArray(value)) return [];

  return value
    .map((item) => {
      const name = sanitizePublicText(item?.name, '', 80);
      const amount = sanitizePublicText(item?.amount, '', 80);
      if (!name || !amount) return null;
      return {
        name,
        amount,
        note: normalizeIngredientNote(item?.note),
      };
    })
    .filter(Boolean)
    .filter((item) => item.name && item.amount)
    .slice(0, 8);
}

function normalizeIngredientNote(value) {
  return sanitizePublicText(value, '식사 구성 참고', 100);
}

function sanitizePublicText(value, fallback, maxLength) {
  const text = String(value || '').trim().replace(/\s+/g, ' ');
  if (!text || containsForbiddenPublicCopy(text)) return fallback;
  return text.slice(0, maxLength);
}

function containsForbiddenPublicCopy(value) {
  return /mg\s*\/\s*dL|혈당|당뇨|스파이크|피크|진단|치료|투약|인슐린|질병\s*(?:예방|개선|완화)/i.test(
    value,
  );
}

function burdenScoreFallback(level) {
  if (level === 'high') return 88;
  if (level === 'low') return 30;
  return 62;
}

function clampInt(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(min, Math.min(max, Math.round(number)));
}
