import 'secrets.dart';

/// 앱 기본 설정값.
///
/// 우선순위: --dart-define 으로 넘긴 값 > secrets.dart 값.
/// (앱 내 'AI 설정' 화면에서 사용자가 저장한 값은 이 기본값보다 우선합니다.)
class AppConfig {
  /// 네이버 클라우드 플랫폼 - Maps 의 client id (ncpKeyId).
  static const naverMapClientId = String.fromEnvironment(
    'NAVER_MAP_CLIENT_ID',
    defaultValue: Secrets.naverMapClientId,
  );

  /// 네이버 개발자센터 - 검색 API Client ID / Secret.
  static const naverSearchClientId = String.fromEnvironment(
    'NAVER_SEARCH_CLIENT_ID',
    defaultValue: Secrets.naverSearchClientId,
  );
  static const naverSearchClientSecret = String.fromEnvironment(
    'NAVER_SEARCH_CLIENT_SECRET',
    defaultValue: Secrets.naverSearchClientSecret,
  );

  /// (선택) AI 공급자 기본 API 키.
  static const defaultAiApiKey = String.fromEnvironment(
    'AI_API_KEY',
    defaultValue: Secrets.defaultAiApiKey,
  );

  /// 플레이스홀더(미설정) 여부 판단.
  static bool _isSet(String v) =>
      v.isNotEmpty && !v.startsWith('YOUR_');

  static bool get hasNaverSearchDefault =>
      _isSet(naverSearchClientId) && _isSet(naverSearchClientSecret);
}
