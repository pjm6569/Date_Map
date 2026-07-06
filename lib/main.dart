import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'app_state.dart';
import 'config.dart';
import 'models/ai_settings.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 네이버 지도 SDK 초기화 (지도를 그리기 전에 반드시 1회).
  await FlutterNaverMap().init(
    clientId: AppConfig.naverMapClientId,
    onAuthFailed: (ex) => debugPrint('네이버 지도 인증 실패: $ex'),
  );

  // 저장된 AI 설정 로드.
  final settings = await AiSettings.load();

  runApp(DateMapApp(appState: AppState(settings)));
}

class DateMapApp extends StatelessWidget {
  const DateMapApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: appState,
      child: MaterialApp(
        title: '맛집 도우미',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.redAccent,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
