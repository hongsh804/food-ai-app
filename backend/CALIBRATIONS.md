# 혈당 보정 규칙

보정 규칙은 Gemini가 만든 `estimatedGlucoseRise`를 서버에서 한 번 더
조정합니다. 기존 영양 분석은 그대로 Gemini를 사용합니다. 앱이 명시적으로
`calibrationProfileId`를 보내면 해당 제품 프로필을 우선 적용하고, 프로필을
보내지 않았을 때만 음식명과 정확히 일치하는 활성 메뉴 규칙을 자동 적용합니다.

## 보정 모드

- `fixed`: 최종 상승폭을 `adjustment_value`로 고정
- `delta`: Gemini 상승폭에 `adjustment_value`를 더함
- `multiplier`: Gemini 상승폭에 `adjustment_value`를 곱함

최종 상승폭은 0~140 범위로 제한됩니다. 위험도는 최종 상승폭으로 다시
계산되며, `score_override`가 없으면 부담 점수는 `최종 상승폭 * 1.6`으로
계산해 0~100 범위로 제한합니다.

규칙은 `active`만 켠다고 적용되지 않습니다. 최소 3건의 측정 표본과
`approved_at`, `approved_by`가 모두 있어야 합니다. 검토되지 않은 규칙이나
표본이 부족한 규칙은 카탈로그·사진 추천·메뉴 자동 보정에서 모두 제외됩니다.

## 저장소 선택

1. `DATABASE_URL`이 있으면 PostgreSQL을 먼저 조회합니다.
2. DB 연결 또는 조회에 실패하면 `data/calibrations.json`을 읽습니다.
3. `DATABASE_URL`이 없으면 JSON만 사용합니다.

Render의 로컬 디스크는 영속 데이터 저장소로 사용하지 않습니다. JSON은
Git으로 버전 관리되는 읽기 전용 배포 데이터이며, 운영 중 자주 수정할
데이터는 PostgreSQL에 저장합니다.

PostgreSQL을 사용할 때 다음 migration을 한 번 실행합니다.

```text
migrations/001_calibrations.sql
```

외부 PostgreSQL이 TLS를 요구하면 기본 설정을 그대로 사용합니다. 로컬처럼
TLS가 없는 DB만 `DATABASE_SSL=false`를 설정합니다.

`calibration_measurements`에는 보정 계산의 근거가 되는 원자료를 보관합니다.
제품 프로필 또는 메뉴 규칙 중 하나에만 연결되며, 식전값·식후 최고값·최고값
도달 시간·분량·AI 원본 예상값을 기록합니다. `user_code`에는 이름·전화번호가
아닌 익명 코드만 사용하고, 메모에도 개인정보를 넣지 않습니다.

## 규칙 우선순위

1. 요청의 유효한 `calibrationProfileId`
2. `calibrationProfileId`가 없을 때 메뉴명 또는 별칭 정확 매칭
3. 일치 규칙이 없으면 보정하지 않음

잘못되거나 비활성인 `calibrationProfileId`가 요청되면 메뉴 규칙으로 조용히
우회하지 않습니다. 메뉴 규칙끼리 같은 이름 또는 별칭에 일치하면 숫자가 큰
`priority` 규칙 하나만 적용합니다. 공백을 정리하고 대소문자를 무시하지만
부분 문자열이나 유사도 검색은 하지 않습니다.

## 데이터 예시

처음 포함된 JSON 프로필은 `active: false`라서 어떤 분석에도 영향을 주지
않습니다. 실제 자료 검토 후 다음과 같은 행을 DB에 등록할 수 있습니다.

```sql
INSERT INTO calibration_profiles (
  id, name, description, sample_count, mode, adjustment_value,
  score_override, note, active, approved_at, approved_by, version
) VALUES (
  'low-sugar-flour-gimbap',
  '저당밀가루 김밥',
  '등록된 1줄 분량 기준',
  12,
  'delta',
  20,
  NULL,
  '등록 측정 자료 12건 기준 보정',
  TRUE,
  NOW(),
  'data-review-2026-08',
  1
);
```

동일한 이미지 파일만 자동 추천하려면 원본 파일의 SHA-256을 소문자로
등록합니다.

```powershell
(Get-FileHash -Algorithm SHA256 -LiteralPath '.\reference.jpg').Hash.ToLower()
```

```sql
INSERT INTO calibration_image_hashes (sha256, profile_id, active)
VALUES ('64자리_sha256', 'low-sugar-flour-gimbap', TRUE);
```

사진을 다시 촬영하거나 편집·압축하면 SHA-256이 달라지므로 자동 확정하지
않습니다. 저당밀가루처럼 사진만으로 구별할 수 없는 재료는 사용자가 앱에서
프로필을 직접 선택해야 합니다.

메뉴별 자동 보정은 별도 테이블에 등록합니다.

```sql
INSERT INTO calibration_menu_rules (
  id, name, aliases, sample_count, mode, adjustment_value,
  score_override, note, priority, active, approved_at, approved_by, version
) VALUES (
  'gimbap-default',
  '김밥',
  ARRAY['일반 김밥', '야채 김밥'],
  20,
  'delta',
  20,
  NULL,
  '등록 측정 자료 20건 기준 보정',
  100,
  TRUE,
  NOW(),
  'data-review-2026-08',
  1
);
```

위 예시는 Gemini 상승폭이 60일 때 20을 더해 최종 80으로 만듭니다. 항상
80으로 고정하려면 `mode='fixed'`, `adjustment_value=80`을 사용합니다.

## 읽기 API

- `GET /api/calibrations/catalog`
  - 활성 프로필의 `id`, `name`, `description`, `sampleCount`만 반환
- `POST /api/identify-food`
  - 기존 응답에 `profiles`, `suggestedProfileId` 추가
  - `suggestedProfileId`는 정확한 이미지 SHA-256이 등록된 경우에만 설정
- `POST /api/analyze-meal`
  - 요청에 선택적 `calibrationProfileId` 추가
  - 기존 분석 필드를 유지하고 `calibration` 메타데이터 추가
  - 프로필 ID가 없으면 음식명과 일치하는 활성 메뉴 규칙을 자동 적용

공개 서버에는 보정값을 수정하는 쓰기 API가 없습니다. 데이터 변경은 DB
관리 화면 또는 승인된 배포 커밋으로만 수행합니다.
