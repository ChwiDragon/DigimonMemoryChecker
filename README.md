# DigiMemory Checker

디지몬 카드게임의 메모리 게이지를 폰 한 대로 관리하는 2인용 비공식 도구입니다.

**웹에서 바로 쓰기:** https://chwidragon.github.io/DigimonMemoryChecker/

- 홈 화면에 앱처럼 설치할 수 있습니다. 안드로이드 크롬은 메뉴(⋮) → **앱 설치**, 아이폰 사파리는 공유 → **홈 화면에 추가**.
- 설치하면 전체화면으로 열리고, 인터넷 없이도 동작합니다.

## 파일 (`memorychecker-app/`)

| 파일 | 내용 |
|---|---|
| `memorycheckerapk.html` | 앱의 원본 코드 (안드로이드 앱에 들어가는 화면) |
| `memorychecker.html` | 웹 버전. `tools/make_browser.py`가 `memorycheckerapk.html`에서 만듦 (직접 고치지 않음) |
| `memorychecker.apk` | 안드로이드 앱 (직접 설치용) |
| `index.html`, `manifest.webmanifest`, `sw.js`, `pwa/` | 웹 앱 설치(PWA)용 파일 |
| `android/`, `rebuild.ps1` | 안드로이드 앱 빌드 (Capacitor) |

개인정보처리방침: [PRIVACY.md](PRIVACY.md)

이 앱은 비공식 팬메이드 도구이며 Bandai 및 디지몬 카드게임의 권리자와 관련이 없습니다.
