import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// 配置文件 / 规则集 / 日志 / 诊断 的文件管理
///
/// 移植自 clash-verg 的 SharedConstants（App Group 部分）
class FileService {
  static const String configFileName = 'config.json';
  static const String logFileName = 'tunnel.log';
  static const String localSubFileName = 'subscription_local.txt';
  static const List<String> ruleSetFiles = [
    'geoip-cn.srs',
    'geosite-cn.srs',
  ];

  static Directory? _workingDir;

  /// 工作目录（存放规则集与 config.json）
  static Future<Directory> workingDir() async {
    if (_workingDir != null) return _workingDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/working');
    await dir.create(recursive: true);
    _workingDir = dir;
    return dir;
  }

  /// 写入 sing-box 配置；返回是否成功
  static Future<bool> writeConfig(String json) async {
    try {
      final dir = await workingDir();
      final f = File('${dir.path}/$configFileName');
      await f.writeAsString(json, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> readConfig() async {
    try {
      final dir = await workingDir();
      final f = File('${dir.path}/$configFileName');
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// 把内置的 CN 分流规则集（.srs）从 assets 复制到工作目录。
  static Future<bool> ensureRuleSets() async {
    try {
      final dir = await workingDir();
      var allOK = true;
      for (final name in ruleSetFiles) {
        final dest = File('${dir.path}/$name');
        if (await dest.exists() && await dest.length() > 1000) continue;
        try {
          final data = await rootBundle.load('assets/rules/$name');
          await dest.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
        } catch (_) {
          allOK = false;
        }
      }
      return allOK;
    } catch (_) {
      return false;
    }
  }

  /// 规则集所在目录路径（原生侧 sing-box basePath 需要）
  static Future<String> rulesDirPath() async => (await workingDir()).path;

  /// 把内置规则集读成 base64（传给原生层写入隧道的 working 目录）
  static Future<Map<String, String>> loadRuleSetsAsBase64() async {
    final map = <String, String>{};
    for (final name in ruleSetFiles) {
      final data = await rootBundle.load('assets/rules/$name');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      map[name] = base64Encode(bytes);
    }
    return map;
  }

  /// 追加写日志
  static Future<void> log(String message) async {
    try {
      final dir = await workingDir();
      final f = File('${dir.path}/$logFileName');
      final stamp = DateTime.now().toIso8601String();
      await f.writeAsString('$stamp $message\n',
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// 本地订阅文件（用户无法直连订阅服务器时，可由外部写入后导入）
  static Future<File> localSubFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/$localSubFileName');
  }

  static Future<String?> readLocalSub() async {
    try {
      final f = await localSubFile();
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<String> readLog() async {
    try {
      final dir = await workingDir();
      final f = File('${dir.path}/$logFileName');
      if (!await f.exists()) return '';
      return await f.readAsString();
    } catch (_) {
      return '';
    }
  }

  static Future<void> clearLog() async {
    try {
      final dir = await workingDir();
      final f = File('${dir.path}/$logFileName');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 写一份诊断信息到应用文档目录
  static Future<String> writeDiagnostic({
    required int nodesCount,
    required String? selectedNode,
    required String subscriptionTitle,
  }) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final f = File('${docs.path}/diagnostic.txt');
      final config = await readConfig();
      final dir = await workingDir();
      var ruleSets = '';
      for (final name in ruleSetFiles) {
        final rf = File('${dir.path}/$name');
        final size = await rf.exists() ? await rf.length() : -1;
        ruleSets += '$name=${size}B; ';
      }
      final text = '''
workingDir = ${dir.path}
readConfig = ${config != null ? '${config.length} bytes' : 'nil'}
subscriptionType = $subscriptionTitle
nodesCount = $nodesCount
selectedNode = ${selectedNode ?? 'nil'}
ruleSets: $ruleSets
''';
      await f.writeAsString(text, flush: true);
      return f.path;
    } catch (_) {
      return '';
    }
  }
}
