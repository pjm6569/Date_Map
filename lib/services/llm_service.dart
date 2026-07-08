import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_settings.dart';
import '../models/menu.dart';
import '../models/restaurant.dart';
import 'naver_search_service.dart';

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

// ── 1단계: 네이버 지역검색용 검색어 생성 ──
String _querySystem(int numQueries) => '''
너는 네이버 지역검색에 넣을 "검색어"를 만드는 도우미다.
사용자 조건에 맞는 식당을 찾기 위한 네이버 검색어 $numQueries개를 만든다.

규칙:
- 각 검색어는 "지역 + 음식종류/키워드 + 맛집" 형태로 실제 네이버에서 잘 검색되게 만든다.
  (예: "성수동 파스타 맛집", "성수동 데이트 한식", "성수동 분위기 좋은 이자카야")
- 음식종류가 여러 개면 종류별로 나눠서 검색어를 만든다.
- 서로 다른 각도로 다양하게. 반드시 아래 JSON 스키마만 출력. 순수 JSON 만.

JSON 스키마:
{ "queries": ["검색어1", "검색어2"] }
''';

String _queryUser(SearchRequest req, int numQueries) {
  final b = StringBuffer();
  b.writeln('지역: ${req.location}');
  b.writeln('1인 예산: ${_won(req.minBudget)} ~ ${_won(req.maxBudget)}');
  if (req.moods.isNotEmpty) b.writeln('분위기: ${req.moods.join(", ")}');
  if (req.cuisines.isNotEmpty) b.writeln('음식 종류: ${req.cuisines.join(", ")}');
  if (req.extraPrompt.trim().isNotEmpty) {
    b.writeln('추가 요청: ${req.extraPrompt.trim()}');
  }
  b.writeln('\n위 조건으로 네이버 검색어 $numQueries개를 JSON 으로 만들어줘.');
  return b.toString();
}

// ── 2단계: 실존 후보 중 선별·정렬·추천이유 작성 ──
String _selectSystem(int count) => '''
너는 대한민국 맛집 큐레이터다. 아래 "후보 목록"은 네이버 지역검색으로 찾은 실제 존재하는 가게들이다.
이 후보들 중에서만 골라 사용자 조건에 가장 잘 맞는 식당을 정확히 $count곳 추천한다.

절대 규칙:
- 후보 목록에 없는 가게를 새로 만들어내지 마라. 반드시 후보 안에서만 고른다.
- 후보의 name(상호)과 index 는 그대로 사용한다. 좌표/주소는 시스템이 채우므로 신경쓰지 마라.
- 반드시 $count곳을 채워서 추천한다. 조건에 딱 맞는 곳이 부족하면, 조건에 가장 가까운 후보로 $count곳을 채운다.
  (후보 수가 $count곳보다 적을 때만 예외로 더 적게 반환한다.)
- 조건 부합도가 높은 순으로 정렬한다(가장 잘 맞는 곳이 맨 위).
- menu 는 그 가게의 대표 메뉴(추정 가능하면), price 는 1인 예상 가격대, reason 은 이 조건에 왜 맞는지 한 문장.
- 반드시 아래 JSON 스키마만 출력. 순수 JSON 만.

JSON 스키마:
{
  "picks": [
    { "index": 0, "menu": "대표메뉴", "price": "1인 3만원대", "reason": "추천 이유" }
  ]
}
''';

String _selectUser(SearchRequest req, List<Restaurant> candidates) {
  final b = StringBuffer();
  b.writeln('[사용자 조건]');
  b.writeln('지역: ${req.location}');
  b.writeln('1인 예산: ${_won(req.minBudget)} ~ ${_won(req.maxBudget)}');
  b.writeln(req.moods.isEmpty ? '분위기: 상관없음' : '분위기: ${req.moods.join(", ")}');
  b.writeln(req.cuisines.isEmpty
      ? '음식 종류: 상관없음'
      : '음식 종류: ${req.cuisines.join(", ")}');
  if (req.extraPrompt.trim().isNotEmpty) {
    b.writeln('추가 요청: ${req.extraPrompt.trim()}');
  }
  b.writeln('\n[후보 목록] (index: 상호 | 분류 | 주소)');
  for (var i = 0; i < candidates.length; i++) {
    final c = candidates[i];
    b.writeln('$i: ${c.name} | ${c.menu} | ${c.reason}');
  }
  b.writeln('\n위 후보 중에서 조건에 맞는 곳을 최대 ${req.count}곳 골라 JSON 으로.');
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

  /// 맛집 검색 파이프라인:
  /// 1) AI 가 네이버 검색어 생성 → 2) 네이버 지역검색으로 실존 후보 수집
  /// → 3) AI 가 후보 중 선별·정렬·이유 작성.
  /// [naverSearch] 가 없으면(키 미설정) 예외를 던진다.
  Future<RestaurantResult> search(
    SearchRequest req, {
    required NaverSearchService naverSearch,
  }) async {
    // 목표 개수에 맞춰 검색어 수 결정.
    // 선별 단계에서 딱 맞게 고를 수 있도록 후보 풀을 넉넉히 확보한다
    // (검색어당 여러 곳 수집 + 중복 제거로 실제 후보는 줄어들기 때문).
    final numQueries = (req.count / 2).ceil().clamp(4, 10);

    // 1) 검색어 생성
    List<String> queries;
    try {
      final qJson = _extractJson(
          await complete(_querySystem(numQueries), _queryUser(req, numQueries)));
      queries = ((qJson['queries'] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      queries = [];
    }
    // 폴백: AI 검색어 실패 시 기본 검색어.
    if (queries.isEmpty) {
      queries = [
        if (req.cuisines.isEmpty) '${req.location} 맛집',
        for (final c in req.cuisines) '${req.location} $c 맛집',
      ];
      if (queries.isEmpty) queries = ['${req.location} 맛집'];
    }

    // 2) 네이버 지역검색으로 실존 후보 수집 (검색어당 넉넉히 → 선별 여지 확보)
    final candidates = await naverSearch.searchMany(queries, displayEach: 30);
    if (candidates.isEmpty) {
      throw const LlmException('조건에 맞는 실제 가게를 찾지 못했어요. 지역/조건을 바꿔보세요.');
    }

    // 3) AI 가 후보 중 선별
    final Map<String, dynamic> picksJson;
    try {
      picksJson = _extractJson(await complete(
          _selectSystem(req.count), _selectUser(req, candidates)));
    } catch (e) {
      throw LlmException('AI 선별 결과를 해석하지 못했어요. 다시 시도해주세요.\n($e)');
    }

    final picks = (picksJson['picks'] as List?) ?? [];
    final result = <Restaurant>[];
    for (final p in picks.whereType<Map>()) {
      final idx = (p['index'] as num?)?.toInt();
      if (idx == null || idx < 0 || idx >= candidates.length) continue;
      final base = candidates[idx];
      result.add(Restaurant(
        name: base.name,
        lat: base.lat,
        lng: base.lng,
        menu: (p['menu'] ?? base.menu).toString(),
        price: (p['price'] ?? '').toString(),
        reason: (p['reason'] ?? '').toString(),
      ));
    }

    // AI 선별이 비면(형식 오류 등) 후보 상위 N곳이라도 반환.
    if (result.isEmpty) {
      result.addAll(candidates.take(req.count).map((c) => Restaurant(
            name: c.name,
            lat: c.lat,
            lng: c.lng,
            menu: c.menu,
            price: '',
            reason: c.reason,
          )));
    }
    return RestaurantResult(result);
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
