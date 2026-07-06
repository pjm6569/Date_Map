import 'package:flutter/widgets.dart';

import 'models/ai_settings.dart';

/// 앱 전역에서 공유하는 AI 설정. 하위 어디서든 [AppScope.of] 로 접근.
class AppState extends ChangeNotifier {
  AppState(this._settings);

  AiSettings _settings;
  AiSettings get settings => _settings;

  set settings(AiSettings value) {
    _settings = value;
    notifyListeners();
  }
}

/// [AppState] 를 위젯 트리에 주입하는 InheritedNotifier.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope 를 찾을 수 없습니다.');
    return scope!.notifier!;
  }
}
