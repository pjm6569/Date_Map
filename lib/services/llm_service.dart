import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_settings.dart';
import '../models/menu.dart';
import '../models/restaurant.dart';

/// 맛집 찾기 조건.
class SearchRequest {
  final String location; // 위치 (필수)
  final int minBudget; // 1인 최소 예산(원)
  final int maxBudget; // 1인 최대 예산(원)
  final List<String> moods; // 분위기 (선택, 비어 있을 수 있음)
  final List<String> cuisines; // 음식 종류 (선택, 여러 개)
  final int count; // 추천받을 식당 수
  final String extraPrompt; // 추가 요청 (선택)

  const SearchRequest({
    required this.location,
    required this.minBudget,
    required this.maxBudget,
    required this.moods,
    required this.cuisines,
    required this.count,
    required this.extraPrompt,
  });
}

/// "뭐 먹지?" 메뉴 추천 조건.
class MenuRequest {
  final List<String> situations; // 상황 (예: 혼밥, 데이트, 해장)
  final List<String> tastes; // 당기는 맛 (예: 매콤, 국물)
  final int count; // 추천받을 메뉴 수
  final String extraPrompt; // 추가 요청 (선택)

  const MenuRequest({
    required this.situations,
    required this.tastes,
    required this.count,
    required this.extraPrompt,
  });
}

/// LLM 호출 실패를 사용자 친화 메시지로 감싸는 예외.
class LlmException implements Exception {
  final String message;
  const LlmException(this.message);
  @override
  String toString() => message;
}

// ── 프롬프트 (공급자 공통) ──────────────────────────────────────

String _searchSystem(int count) => '''
너는 대한민국 맛집 큐레이터다. 사용자 조건에 맞는 실존 식당 $count곳을 추천한다.

규칙:
- 반드시 $count곳을 채운다. 조건에 딱 맞는 곳이 부족하면 가장 근접한 곳으로 채운다.
- lat, lng 는 네이버 지도 기준 실제 위경도(WGS84, 소수점 6자리)로 채운다.
- price 는 1인 기준 예상 가격대를 한국어로 (예: "1인 3만원대").
- 실존 장소명을 사용한다.
- 반드시 아래 JSON 스키마만 출력한다. 설명/마크다운/코드블록 없이 순수 JSON 만.

JSON 스키마:
{
  "restaurants": [
    { "name": "식당명", "lat": 37.5665, "lng": 126.9780, "menu": "대표메뉴", "price": "1인 3만원대", "reason": "추천 이유" }
  ]
}
''';

String _searchUser(SearchRequest req) {
  final b = StringBuffer();
  b.writeln('위치: ${req.location}');
  b.writeln('1인 예산: ${_won(req.minBudget)} ~ ${_won(req.maxBudget)}');
  b.writeln(req.moods.isEmpty ? '분위기: 상관없음' : '분위기: ${req.moods.join(", ")}');
  b.writeln(req.cuisines.isEmpty
      ? '음식 종류: 상관없음'
      : '음식 종류: ${req.cuisines.join(", ")}');
  if (req.extraPrompt.trim().isNotEmpty) {
    b.writeln('추가 요청: ${req.extraPrompt.trim()}');
  }
  b.writeln('\n위 조건에 맞는 식당 ${req.count}곳을 JSON 으로 추천해줘.');
  return b.toString();
}

String _menuSystem(int count) => '''
너는 "오늘 뭐 먹지?"를 고민하는 사용자에게 메뉴(요리)를 추천하는 도우미다.
사용자 기분/상황에 맞는 메뉴 $count가지를 추천한다.

규칙:
- 특정 식당이 아니라 "요리/메뉴" 자체를 추천한다 (예: 마라탕, 냉면, 삼겹살).
- 다양하게 겹치지 않게 추천한다.
- 반드시 아래 JSON 스키마만 출력한다. 설명/마크다운/코드블록 없이 순수 JSON 만.

JSON 스키마:
{
  "menus": [
    { "name": "요리명", "category": "분류(한식/중식/일식/양식 등)", "taste": "맛 특징", "reason": "추천 이유" }
  ]
}
''';

String _menuUser(MenuRequest req) {
  final b = StringBuffer();
  b.writeln(req.situations.isEmpty
      ? '상황: 아무거나'
      : '상황: ${req.situations.join(", ")}');
  b.writeln(
      req.tastes.isEmpty ? '당기는 맛: 상관없음' : '당기는 맛: ${req.tastes.join(", ")}');
  if (req.extraPrompt.trim().isNotEmpty) {
    b.writeln('추가 요청: ${req.extraPrompt.trim()}');
  }
  b.writeln('\n위 기분에 맞는 메뉴 ${req.count}가지를 JSON 으로 추천해줘.');
  return b.toString();
}

