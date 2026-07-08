import 'package:flutter/material.dart';

import '../services/llm_service.dart';
import 'count_picker.dart';
import 'llm_runner.dart';
import 'menu_result_screen.dart';

/// "오늘 뭐 먹지?" — 기분/상황을 골라 메뉴를 추천받는 입력 폼.
class MenuInputScreen extends StatefulWidget {
  const MenuInputScreen({super.key});

  @override
  State<MenuInputScreen> createState() => _MenuInputScreenState();
}

class _MenuInputScreenState extends State<MenuInputScreen> {
  final _extraCtrl = TextEditingController();

  static const _situations = [
    '혼밥',
    '데이트',
    '친구모임',
    '회식',
    '해장',
    '야식',
    '간단히',
    '든든하게',
  ];
  static const _tastes = [
    '매콤한',
    '국물있는',
    '기름진',
    '담백한',
    '달달한',
    '새콤한',
    '뜨끈한',
    '시원한',
  ];

  final Set<String> _selSituations = {};
  final Set<String> _selTastes = {};
  int _count = 5;

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final req = MenuRequest(
      situations: _selSituations.toList(),
      tastes: _selTastes.toList(),
      count: _count,
      extraPrompt: _extraCtrl.text,
    );
    final result = await runLlm<dynamic>(
      context,
      loadingMessage: '기분에 맞는 메뉴를 고르고 있어요...',
      task: (client) => client.suggestMenus(req),
    );
    if (result == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MenuResultScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘 뭐 먹지?')),
      body: SingleChildScrollView(
        // 하단은 시스템 내비게이션 바(제스처 영역)만큼 여백을 더해 버튼이 가리지 않게.
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('어떤 상황인가요?  (선택)'),
            const SizedBox(height: 8),
            _multiChips(_situations, _selSituations),
            const SizedBox(height: 20),
            _label('뭐가 당겨요?  (선택)'),
            const SizedBox(height: 8),
            _multiChips(_tastes, _selTastes),
            const SizedBox(height: 20),
            _label('몇 개 추천받을까요?'),
            const SizedBox(height: 8),
            CountPicker(
              value: _count,
              unit: '개',
              onChanged: (v) => setState(() => _count = v),
            ),
            const SizedBox(height: 20),
            _label('AI 에게 더 요청할 게 있나요?  (선택)'),
            const SizedBox(height: 8),
            TextField(
              controller: _extraCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예) 다이어트 중이야, 매운 건 빼줘, 술안주로',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('메뉴 추천받기', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _multiChips(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((opt) {
        return FilterChip(
          label: Text(opt),
          selected: selected.contains(opt),
          onSelected: (on) => setState(() {
            on ? selected.add(opt) : selected.remove(opt);
          }),
        );
      }).toList(),
    );
  }
}
