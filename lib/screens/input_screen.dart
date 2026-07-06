import 'package:flutter/material.dart';

import '../services/llm_service.dart';
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

  // 예산 슬라이더: 0원 ~ 10만원, 천원 단위.
  static const _budgetMax = 100000.0;
  RangeValues _budget = const RangeValues(10000, 50000);

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
    final req = SearchRequest(
      location: location,
      minBudget: _budget.start.round(),
      maxBudget: _budget.end.round(),
      moods: _selectedMoods.toList(),
      cuisines: _selectedCuisines.toList(),
      count: _count,
      extraPrompt: _extraCtrl.text,
    );

    final result = await runLlm<dynamic>(
      context,
      loadingMessage: '조건에 맞는 맛집을 찾고 있어요...',
      task: (client) => client.search(req),
    );
    if (result == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
  }

  String _won(double v) {
    final total = v.round();
    if (total >= _budgetMax) return '10만원+';
    if (total == 0) return '0원';
    final man = total ~/ 10000;
    final cheon = (total % 10000) ~/ 1000;
    final parts = <String>[
      if (man > 0) '$man만',
      if (cheon > 0) '$cheon천',
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
                Text('${_won(_budget.start)} ~ ${_won(_budget.end)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.redAccent)),
              ],
            ),
            RangeSlider(
              values: _budget,
              min: 0,
              max: _budgetMax,
              divisions: 100,
              labels: RangeLabels(_won(_budget.start), _won(_budget.end)),
              onChanged: (v) => setState(() => _budget = v),
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
