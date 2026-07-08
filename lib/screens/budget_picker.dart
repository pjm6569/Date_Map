import 'package:flutter/material.dart';

/// 예산 구간 선택 위젯.
/// 사용자가 [시작 / 마지막 / 단위] 를 정하면 그 설정으로 범위 슬라이더가 구성된다.
/// - 시작(bound 하한), 마지막(bound 상한), 단위(눈금 간격)
/// - 슬라이더로 실제 최소~최대 예산 구간을 고른다.
class BudgetPicker extends StatefulWidget {
  const BudgetPicker({
    super.key,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int min;
  final int max;
  final void Function(int min, int max) onChanged;

  @override
  State<BudgetPicker> createState() => _BudgetPickerState();
}

class _BudgetPickerState extends State<BudgetPicker> {
  // 슬라이더 구성 설정.
  int _lo = 0; // 시작값 (bound 하한)
  int _hi = 50000; // 마지막값 (bound 상한)
  int _step = 1000; // 단위

  late RangeValues _values; // 실제 선택 구간

  @override
  void initState() {
    super.initState();
    // 초기 선택값을 담을 수 있도록 bound 를 넉넉히.
    _hi = ((widget.max / 10000).ceil() * 10000).clamp(10000, 1000000);
    _values = RangeValues(
      widget.min.toDouble().clamp(_lo.toDouble(), _hi.toDouble()),
      widget.max.toDouble().clamp(_lo.toDouble(), _hi.toDouble()),
    );
  }

  int get _divisions => ((_hi - _lo) ~/ _step).clamp(1, 100000);

  /// 값을 단위에 맞춰 반올림하고 bound 안으로 clamp.
  double _snap(double v) {
    final snapped = (v / _step).round() * _step;
    return snapped.toDouble().clamp(_lo.toDouble(), _hi.toDouble());
  }

  void _reconfigure() {
    setState(() {
      // bound/단위 변경 후 선택값을 새 범위에 맞춤.
      _values = RangeValues(_snap(_values.start), _snap(_values.end));
    });
    widget.onChanged(_values.start.round(), _values.end.round());
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 구간 설정: 시작 / 마지막 / 단위 ──
        Row(
          children: [
            Expanded(
              child: _Stepper(
                label: '시작',
                value: _lo,
                step: _step,
                min: 0,
                max: _hi - _step,
                format: _won,
                editable: true,
                onChanged: (v) {
                  setState(() => _lo = v);
                  _reconfigure();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stepper(
                label: '마지막',
                value: _hi,
                step: _step,
                min: _lo + _step,
                max: 1000000,
                format: _won,
                editable: true,
                onChanged: (v) {
                  setState(() => _hi = v);
                  _reconfigure();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Stepper(
          label: '단위',
          value: _step,
          step: 1000,
          min: 1000,
          max: 50000,
          format: _won,
          onChanged: (v) {
            setState(() => _step = v);
            _reconfigure();
          },
        ),
        const SizedBox(height: 4),
        // ── 실제 구간 슬라이더 ──
        RangeSlider(
          values: _values,
          min: _lo.toDouble(),
          max: _hi.toDouble(),
          divisions: _divisions,
          labels: RangeLabels(
              _won(_values.start.round()), _won(_values.end.round())),
          onChanged: (v) {
            setState(() =>
                _values = RangeValues(_snap(v.start), _snap(v.end)));
            widget.onChanged(_values.start.round(), _values.end.round());
          },
        ),
      ],
    );
  }
}

/// +/- 버튼으로 값을 조절하는 작은 스테퍼.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
    this.editable = false,
  });

  final String label;
  final int value;
  final int step;
  final int min;
  final int max;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  /// true 면 가운데 값을 탭해 숫자를 직접 입력할 수 있다.
  final bool editable;

  /// 숫자 직접 입력 다이얼로그.
  Future<void> _editValue(BuildContext context) async {
    final ctrl = TextEditingController(text: value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label 금액 입력'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: '원',
            border: const OutlineInputBorder(),
            helperText: '${format(min)} ~ ${format(max)}',
          ),
          onSubmitted: (t) =>
              Navigator.of(ctx).pop(int.tryParse(t.trim())),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소')),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(format(value),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: value - step >= min
                    ? () => onChanged(value - step)
                    : null,
              ),
              Flexible(
                child: editable
                    ? InkWell(
                        onTap: () => _editValue(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: valueWidget),
                              const SizedBox(width: 2),
                              Icon(Icons.edit,
                                  size: 12, color: Colors.grey.shade500),
                            ],
                          ),
                        ),
                      )
                    : valueWidget,
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: value + step <= max
                    ? () => onChanged(value + step)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
