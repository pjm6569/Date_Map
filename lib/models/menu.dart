// "뭐 먹지?" — 메뉴(요리) 추천 결과 모델.
//
// 기대 스키마:
// {
//   "menus": [
//     { "name": "요리명", "category": "한식", "taste": "매콤/든든",
//       "reason": "추천 이유" }
//   ]
// }

String _toStr(dynamic v) => v?.toString().trim() ?? '';

/// 추천 메뉴 한 가지.
class MenuSuggestion {
  final String name; // 요리명 (예: 마라탕)
  final String category; // 분류 (예: 중식)
  final String taste; // 맛 특징 (예: 얼큰함)
  final String reason; // 추천 이유

  const MenuSuggestion({
    required this.name,
    required this.category,
    required this.taste,
    required this.reason,
  });

  factory MenuSuggestion.fromJson(Map<String, dynamic> json) => MenuSuggestion(
        name: _toStr(json['name']),
        category: _toStr(json['category']),
        taste: _toStr(json['taste']),
        reason: _toStr(json['reason']),
      );
}

/// 메뉴 추천 결과.
class MenuResult {
  final List<MenuSuggestion> menus;

  const MenuResult(this.menus);

  factory MenuResult.fromJson(Map<String, dynamic> json) {
    final list = json['menus'];
    if (list is! List || list.isEmpty) {
      throw const FormatException('JSON 에 menus 배열이 없습니다.');
    }
    return MenuResult(
      list
          .whereType<Map>()
          .map((e) => MenuSuggestion.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
