import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/ai_settings.dart';

/// AI 공급자/키/모델/엔드포인트를 설정하는 화면.
/// 저장 시 [AppState] 에 반영하고 화면을 닫는다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AiProvider _provider;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _baseUrlCtrl;
  bool _obscureKey = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final initial = AppScope.of(context).settings;
    _provider = initial.provider;
    _keyCtrl = TextEditingController(text: initial.apiKey);
    _modelCtrl = TextEditingController(text: initial.model);
    _baseUrlCtrl = TextEditingController(text: initial.baseUrl);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  /// 공급자를 바꾸면 그 공급자에 저장돼 있던 값(없으면 기본값)을 필드에 반영.
  Future<void> _onProviderChanged(AiProvider p) async {
    final saved = await AiSettings.loadFor(p);
    setState(() {
      _provider = p;
      _keyCtrl.text = saved.apiKey;
      _modelCtrl.text = saved.model.isEmpty ? p.defaultModel : saved.model;
      _baseUrlCtrl.text =
          saved.baseUrl.isEmpty ? p.defaultBaseUrl : saved.baseUrl;
    });
  }

  Future<void> _save() async {
    final settings = AiSettings(
      provider: _provider,
      apiKey: _keyCtrl.text.trim(),
      model: _modelCtrl.text.trim().isEmpty
          ? _provider.defaultModel
          : _modelCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim().isEmpty
          ? _provider.defaultBaseUrl
          : _baseUrlCtrl.text.trim(),
    );
    await settings.save();
    if (!mounted) return;
    AppScope.of(context).settings = settings;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Gemini 는 baseUrl 을 사용자에게 노출할 필요가 적지만, Custom/OpenAI 는 중요.
    final showBaseUrl = _provider != AiProvider.gemini;
    final keyHint = switch (_provider) {
      AiProvider.openai => 'sk-... (platform.openai.com)',
      AiProvider.gemini => 'AI... (aistudio.google.com)',
      AiProvider.custom => 'vLLM/서버의 API 키 (없으면 아무 값)',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 설정'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('AI 공급자',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AiProvider.values.map((p) {
              return ChoiceChip(
                label: Text(p.label),
                selected: _provider == p,
                onSelected: (_) => _onProviderChanged(p),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          const Text('API 키',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              hintText: keyHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('모델',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _modelCtrl,
            decoration: InputDecoration(
              hintText: _provider.defaultModel,
              border: const OutlineInputBorder(),
            ),
          ),

          if (showBaseUrl) ...[
            const SizedBox(height: 20),
            const Text('엔드포인트 (Base URL)',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: _provider.defaultBaseUrl,
                helperText: _provider == AiProvider.custom
                    ? 'vLLM 예) http://192.168.0.10:8000/v1'
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Text(
              '⚠️ API 키는 이 기기에만 저장됩니다. 개인 MVP 용도이며, '
              '배포 시에는 서버를 통해 키를 숨기는 것을 권장합니다.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
