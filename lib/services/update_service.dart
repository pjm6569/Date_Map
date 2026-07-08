import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// GitHub Releases 를 이용한 인앱 자동 업데이트.
///
/// 흐름: 최신 릴리스 확인 → 현재 버전과 비교 → APK 다운로드 → 설치 인텐트.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // GitHub 저장소.
  static const _owner = 'pjm6569';
  static const _repo = 'Date_Map';
  static const _latestReleaseApi =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// 최신 릴리스 정보. 업데이트 없으면 null.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final res = await _client.get(
        Uri.parse(_latestReleaseApi),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('[Update] 릴리스 조회 실패 ${res.statusCode}');
        return null;
      }

      final json = jsonDecode(utf8.decode(res.bodyBytes));
      final tag = (json['tag_name'] ?? '').toString(); // 예: v0.2.0
      final latest = _parseVersion(tag);
      if (latest == null) return null;

      final info = await PackageInfo.fromPlatform();
      final current = _parseVersion(info.version);
      if (current == null) return null;

      if (!_isNewer(latest, current)) return null; // 최신이거나 동일

      // APK 에셋 URL 찾기.
      final assets = (json['assets'] as List?) ?? [];
      final apk = assets.whereType<Map>().firstWhere(
            (a) => a['name'].toString().toLowerCase().endsWith('.apk'),
            orElse: () => {},
          );
      final apkUrl = apk['browser_download_url']?.toString();
      if (apkUrl == null) return null;

      return UpdateInfo(
        version: tag,
        apkUrl: apkUrl,
        releaseNotes: (json['body'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('[Update] 확인 오류: $e');
      return null;
    }
  }

  /// APK 다운로드 → 설치 화면 실행.
  /// [onProgress] 는 0.0~1.0. 성공 시 true.
  Future<bool> downloadAndInstall(
    UpdateInfo info, {
    void Function(double)? onProgress,
  }) async {
    // Android 8+ : 알 수 없는 앱 설치 권한 필요.
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        debugPrint('[Update] 설치 권한 거부됨');
        return false;
      }
    }

    try {
      final req = http.Request('GET', Uri.parse(info.apkUrl));
      final resp = await _client.send(req);
      if (resp.statusCode != 200) return false;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/date_map-${info.version}.apk');
      final sink = file.openWrite();
      final total = resp.contentLength ?? 0;
      var received = 0;

      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();

      final result = await OpenFilex.open(file.path);
      debugPrint('[Update] 설치 실행: ${result.type} ${result.message}');
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[Update] 다운로드/설치 오류: $e');
      return false;
    }
  }

  void dispose() => _client.close();

  // "v1.2.3" 또는 "1.2.3" → [1,2,3]
  static List<int>? _parseVersion(String raw) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(raw);
    if (m == null) return null;
    return [int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)];
  }

  static bool _isNewer(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}

class UpdateInfo {
  final String version;
  final String apkUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.releaseNotes,
  });
}
