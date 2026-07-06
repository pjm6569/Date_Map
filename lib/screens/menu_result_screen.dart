import 'package:flutter/material.dart';

import '../models/menu.dart';
import 'input_screen.dart';

/// 메뉴 추천 결과. 각 메뉴 카드에서 "이 메뉴로 맛집 찾기"로 연결된다.
class MenuResultScreen extends StatelessWidget {
  const MenuResultScreen({super.key, required this.result});

  final MenuResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추천 메뉴')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: result.menus.length,
        itemBuilder: (context, i) => _MenuCard(index: i + 1, menu: result.menus[i]),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.index, required this.menu});

  final int index;
  final MenuSuggestion menu;

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: Colors.orange,
                  child: Text('$index',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(menu.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                if (menu.category.isNotEmpty)
                  Chip(
                    label: Text(menu.category,
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (menu.taste.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('👅 ${menu.taste}', style: const TextStyle(fontSize: 14)),
            ],
            if (menu.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(menu.reason,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InputScreen(prefillCuisine: menu.name),
                  ),
                ),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('이 메뉴로 맛집 찾기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
