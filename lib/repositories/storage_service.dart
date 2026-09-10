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

  /// 安全写入 JSON 文件（支持原子覆盖）
  Future<void> writeJson(String fileName, dynamic data) async {
    try {
      final dir = await _getDirectory();
      final file = File('${dir.path}/$fileName');
      final tempFile = File('${dir.path}/$fileName.tmp');
      final content = const JsonEncoder.withIndent('  ').convert(data);

      await tempFile.writeAsString(content, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint('Error writing $fileName: $e');
    }
  }

  /// 读取 JSON 文件
  Future<dynamic> readJson(String fileName) async {
    try {
      final dir = await _getDirectory();
      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) {
        return null;
      }
      final content = await file.readAsString();
      return jsonDecode(content);
    } catch (e) {
      debugPrint('Error reading $fileName: $e');
      return null;
    }
  }
}

