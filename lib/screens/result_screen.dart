import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/restaurant.dart';

/// 화면 3: 상단 지도(식당 마커 여러 개) + 하단 식당 리스트 바텀시트.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final RestaurantResult result;

  @override
  Widget build(BuildContext context) {
    final withCoord = result.restaurants.where((r) => r.hasCoord).toList();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _ResultMap(restaurants: withCoord)),

          // 뒤로가기(다시 찾기)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '뒤로',
                  ),
                ),
              ),
            ),
          ),

          // 하단 식당 리스트
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: result.restaurants.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('추천 맛집 ${result.restaurants.length}곳',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                    final r = result.restaurants[i - 1];
                    return _RestaurantCard(index: i, restaurant: r);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResultMap extends StatelessWidget {
  const _ResultMap({required this.restaurants});

  final List<Restaurant> restaurants;

  @override
  Widget build(BuildContext context) {
    // 좌표가 하나도 없으면 지도 대신 안내.
    if (restaurants.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 80),
        child: const Text('지도에 표시할 좌표가 없어요.\n아래 목록을 확인해주세요.',
            textAlign: TextAlign.center),
      );
    }

    final first = restaurants.first;
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(first.lat, first.lng),
          zoom: 14,
        ),
      ),
      onMapReady: (controller) {
        for (var i = 0; i < restaurants.length; i++) {
          final r = restaurants[i];
          controller.addOverlay(
            NMarker(
              id: 'r$i',
              position: NLatLng(r.lat, r.lng),
              caption: NOverlayCaption(text: '${i + 1}. ${r.name}'),
            ),
          );
        }
        if (restaurants.length >= 2) {
          final bounds = NLatLngBounds.from(
            [for (final r in restaurants) NLatLng(r.lat, r.lng)],
          );
          controller.updateCamera(
            NCameraUpdate.fitBounds(bounds,
                padding: const EdgeInsets.all(48)),
          );
        }
      },
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.index, required this.restaurant});

  final int index; // 1-based
  final Restaurant restaurant;

  Future<void> _openNaverMap(BuildContext context) async {
    final ok = await launchUrl(restaurant.naverMapUri,
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네이버 지도를 열 수 없어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.redAccent,
                  child: Text('$index',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                if (r.price.isNotEmpty)
                  Text(r.price,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            if (r.menu.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('🍽 ${r.menu}',
                  style: const TextStyle(fontSize: 14)),
            ],
            if (r.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.reason,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openNaverMap(context),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('네이버 지도로 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
