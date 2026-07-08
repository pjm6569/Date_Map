/// 앱에 기본으로 박아두는 키/설정값 템플릿.
///
/// 사용법:
///   1) 이 파일을 같은 폴더에 `secrets.dart` 로 복사한다.
///   2) 아래 값들을 실제 키로 채운다.
///   3) `secrets.dart` 는 .gitignore 에 포함되어 git 에 올라가지 않는다.
///
/// (앱 내 'AI 설정' 화면에서 저장한 값이 있으면 그 값이 이 기본값보다 우선합니다.)
class Secrets {
  /// 네이버 클라우드 플랫폼 - Maps 의 client id (ncpKeyId). 지도 표시에 필수.
  static const naverMapClientId = 'YOUR_NAVER_MAP_CLIENT_ID';

  /// 네이버 개발자센터 - 검색 API 의 Client ID / Secret. 맛집 실존 검색에 사용.
  static const naverSearchClientId = 'YOUR_NAVER_SEARCH_CLIENT_ID';
  static const naverSearchClientSecret = 'YOUR_NAVER_SEARCH_CLIENT_SECRET';

  /// (선택) AI 공급자 기본 API 키. 비워두면 설정 화면에서 직접 입력.
  static const defaultAiApiKey = '';
}
