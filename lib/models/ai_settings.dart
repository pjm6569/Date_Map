import 'package:shared_preferences/shared_preferences.dart';

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

  const AiSettings({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });

  /// 아직 아무것도 설정 안 된 초기값(OpenAI 기본).
  factory AiSettings.initial() => const AiSettings(
        provider: AiProvider.openai,
        apiKey: '',
        model: 'gpt-4o-mini',
        baseUrl: 'https://api.openai.com/v1',
      );

  bool get isConfigured => apiKey.trim().isNotEmpty;

  AiSettings copyWith({
    AiProvider? provider,
    String? apiKey,
    String? model,
    String? baseUrl,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  // ── 영속화 (shared_preferences) ──────────────────────────────
  // 공급자별로 키/모델/baseUrl 을 따로 저장해서, 공급자를 바꿔도 각자 값이 유지되게 함.
  static String _k(AiProvider p, String field) => 'ai_${p.name}_$field';
  static const _kProvider = 'ai_selected_provider';

  static Future<AiSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final provider = AiProvider.fromName(sp.getString(_kProvider));
    return AiSettings(
      provider: provider,
      apiKey: sp.getString(_k(provider, 'key')) ?? '',
      model: sp.getString(_k(provider, 'model')) ?? provider.defaultModel,
      baseUrl:
          sp.getString(_k(provider, 'baseUrl')) ?? provider.defaultBaseUrl,
    );
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProvider, provider.name);
    await sp.setString(_k(provider, 'key'), apiKey);
    await sp.setString(_k(provider, 'model'), model);
    await sp.setString(_k(provider, 'baseUrl'), baseUrl);
  }

  /// 특정 공급자에 저장돼 있던 값을 불러온다(공급자 전환 시 사용).
  static Future<AiSettings> loadFor(AiProvider provider) async {
    final sp = await SharedPreferences.getInstance();
    return AiSettings(
      provider: provider,
      apiKey: sp.getString(_k(provider, 'key')) ?? '',
      model: sp.getString(_k(provider, 'model')) ?? provider.defaultModel,
      baseUrl:
          sp.getString(_k(provider, 'baseUrl')) ?? provider.defaultBaseUrl,
    );
  }
}