String _won(int v) => v >= 10000
    ? '${(v / 10000).toStringAsFixed(v % 10000 == 0 ? 0 : 1)}만원'
    : '$v원';

/// 모델 응답에서 JSON 오브젝트만 추출 (코드펜스/잡텍스트 방어).
Map<String, dynamic> _extractJson(String content) {
  var text = content.trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    if (text.endsWith('```')) text = text.substring(0, text.length - 3);
    text = text.trim();
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    text = text.substring(start, end + 1);
  }
  return jsonDecode(text) as Map<String, dynamic>;
}

/// 모든 공급자의 공통 인터페이스.
/// 각 구현은 [complete] 만 채우면 [search]/[suggestMenus] 는 공용 로직을 탄다.
abstract class LlmClient {
  const LlmClient();

  /// system/user 프롬프트를 보내 순수 텍스트 응답을 받는다.
  Future<String> complete(String system, String user);
  void dispose();

  Future<RestaurantResult> search(SearchRequest req) async {
    final content = await complete(_searchSystem(req.count), _searchUser(req));
    try {
      return RestaurantResult.fromJson(_extractJson(content));
    } catch (e) {
      throw LlmException('AI 결과를 해석하지 못했어요. 다시 시도해주세요.\n($e)');
    }
  }

  Future<MenuResult> suggestMenus(MenuRequest req) async {
    final content = await complete(_menuSystem(req.count), _menuUser(req));
    try {
      return MenuResult.fromJson(_extractJson(content));
    } catch (e) {
      throw LlmException('AI 결과를 해석하지 못했어요. 다시 시도해주세요.\n($e)');
    }
  }

  factory LlmClient.fromSettings(AiSettings s, {http.Client? httpClient}) {
    switch (s.provider) {
      case AiProvider.openai:
      case AiProvider.custom:
        return OpenAiCompatibleClient(settings: s, client: httpClient);
      case AiProvider.gemini:
        return GeminiClient(settings: s, client: httpClient);
    }
  }
}

/// OpenAI 및 OpenAI 호환(vLLM, LM Studio 등) 공용 클라이언트.
class OpenAiCompatibleClient extends LlmClient {
  OpenAiCompatibleClient({required this.settings, http.Client? client})
      : _client = client ?? http.Client();

  final AiSettings settings;
  final http.Client _client;

  @override
  Future<String> complete(String system, String user) async {
    final base = settings.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');

    final body = jsonEncode({
      'model': settings.model,
      'temperature': 0.8,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    });

    final http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${settings.apiKey}',
              },
              body: body)
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw LlmException('네트워크 오류가 발생했어요. 엔드포인트/연결을 확인해주세요.\n($e)');
    }

    final resBody = utf8.decode(res.bodyBytes);
    debugPrint('[OpenAI-compat] ${res.statusCode} :: $resBody');
    if (res.statusCode != 200) {
      throw LlmException('AI 응답 오류 (${res.statusCode}).\n$resBody');
    }
    try {
      return jsonDecode(resBody)['choices'][0]['message']['content'] as String;
    } catch (e) {
      throw LlmException('AI 응답 형식이 올바르지 않아요.\n($e)');
    }
  }

  @override
  void dispose() => _client.close();
}

/// Google Gemini (generateContent) 클라이언트.
class GeminiClient extends LlmClient {
  GeminiClient({required this.settings, http.Client? client})
      : _client = client ?? http.Client();

  final AiSettings settings;
  final http.Client _client;

  @override
  Future<String> complete(String system, String user) async {
    final base = settings.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
        '$base/models/${settings.model}:generateContent?key=${settings.apiKey}');

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': user}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.8,
        'responseMimeType': 'application/json',
      },
    });

    final http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw LlmException('네트워크 오류가 발생했어요. 연결을 확인해주세요.\n($e)');
    }

    final resBody = utf8.decode(res.bodyBytes);
    debugPrint('[Gemini] ${res.statusCode} :: $resBody');
    if (res.statusCode != 200) {
      throw LlmException('AI 응답 오류 (${res.statusCode}).\n$resBody');
    }
    try {
      return jsonDecode(resBody)['candidates'][0]['content']['parts'][0]['text']
          as String;
    } catch (e) {
      throw LlmException('AI 응답 형식이 올바르지 않아요.\n($e)');
    }
  }

  @override
  void dispose() => _client.close();
}
