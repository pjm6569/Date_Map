import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/restaurant.dart';
import 'place_webview_screen.dart';

/// 결과 화면: 상단 앱 내 지도(식당 마커) + 하단 식당 리스트.
/// 카드를 누르면 외부로 나가지 않고 앱 내 지도에서 해당 식당으로 이동+정보창 표시.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});

  final RestaurantResult result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  NaverMapController? _mapController;
  final _sheetController = DraggableScrollableController();

  // 식당 인덱스 → 마커 (카드 탭 시 정보창 열기용)
  final Map<int, NMarker> _markers = {};
  // 좌표가 있는 식당만 마커로 표시.
  late final List<Restaurant> _withCoord =
      widget.result.restaurants.where((r) => r.hasCoord).toList();

  int _selected = -1;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// 앱 내 지도에서 해당 식당으로 카메라 이동 + 정보창 표시.
  Future<void> _focusOnMap(int index) async {
    final c = _mapController;
    final r = widget.result.restaurants[index];
    if (c == null || !r.hasCoord) return;
    await c.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(r.lat, r.lng),
        zoom: 16,
      )..setAnimation(duration: const Duration(milliseconds: 400)),
    );
    // 해당 마커에 정보창 열기.
    final marker = _markers[index];
    if (marker != null) {
      await marker.openInfoWindow(
        NInfoWindow.onMarker(id: 'iw$index', text: r.name),
      );
    }
  }

  /// 카드 탭: 처음 누르면 지도 이동+하이라이트,
  /// 이미 선택된 카드를 다시 누르면 상세(별점/메뉴)를 바로 연다.
  void _tapCard(int index) {
    if (_selected == index) {
      _openDetail(widget.result.restaurants[index]);
      return;
    }
    setState(() => _selected = index);
    _focusOnMap(index);
    if (_sheetController.isAttached && _sheetController.size > 0.55) {
      _sheetController.animateTo(0.4,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  /// 마커 탭용: 지도 이동 + 하이라이트만.
  void _selectCard(int index) {
    setState(() => _selected = index);
    _focusOnMap(index);
    if (_sheetController.isAttached && _sheetController.size > 0.55) {
      _sheetController.animateTo(0.4,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  /// 화면 이동 없이 하단 시트로 네이버 상세(별점/메뉴/리뷰) 표시.
  void _openDetail(Restaurant r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PlaceDetailSheet(query: r.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),

          // 뒤로가기
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

          _buildSheet(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_withCoord.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 80),
        child: const Text('지도에 표시할 좌표가 없어요.\n아래 목록을 확인해주세요.',
            textAlign: TextAlign.center),
      );
    }

    final first = _withCoord.first;
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition:
            NCameraPosition(target: NLatLng(first.lat, first.lng), zoom: 14),
      ),
      onMapReady: (controller) {
        _mapController = controller;
        _markers.clear();
        for (final r in _withCoord) {
          final idx = widget.result.restaurants.indexOf(r);
          final marker = NMarker(
            id: 'r$idx',
            position: NLatLng(r.lat, r.lng),
            caption: NOverlayCaption(text: '${idx + 1}. ${r.name}'),
          );
          _markers[idx] = marker;
          // 마커 탭 → 카드 선택 + 지도 이동
          marker.setOnTapListener((overlay) => _selectCard(idx));
          controller.addOverlay(marker);
        }
        if (_withCoord.length >= 2) {
          final bounds = NLatLngBounds.from(
              [for (final r in _withCoord) NLatLng(r.lat, r.lng)]);
          controller.updateCamera(
            NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(64)),
          );
        }
      },
    );
  }

  Widget _buildSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.5,
      minChildSize: 0.15,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.15, 0.5, 0.9],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: widget.result.restaurants.length + 1,
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
                      child: Text('추천 맛집 ${widget.result.restaurants.length}곳',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('카드를 누르면 위 지도에서 위치를 볼 수 있어요',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              final index = i - 1;
              final r = widget.result.restaurants[index];
              return _RestaurantCard(
                index: i,
                restaurant: r,
                selected: _selected == index,
                onTap: () => _tapCard(index),
                onDetail: () => _openDetail(r),
              );
            },
          ),
        );
      },
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.index, // 1-based
    required this.restaurant,
    required this.selected,
    required this.onTap,
    required this.onDetail,
  });

  final int index;
  final Restaurant restaurant;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Card(
      elevation: selected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? const BorderSide(color: Colors.redAccent, width: 1.5)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                            color: Colors.white, fontWeight: FontWeight.bold)),
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
                Text('🍽 ${r.menu}', style: const TextStyle(fontSize: 14)),
              ],
              if (r.reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.reason,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey.shade700)),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.reviews_outlined, size: 16),
                  label: const Text('별점·메뉴·리뷰 보기',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
