/// 앱 실행에 필요한 빌드타임 설정값.
///
/// AI 공급자/키는 이제 앱 내 'AI 설정' 화면에서 입력·저장합니다 ([AiSettings]).
/// 여기 남은 건 앱 실행 전에 반드시 필요한 네이버 지도 client id 뿐입니다.
///
///   flutter run --dart-define=NAVER_MAP_CLIENT_ID=xxxx
class AppConfig {
  /// 네이버 클라우드 플랫폼 - Maps 의 client id (ncpKeyId).
  static const naverMapClientId =
      String.fromEnvironment('NAVER_MAP_CLIENT_ID', defaultValue: '');
}
