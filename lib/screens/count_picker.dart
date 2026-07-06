import 'package:flutter/material.dart';

/// 추천 개수 선택 위젯.
/// 프리셋 칩(3/5/10/15) + '직접 입력' 칩(선택 시 숫자 입력 필드 노출).
class CountPicker extends StatefulWidget {
  const CountPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.unit = '개',
    this.max = 30,
    this.presets = const [3, 5, 10, 15],
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String unit; // '곳' / '개'
  final int max; // 직접 입력 상한
  final List<int> presets;

  @override
  State<CountPicker> createState() => _CountPickerState();
}

class _CountPickerState extends State<CountPicker> {
  late final TextEditingController _customCtrl;
  bool _custom = false;

  @override
  void initState() {
    super.initState();
    _custom = !widget.presets.contains(widget.value);
    _customCtrl =
        TextEditingController(text: _custom ? widget.value.toString() : '');
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _applyCustom(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null) return;
    final clamped = n.clamp(1, widget.max);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...widget.presets.map((c) {
              return ChoiceChip(
                label: Text('$c${widget.unit}'),
                selected: !_custom && widget.value == c,
                onSelected: (_) {
                  setState(() => _custom = false);
                  widget.onChanged(c);
                },
              );
            }),
            ChoiceChip(
              label: const Text('직접 입력'),
              selected: _custom,
              onSelected: (_) {
                setState(() => _custom = true);
                if (_customCtrl.text.trim().isNotEmpty) {
                  _applyCustom(_customCtrl.text);
                }
              },
            ),
          ],
        ),
        if (_custom) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _customCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixText: widget.unit,
                    hintText: '1~${widget.max}',
                  ),
                  onChanged: _applyCustom,
                ),
              ),
              const SizedBox(width: 10),
              Text('최대 ${widget.max}${widget.unit}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ],
      ],
    );
  }
}
