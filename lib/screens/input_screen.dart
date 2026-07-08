import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/llm_service.dart';
import '../services/naver_search_service.dart';
import 'budget_picker.dart';
import 'count_picker.dart';
import 'llm_runner.dart';
import 'result_screen.dart';

/// 맛집 찾기 입력 폼.
/// [prefillCuisine] 이 있으면(메뉴 추천에서 넘어온 경우) 음식 종류/추가요청에 반영.
class InputScreen extends StatefulWidget {
  const InputScreen({super.key, this.prefillCuisine});

  final String? prefillCuisine;

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _locationCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();

  // 예산: 숫자 직접 입력 (기본 1~3만원).
  int _minBudget = 10000;
  int _maxBudget = 30000;

  static const _moods = ['감성적인', '트렌디한', '조용한', '활기찬', '고급스러운', '캐주얼한'];
  static const _cuisines = ['한식', '양식', '일식', '중식', '아시안', '분식', '고기', '해산물'];

  final Set<String> _selectedMoods = {};
  final Set<String> _selectedCuisines = {};
  int _count = 5;

  @override
  void initState() {
    super.initState();
    // 메뉴에서 넘어온 경우: 그 메뉴명을 추가 요청에 넣어 검색 정확도를 높인다.
    final prefill = widget.prefillCuisine;
    if (prefill != null && prefill.isNotEmpty) {
      _extraCtrl.text = '$prefill 맛집 위주로 추천해줘';
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final location = _locationCtrl.text.trim();
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('찾을 지역을 입력해주세요.')),
      );
      return;
    }
    // 네이버 지역검색 키 확인 (실존 가게 검색에 필수).
    final settings = AppScope.of(context).settings;
    if (!settings.hasNaverSearch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 설정에서 네이버 검색 API 키를 먼저 입력해주세요.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final req = SearchRequest(
      location: location,
      minBudget: _minBudget,
      maxBudget: _maxBudget,
      moods: _selectedMoods.toList(),
      cuisines: _selectedCuisines.toList(),
      count: _count,
      extraPrompt: _extraCtrl.text,
    );

    final naverSearch = NaverSearchService(
      clientId: settings.naverSearchClientId,
      clientSecret: settings.naverSearchClientSecret,
    );

    final result = await runLlm<dynamic>(
      context,
      loadingMessage: '조건에 맞는 맛집을 찾고 있어요...',
      task: (client) => client.search(req, naverSearch: naverSearch),
    );
    naverSearch.dispose();
    if (result == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
  }

  String _won(int total) {
    if (total == 0) return '0원';
    final man = total ~/ 10000;
    final cheon = (total % 10000) ~/ 1000;
    final rest = total % 1000;
    final parts = <String>[
      if (man > 0) '$man만',
      if (cheon > 0) '$cheon천',
      if (rest > 0) '$rest',
    ];
    return '${parts.join(' ')}원';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('맛집 찾기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('어디서 찾을까요?'),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '예) 서울 성수동, 부산 서면',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('1인 예산'),
                Text('${_won(_minBudget)} ~ ${_won(_maxBudget)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 8),
            BudgetPicker(
              min: _minBudget,
              max: _maxBudget,
              onChanged: (lo, hi) => setState(() {
                _minBudget = lo;
                _maxBudget = hi;
              }),
            ),
            const SizedBox(height: 16),
            _label('분위기  (선택 안 해도 돼요)'),
            const SizedBox(height: 8),
            _multiChips(_moods, _selectedMoods),
            const SizedBox(height: 20),
            _label('음식 종류  (여러 개 가능)'),
            const SizedBox(height: 8),
            _multiChips(_cuisines, _selectedCuisines),
            const SizedBox(height: 20),
            _label('몇 곳 추천받을까요?'),
            const SizedBox(height: 8),
            CountPicker(
              value: _count,
              unit: '곳',
              onChanged: (v) => setState(() => _count = v),
            ),
            const SizedBox(height: 20),
            _label('AI 에게 더 요청할 게 있나요?  (선택)'),
            const SizedBox(height: 8),
            TextField(
              controller: _extraCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예) 주차 가능한 곳, 웨이팅 짧은 곳 위주로',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.search),
                label: const Text('맛집 찾기', style: TextStyle(fontSize: 16)),
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
