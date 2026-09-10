import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  Directory? _baseDir;

  Future<Directory> _getDirectory() async {
    if (_baseDir != null) return _baseDir!;
    _baseDir = await getApplicationDocumentsDirectory();
    final appSubdir = Directory('${_baseDir!.path}/ScheduleFocusData');
    if (!await appSubdir.exists()) {
      await appSubdir.create(recursive: true);
    }
    _baseDir = appSubdir;
    return _baseDir!;
  }

  /// 获取 macOS 下另一套可能的存储目录（沙盒容器 vs 本地 Documents）
  Directory? _getMacAlternativeDirectory() {
    if (!Platform.isMacOS) return null;
    try {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isEmpty) return null;

      if (home.contains('/Library/Containers/')) {
        // 当前处于沙盒环境，对端为真实主目录 Documents
        final realHome = home.substring(
          0,
          home.indexOf('/Library/Containers/'),
        );
        return Directory('$realHome/Documents/ScheduleFocusData');
      } else {
        // 当前处于非沙盒环境，对端为沙盒容器 Documents
        return Directory(
          '$home/Library/Containers/com.antigravity.schedule/Data/Documents/ScheduleFocusData',
        );
      }
    } catch (_) {
      return null;
    }
  }

  /// 安全写入 JSON 文件（支持原子覆盖与 macOS 跨目录冗余同步）
  Future<void> writeJson(String fileName, dynamic data) async {
    final content = const JsonEncoder.withIndent('  ').convert(data);

    // 1. 写入主存储目录
    try {
      final dir = await _getDirectory();
      await _safeWriteFile(File('${dir.path}/$fileName'), content);
    } catch (e) {
      debugPrint('Error writing $fileName to primary storage: $e');
    }

    // 2. macOS 双向冗余同步备份：如果对端目录存在或可访问，同步写入
    if (Platform.isMacOS) {
      try {
        final altDir = _getMacAlternativeDirectory();
        if (altDir != null) {
          if (!await altDir.exists()) {
            await altDir.create(recursive: true);
          }
          await _safeWriteFile(File('${altDir.path}/$fileName'), content);
        }
      } catch (_) {
        // 沙盒权限限制等情况下静默忽略，不影响主流程
      }
    }
  }

  Future<void> _safeWriteFile(File file, String content) async {
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(content, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  /// 读取 JSON 文件（包含跨沙盒自动挽救与示例任务覆盖检测）
  Future<dynamic> readJson(String fileName) async {
    try {
      final dir = await _getDirectory();
      final primaryFile = File('${dir.path}/$fileName');

      // 检查对端目录是否有历史真实数据
      if (Platform.isMacOS) {
        final altDir = _getMacAlternativeDirectory();
        if (altDir != null) {
          final altFile = File('${altDir.path}/$fileName');

          // 情况 1: 主目录文件不存在，但对端文件存在 -> 自动迁移过来
          if (!await primaryFile.exists() && await altFile.exists()) {
            try {
              final altContent = await altFile.readAsString();
              await _safeWriteFile(primaryFile, altContent);
              return jsonDecode(altContent);
            } catch (_) {}
          }

          // 情况 2: 若为主任务列表 tasks.json，检查主文件是否仅为默认示例任务，而对端包含用户自定义任务
          if (fileName == 'tasks.json' &&
              await primaryFile.exists() &&
              await altFile.exists()) {
            try {
              final primaryContent = await primaryFile.readAsString();
              final altContent = await altFile.readAsString();

              final primaryIsSampleOnly = _isOnlySampleTasks(primaryContent);
              final altIsSampleOnly = _isOnlySampleTasks(altContent);

              if (primaryIsSampleOnly && !altIsSampleOnly) {
                // 主目录仅为示例任务，对端有真实任务，自动以对端真实数据恢复
                await _safeWriteFile(primaryFile, altContent);
                return jsonDecode(altContent);
              }
            } catch (_) {}
          }
        }
      }

      if (!await primaryFile.exists()) {
        return null;
      }
      final content = await primaryFile.readAsString();
      return jsonDecode(content);
    } catch (e) {
      debugPrint('Error reading $fileName: $e');
      return null;
    }
  }

  /// 判断任务内容是否仅为系统初始创建的默认示例任务
  bool _isOnlySampleTasks(String jsonContent) {
    try {
      final list = jsonDecode(jsonContent);
      if (list is! List || list.isEmpty) return false;
      final titles = list
          .map((e) => (e as Map<String, dynamic>)['title'] as String? ?? '')
          .toSet();
      return titles.difference({'早晨高效专注计划', '项目架构设计与核心功能编码'}).isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 导出全部数据为 JSON 字符串（包含任务列表与专注记录）
  Future<String> exportAllDataAsJson() async {
    final tasksData = await readJson('tasks.json') ?? [];
    final focusData = await readJson('focus_sessions.json') ?? [];
    final exportMap = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasksData,
      'focus_sessions': focusData,
    };
    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  /// 从 JSON 字符串恢复/导入全部数据
  Future<bool> importDataFromJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return false;

      final tasks = decoded['tasks'];
      if (tasks is List) {
        await writeJson('tasks.json', tasks);
      }

      final sessions = decoded['focus_sessions'];
      if (sessions is List) {
        await writeJson('focus_sessions.json', sessions);
      }
      return true;
    } catch (e) {
      debugPrint('Error importing data: $e');
      return false;
    }
  }
}
