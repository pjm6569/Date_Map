import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/restaurant.dart';

/// 네이버 지역검색 API 로 실제 존재하는 가게를 조회한다.
/// (네이버 개발자센터 Client ID/Secret 필요 — 지도 SDK 키와 별개)
class NaverSearchService {
  NaverSearchService({
    required this.clientId,
    required this.clientSecret,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String clientId;
  final String clientSecret;
  final http.Client _client;

  static const _endpoint =
      'https://openapi.naver.com/v1/search/local.json';

  /// 검색어 하나로 지역검색. [display] 만큼 요청(최대 100).
  Future<List<Restaurant>> searchOne(String query, {int display = 20}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'query': query,
      'display': display.toString(),
      'sort': 'comment', // 리뷰 많은 순(인기 우선)
    });

    final http.Response res;
    try {
      res = await _client.get(uri, headers: {
        'X-Naver-Client-Id': clientId,
        'X-Naver-Client-Secret': clientSecret,
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[NaverSearch] "$query" 네트워크 오류: $e');
      return [];
    }

    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) {
      debugPrint('[NaverSearch] "$query" ${res.statusCode}: $body');
      return [];
    }

    try {
      final items = (jsonDecode(body)['items'] as List?) ?? [];
      debugPrint('[NaverSearch] "$query" → ${items.length}곳');
      return items
          .whereType<Map>()
          .map((e) => _fromNaverItem(Map<String, dynamic>.from(e)))
          .whereType<Restaurant>()
          .toList();
    } catch (e) {
      debugPrint('[NaverSearch] "$query" 파싱 오류: $e');
      return [];
    }
  }

  /// 여러 검색어를 조회해 중복(같은 상호+좌표) 제거 후 합친다.
  Future<List<Restaurant>> searchMany(List<String> queries,
      {int displayEach = 20}) async {
    final results = <Restaurant>[];
    final seen = <String>{};
    // 순차 호출(네이버 rate limit 보호). 검색어 수가 많지 않으므로 충분.
    for (final q in queries) {
      final list = await searchOne(q, display: displayEach);
      for (final r in list) {
        final key = '${r.name}@${r.lat.toStringAsFixed(4)},'
            '${r.lng.toStringAsFixed(4)}';
        if (seen.add(key)) results.add(r);
      }
    }
    debugPrint('[NaverSearch] 후보 합계 ${results.length}곳 '
        '(검색어 ${queries.length}개)');
    return results;
  }

  void dispose() => _client.close();
}

/// 네이버 지역검색 item → Restaurant.
/// - title 에 <b> 태그가 섞여오므로 제거.
/// - mapx/mapy 는 KATECH(구) 또는 WGS84*1e7 정수. 최신 API 는 WGS84*1e7.
Restaurant? _fromNaverItem(Map<String, dynamic> item) {
  final rawTitle = (item['title'] ?? '').toString();
  final name = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  if (name.isEmpty) return null;

  final category = (item['category'] ?? '').toString();
  final address =
      (item['roadAddress'] ?? item['address'] ?? '').toString();

  // mapx=경도, mapy=위도 (문자열 정수, WGS84 * 1e7).
  final mapx = double.tryParse((item['mapx'] ?? '').toString()) ?? 0;
  final mapy = double.tryParse((item['mapy'] ?? '').toString()) ?? 0;
  // 1e7 스케일이면 나눠서 실좌표로.
  final lng = mapx > 1000000 ? mapx / 1e7 : mapx;
  final lat = mapy > 1000000 ? mapy / 1e7 : mapy;

  return Restaurant(
    name: name,
    lat: lat,
    lng: lng,
    menu: category, // 네이버 분류(예: "한식>냉면")를 메뉴 자리에 임시로
    price: '',
    reason: address, // 주소를 이유 자리에 임시 보관(AI 선별 단계에서 교체)
  );
}
