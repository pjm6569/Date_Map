// OpenAI/Gemini 가 반환하는 "식당 여러 곳" JSON 을 파싱하는 모델.
//
// 기대 스키마:
// {
//   "restaurants": [
//     { "name": "식당명", "lat": 37.5665, "lng": 126.9780,
//       "menu": "대표메뉴", "price": "1인 3만원대", "reason": "추천 이유" },
//     ...
//   ]
// }

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0.0;
  return 0.0;
}

String _toStr(dynamic v) => v?.toString().trim() ?? '';

/// 추천 식당 한 곳.
class Restaurant {
  final String name;
  final double lat;
  final double lng;
  final String menu;
  final String price;
  final String reason;

  const Restaurant({
    required this.name,
    required this.lat,
    required this.lng,
    required this.menu,
    required this.price,
    required this.reason,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        name: _toStr(json['name']),
        lat: _toDouble(json['lat']),
        lng: _toDouble(json['lng']),
        menu: _toStr(json['menu']),
        price: _toStr(json['price']),
        reason: _toStr(json['reason']),
      );

  bool get hasCoord => lat != 0.0 && lng != 0.0;

  /// 네이버 지도 검색 딥링크.
  Uri get naverMapUri =>
      Uri.parse('https://map.naver.com/v5/search/${Uri.encodeComponent(name)}');
}

/// 추천 결과(식당 목록).
class RestaurantResult {
  final List<Restaurant> restaurants;

  const RestaurantResult(this.restaurants);

  factory RestaurantResult.fromJson(Map<String, dynamic> json) {
    final list = json['restaurants'];
    if (list is! List || list.isEmpty) {
      throw const FormatException('JSON 에 restaurants 배열이 없습니다.');
    }
    return RestaurantResult(
      list
          .whereType<Map>()
          .map((e) => Restaurant.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
