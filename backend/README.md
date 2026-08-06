# GlucoLog Gemini API 서버

Flutter APK에 Gemini API 키를 넣지 않고, PC 또는 배포 서버가 Gemini를 대신 호출하는 구조입니다.

```text
GlucoLog 앱 → GlucoLog Node 서버 → Gemini API
```

앱에는 서버 주소만 들어가고 Gemini 키는 `backend/.env` 또는 배포 서비스의 환경 변수에만 저장됩니다.

## 1. API 키 만들기

1. `https://aistudio.google.com/app/apikey`에 Google 계정으로 로그인합니다.
2. `Create API key`를 눌러 새 키를 만듭니다.
3. 발급된 키를 복사합니다.
4. 키를 채팅, GitHub, Flutter 코드 또는 APK에 넣지 마세요.

## 2. 이 PC에서 키 설정하기

PowerShell에서 프로젝트의 `backend` 폴더로 이동합니다.

```powershell
cd C:\경로\food_ai_app\backend
Copy-Item .env.example .env
notepad .env
```

`.env`의 첫 줄만 실제 키로 바꿉니다.

```env
GEMINI_API_KEY=여기에_발급받은_키
GEMINI_MODEL=gemini-2.5-flash
HOST=127.0.0.1
PORT=8787
```

`.gitignore`가 `backend/.env`를 제외하므로 키는 프로젝트 백업이나 Git에 포함되지 않습니다.

## 3. 서버 설치 및 실행

Node.js가 설치된 터미널에서 한 번만 의존성을 설치합니다.

```powershell
cd C:\경로\food_ai_app\backend
npm install
npm start
```

정상 실행되면 아래 주소로 상태를 확인합니다.

```text
http://127.0.0.1:8787/health
```

응답의 `hasGeminiKey`가 `true`여야 실제 Gemini가 사용됩니다.

```json
{"ok":true,"provider":"gemini","model":"gemini-2.5-flash","hasGeminiKey":true}
```

`false`라면 서버는 앱 흐름 확인용 임시 결과를 반환합니다. `.env`를 수정했다면 실행 중인 서버를 종료하고 다시 `npm start` 하세요.

## 4. Android Emulator에서 실행

에뮬레이터의 `10.0.2.2`는 이 PC의 `127.0.0.1`을 뜻합니다.

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8787
```

APK를 만들 때도 같은 주소를 지정합니다.

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8787
```

## 5. 실제 휴대폰에서 테스트

PC와 휴대폰을 같은 Wi-Fi에 연결하고 `.env`의 서버 주소를 아래처럼 바꿉니다.

```env
HOST=0.0.0.0
PORT=8787
```

`ipconfig`에서 PC의 IPv4 주소를 찾은 뒤 앱 서버 주소에 넣습니다.

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8787
```

`192.168.0.10`은 예시이며 실제 PC 주소로 바꿔야 합니다. Windows 방화벽에서 Node.js의 개인 네트워크 접근도 허용해야 합니다.

## 6. Render Web Service 배포

프로젝트를 비공개 GitHub 저장소에 올린 뒤 Render에서 **New > Web Service**를 선택하고 저장소를 연결합니다. `backend/.env`는 Git에 포함하지 말고 Render 환경 변수 화면에 키를 직접 등록합니다.

Render 서비스 설정값은 다음과 같습니다.

| 항목 | 값 |
| --- | --- |
| Runtime | `Node` |
| Root Directory | `backend` |
| Build Command | `npm install` |
| Start Command | `npm start` |
| Health Check Path | `/health` |

**Environment**에는 다음 값만 등록합니다.

```env
GEMINI_API_KEY=실제_Gemini_API_키
GEMINI_MODEL=gemini-2.5-flash
HOST=0.0.0.0
```

`PORT`는 Render가 실행할 때 자동으로 제공하므로 직접 만들거나 `8787`로 고정하지 않습니다. 서버는 Render가 제공한 `PORT`를 우선 사용하고, 로컬에서만 기본값 `8787`을 사용합니다.

배포가 끝나면 Render가 발급한 주소에 `/health`를 붙여 확인합니다.

```text
https://서비스이름.onrender.com/health
```

다음과 같이 `ok`와 `hasGeminiKey`가 모두 `true`로 나오기 전에는 Flutter의 기본 API 주소나 APK를 변경하지 않습니다.

```json
{"ok":true,"provider":"gemini","model":"gemini-2.5-flash","hasGeminiKey":true}
```

상태 확인이 끝난 다음 단계에서만 Render 기본 주소를 사용해 Flutter APK를 다시 빌드합니다. 주소 끝에는 `/health`를 넣지 않습니다.

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://서비스이름.onrender.com
```

## API 동작 흐름

- `GET /health`: 서버와 키 설정 상태 확인
- `POST /api/identify-food`: 사진을 받아 음식 후보 목록 생성
- `POST /api/analyze-meal`: 확인된 메뉴명과 사진으로 영양 성분, 예상 혈당 상승폭, 코칭 생성

사진은 Flutter 앱에서 JPEG 바이트를 Base64 문자열로 바꿔 서버로 전송합니다. 서버는 Gemini의 구조화 JSON 응답을 숫자 범위에 맞게 정리한 뒤 앱에 반환합니다.

## 주의

- 결과는 음식 사진 기반 AI 추정값입니다.
- 실제 혈당 측정값, 진단, 치료 또는 투약 판단을 대신하지 않습니다.
- 공개 배포 시에는 HTTPS, 요청 크기 제한, 사용자 인증, 호출 횟수 제한, 로그의 개인정보 제거가 추가로 필요합니다.
