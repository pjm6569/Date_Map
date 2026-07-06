# date_map — 식당 중심 데이트 코스 추천 앱 (MVP)

백엔드 없이 디바이스가 직접 OpenAI(gpt-4o-mini)를 호출하고, 결과 좌표를
네이버 지도에 그려주는 안드로이드 Flutter 앱입니다.

## 화면 흐름
1. **입력 폼** — 위치 TextField + 예산/분위기/음식종류 ChoiceChip → `데이트 코스 생성`
2. **로딩** — CircularProgressIndicator 대기 화면
3. **결과** — 상단 네이버 지도(마커 3 + Polyline) / 하단 DraggableScrollableSheet 타임라인 카드
   - 각 카드의 `네이버 지도로 보기` → `https://map.naver.com/v5/search/{장소명}` 아웃링크

## 폴더 구조
```
lib/
├─ main.dart                      # 진입점 + 3단계 상태 머신(입력→로딩→결과)
├─ config.dart                    # API 키/네이버 client id (dart-define 주입)
├─ models/date_course.dart        # DateCourse / Restaurant / Cafe / Parking + fromJson
├─ services/openai_service.dart   # gpt-4o-mini POST 호출
└─ screens/
   ├─ input_screen.dart
   ├─ loading_screen.dart
   └─ result_screen.dart          # NaverMap + DraggableScrollableSheet
```

## 셋업

### 1) 패키지 설치
```bash
flutter pub get
```

### 2) 네이버 지도 준비 (필수)
- 네이버 클라우드 플랫폼 → **Maps → Mobile Dynamic Map** 앱 등록 후 `client id(ncpKeyId)` 발급.
- 등록 시 앱 패키지명을 실제 값과 일치시킵니다.
- `android/app/src/main/AndroidManifest.xml` 의 `<application>` 안에 인터넷/위치 권한과
  최소 SDK 를 확인하세요. (flutter_naver_map 은 minSdk 23 이상 필요 →
  `android/app/build.gradle` 의 `minSdkVersion 23`)

```xml
<manifest ...>
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  ...
</manifest>
```

### 3) url_launcher — 외부 앱(네이버 지도/브라우저) 허용
`AndroidManifest.xml` 의 `<manifest>` 바로 아래에 추가:
```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
</queries>
```

### 4) 키 주입 후 실행
소스에 키를 하드코딩하지 말고 `--dart-define` 으로 주입합니다.
```bash
flutter run \
  --dart-define=OPENAI_API_KEY=sk-xxxxxxxx \
  --dart-define=NAVER_MAP_CLIENT_ID=xxxxxxxx
```

## ⚠️ 보안 주의
클라이언트에 OpenAI 키를 넣는 것은 **개인 MVP 한정 편법**입니다. 앱을 실제 배포하면
디컴파일로 키가 노출될 수 있으니, 배포 전에는 반드시 서버리스 함수/프록시를 두고
키를 숨기세요.

## 패키지 버전 참고
`flutter_naver_map` 은 버전마다 API(`NaverMapSdk.instance.initialize` vs
`FlutterNaverMap().init`, 오버레이 클래스명)가 다릅니다. 본 코드는 1.3.x 기준입니다.
`flutter pub get` 후 빌드 에러가 나면 설치된 버전의 예제에 맞춰
`main.dart` 초기화부와 `result_screen.dart` 의 오버레이 API 를 조정하세요.
