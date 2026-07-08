import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';
import '../services/update_service.dart';
import 'input_screen.dart';
import 'menu_input_screen.dart';
import 'settings_screen.dart';
import 'update_dialog.dart';

/// 홈: 두 가지 모드 선택 (맛집 찾기 / 뭐 먹지?).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    // 앱 시작 시: 위치 권한 요청 후 조용히 업데이트 확인.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
      _checkUpdate();
    });
  }

  /// 앱 시작 시 위치 권한을 1회 요청한다.
  /// 이미 허용/영구 거부된 경우 시스템이 다이얼로그를 띄우지 않으므로 그대로 둔다.
  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final info = await _updateService.checkForUpdate();
    if (info == null || !mounted) return;
    await UpdateDialog.maybeShow(context,
        info: info, service: _updateService);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('맛집 도우미'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(app.settings.provider.label,
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'AI 설정',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('무엇을 도와드릴까요?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _ModeCard(
              icon: Icons.restaurant,
              color: Colors.redAccent,
              title: '맛집 찾기',
              subtitle: '지역·예산·분위기로 딱 맞는 식당을 추천받아요',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InputScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              icon: Icons.lightbulb_outline,
              color: Colors.orange,
              title: '오늘 뭐 먹지?',
              subtitle: '기분·상황을 고르면 메뉴를 골라드려요',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MenuInputScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
