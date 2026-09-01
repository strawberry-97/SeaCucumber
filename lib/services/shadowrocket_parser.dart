import 'dart:convert';

import '../models/vless_node.dart';
import 'clash_parser.dart';

/// 小火箭（Shadowrocket）订阅解析器
///
/// 整体 base64 编码，逐行 `vless://uuid@server:port?query#名称`，
/// 支持 Reality（type=tcp & security=reality）与 WebSocket + TLS（type=ws & security=tls）。
///
/// 移植自 clash-verg 的 ShadowrocketParser.swift
class ShadowrocketParser {
  static List<VlessNode> parseNodes(String raw) {
    var body = raw;

    // 若整份内容是 base64（不含 ://），先解码
    if (!body.contains('://')) {
      final trimmed = body.trim();
      try {
        final decoded = utf8.decode(base64.decode(trimmed));
        body = decoded;
      } catch (_) {
        // 不是合法 base64，按原样处理
      }
    }

    final nodes = <VlessNode>[];
    for (final line in body.split('\n')) {
      final t = line.trim();
      if (!t.startsWith('vless://')) continue;
      final node = _parseVlessUri(t);
      if (node != null) nodes.add(node);
    }
    return nodes;
  }

  /// 解析单条 vless:// URI
  static VlessNode? _parseVlessUri(String uri) {
    // 1) 分离名称（# 之后，可能百分号编码）
    var name = '';
    var rest = uri;
    final hashIdx = uri.indexOf('#');
    if (hashIdx != -1) {
      final encoded = uri.substring(hashIdx + 1);
      name = _percentDecode(encoded) ?? encoded;
      rest = uri.substring(0, hashIdx);
    }

    if (!rest.startsWith('vless://')) return null;
    var body = rest.substring('vless://'.length);

    // 2) 分离 query（? 之后）
    var query = '';
    final qIdx = body.indexOf('?');
    if (qIdx != -1) {
      query = body.substring(qIdx + 1);
      body = body.substring(0, qIdx);
    }

    // 3) uuid@server:port
    final atIdx = body.indexOf('@');
    if (atIdx == -1) return null;
    final uuid = body.substring(0, atIdx);
    final address = body.substring(atIdx + 1);
    final split = _splitAddress(address);
    final server = split.$1;
    final portStr = split.$2;
    final port = int.tryParse(portStr);
    if (server.isEmpty || port == null) return null;

    // 4) query 参数（值已百分号解码）
    final params = _parseQuery(query);
    if (ClashParser.isPlaceholder(name)) return null;

    final security = params['security'] ?? '';
    final type = params['type'] ?? 'tcp';
    final fp = params['fp'] ?? 'ios';
    final sni = params['sni'] ?? '';
    final flow = params['flow'] ?? '';

    var transport = 'tcp';
    var publicKey = '';
    var shortId = '';
    var wsHost = '';
    var wsPath = '';

    if (type == 'ws') {
      transport = 'ws';
      wsHost = params['host'] ?? '';
      wsPath = params['path'] ?? '';
    }
    if (security == 'reality') {
      transport = 'tcp';
      publicKey = params['pbk'] ?? '';
      shortId = params['sid'] ?? '';
    }

    return VlessNode(
      name: name.isEmpty ? '$server:$port' : name,
      server: server,
      port: port,
      uuid: uuid,
      flow: flow.isEmpty ? 'xtls-rprx-vision' : flow,
      fingerprint: fp,
      servername: sni.isEmpty ? server : sni,
      publicKey: publicKey,
      shortId: shortId,
      transport: transport,
      wsHost: wsHost,
      wsPath: wsPath,
    );
  }

  /// 拆分 server:port，兼容 IPv6 `[::1]:443`
  static (String, String) _splitAddress(String s) {
    if (s.startsWith('[')) {
      final close = s.indexOf(']');
      if (close == -1) return (s, '');
      final ip = s.substring(1, close);
      final rest = s.substring(close + 1);
      final port = rest.startsWith(':') ? rest.substring(1) : '';
      return (ip, port);
    }
    final colon = s.lastIndexOf(':');
    if (colon == -1) return (s, '');
    return (s.substring(0, colon), s.substring(colon + 1));
  }

  /// 解析 URL query，键值均做百分号解码
  static Map<String, String> _parseQuery(String q) {
    final result = <String, String>{};
    if (q.isEmpty) return result;
    for (final pair in q.split('&')) {
      final eq = pair.indexOf('=');
      if (eq == -1) {
        final key = _percentDecode(pair);
        if (key != null && key.isNotEmpty) result[key] = '';
        continue;
      }
      final key = _percentDecode(pair.substring(0, eq));
      final rawVal = pair.substring(eq + 1);
      final val = _percentDecode(rawVal) ?? rawVal;
      if (key != null && key.isNotEmpty) result[key] = val;
    }
    return result;
  }

  static String? _percentDecode(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return null;
    }
  }
}
