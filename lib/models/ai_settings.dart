import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 지원하는 AI 공급자.
enum AiProvider {
  openai('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
  gemini('Google Gemini',
      'https://generativelanguage.googleapis.com/v1beta', 'gemini-2.0-flash'),
  custom('Custom (vLLM 등)', 'http://localhost:8000/v1', 'default');

  const AiProvider(this.label, this.defaultBaseUrl, this.defaultModel);

  /// 사용자에게 보여줄 이름.
  final String label;

  /// 기본 API 베이스 URL.
  final String defaultBaseUrl;

  /// 기본 모델명.
  final String defaultModel;

  static AiProvider fromName(String? name) => AiProvider.values.firstWhere(
        (p) => p.name == name,
        orElse: () => AiProvider.openai,
      );
}

/// 앱에 저장되는 AI 설정.
///
/// - [apiKey]     : 각 공급자의 API 키
/// - [model]      : 모델명 (예: gpt-4o-mini, gemini-1.5-flash, vLLM 모델명)
/// - [baseUrl]    : OpenAI 호환/Custom 에서 쓰는 엔드포인트. Gemini 는 기본값 사용.
class AiSettings {
  final AiProvider provider;
  final String apiKey;
  final String model;
  final String baseUrl;

  // 네이버 지역검색 API (개발자센터) — 실존 가게 검색용. 공급자와 무관하게 공유.
  final String naverSearchClientId;
  final String naverSearchClientSecret;

  const AiSettings({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.baseUrl,
    this.naverSearchClientId = '',
    this.naverSearchClientSecret = '',
  });

  /// 아직 아무것도 설정 안 된 초기값(OpenAI 기본).
  factory AiSettings.initial() => const AiSettings(
        provider: AiProvider.openai,
        apiKey: '',
        model: 'gpt-4o-mini',
        baseUrl: 'https://api.openai.com/v1',
      );

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// 네이버 지역검색 사용 가능 여부. (플레이스홀더 'YOUR_...' 는 미설정으로 취급)
  bool get hasNaverSearch =>
      _isRealKey(naverSearchClientId) &&
      _isRealKey(naverSearchClientSecret);

  static bool _isRealKey(String v) =>
      v.trim().isNotEmpty && !v.startsWith('YOUR_');

  AiSettings copyWith({
    AiProvider? provider,
    String? apiKey,
    String? model,
    String? baseUrl,
    String? naverSearchClientId,
    String? naverSearchClientSecret,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
      naverSearchClientId: naverSearchClientId ?? this.naverSearchClientId,
      naverSearchClientSecret:
          naverSearchClientSecret ?? this.naverSearchClientSecret,
    );
  }

  // ── 영속화 (shared_preferences) ──────────────────────────────
  // 공급자별로 키/모델/baseUrl 을 따로 저장해서, 공급자를 바꿔도 각자 값이 유지되게 함.
  static String _k(AiProvider p, String field) => 'ai_${p.name}_$field';
  static const _kProvider = 'ai_selected_provider';
  static const _kNaverId = 'naver_search_client_id';
  static const _kNaverSecret = 'naver_search_client_secret';

  static Future<AiSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final provider = AiProvider.fromName(sp.getString(_kProvider));
    // 네이버 검색 키: 저장값이 없으면 secrets.dart 기본값 사용.
    final savedNaverId = sp.getString(_kNaverId);
    final savedNaverSecret = sp.getString(_kNaverSecret);
    return AiSettings(
      provider: provider,
      apiKey: (sp.getString(_k(provider, 'key')) ?? '').isNotEmpty
          ? sp.getString(_k(provider, 'key'))!
          : AppConfig.defaultAiApiKey,
      model: sp.getString(_k(provider, 'model')) ?? provider.defaultModel,
      baseUrl:
          sp.getString(_k(provider, 'baseUrl')) ?? provider.defaultBaseUrl,
      naverSearchClientId: (savedNaverId != null && savedNaverId.isNotEmpty)
          ? savedNaverId
          : AppConfig.naverSearchClientId,
      naverSearchClientSecret:
          (savedNaverSecret != null && savedNaverSecret.isNotEmpty)
              ? savedNaverSecret
              : AppConfig.naverSearchClientSecret,
    );
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProvider, provider.name);
    await sp.setString(_k(provider, 'key'), apiKey);
    await sp.setString(_k(provider, 'model'), model);
    await sp.setString(_k(provider, 'baseUrl'), baseUrl);
    await sp.setString(_kNaverId, naverSearchClientId);
    await sp.setString(_kNaverSecret, naverSearchClientSecret);
  }

  /// 특정 공급자에 저장돼 있던 값을 불러온다(공급자 전환 시 사용).
  /// 네이버 검색 키는 공급자 무관 공유값이므로 [current] 에서 이어받는다.
  static Future<AiSettings> loadFor(AiProvider provider,
      {AiSettings? current}) async {
    final sp = await SharedPreferences.getInstance();
    return AiSettings(
      provider: provider,
      apiKey: sp.getString(_k(provider, 'key')) ?? '',
      model: sp.getString(_k(provider, 'model')) ?? provider.defaultModel,
      baseUrl:
          sp.getString(_k(provider, 'baseUrl')) ?? provider.defaultBaseUrl,
      naverSearchClientId: current?.naverSearchClientId ??
          sp.getString(_kNaverId) ??
          '',
      naverSearchClientSecret: current?.naverSearchClientSecret ??
          sp.getString(_kNaverSecret) ??
          '',
    );
  }
}
