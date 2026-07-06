import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/llm_service.dart';
import 'loading_screen.dart';

/// AI 요청을 공통 처리한다.
/// - API 키 미설정 시 스낵바 안내 후 null 반환
/// - 로딩 화면을 push 했다가 결과가 오면 pop
/// - 성공 시 결과 반환, 실패 시 스낵바 후 null 반환
///
/// [task] 는 [LlmClient] 를 받아 결과를 만드는 함수.
Future<T?> runLlm<T>(
  BuildContext context, {
  required String loadingMessage,
  required Future<T> Function(LlmClient client) task,
}) async {
  final app = AppScope.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (!app.settings.isConfigured) {
    messenger.showSnackBar(
      const SnackBar(content: Text('먼저 AI 설정에서 API 키를 입력해주세요.')),
    );
    return null;
  }

  // 로딩 화면 push (뒤로가기로 취소되지 않도록 PopScope 로 막음).
  navigator.push(MaterialPageRoute(
    builder: (_) => PopScope(
      canPop: false,
      child: LoadingScreen(message: loadingMessage),
    ),
  ));

  final client = LlmClient.fromSettings(app.settings);
  try {
    final result = await task(client);
    navigator.pop(); // 로딩 닫기
    return result;
  } on LlmException catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(e.message), duration: const Duration(seconds: 5)),
    );
    return null;
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('알 수 없는 오류가 발생했어요. ($e)')),
    );
    return null;
  } finally {
    client.dispose();
  }
}
