import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// 새 버전 안내 + 다운로드/설치 진행 다이얼로그.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info, required this.service});

  final UpdateInfo info;
  final UpdateService service;

  /// 업데이트가 있으면 다이얼로그를 띄운다.
  static Future<void> maybeShow(
    BuildContext context, {
    required UpdateInfo info,
    required UpdateService service,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info, service: service),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;

  Future<void> _update() async {
    setState(() => _downloading = true);
    final ok = await widget.service.downloadAndInstall(
      widget.info,
      onProgress: (p) => setState(() => _progress = p),
    );
    if (!ok && mounted) {
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업데이트에 실패했어요. 잠시 후 다시 시도해주세요.')),
      );
    }
    // 설치 인텐트가 뜨면 사용자가 설치를 진행하므로 다이얼로그는 유지.
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('새 버전 ${widget.info.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('새로운 업데이트가 있어요.'),
          if (widget.info.releaseNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(widget.info.releaseNotes,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 4),
            Text('${(_progress * 100).toStringAsFixed(0)}% 다운로드 중...',
                style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('나중에'),
              ),
              FilledButton(
                onPressed: _update,
                child: const Text('업데이트'),
              ),
            ],
    );
  }
}
