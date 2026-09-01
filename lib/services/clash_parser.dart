import '../models/vless_node.dart';

/// Clash Verge YAML 订阅解析器（VLESS 节点）
///
/// 移植自 clash-verg 的 ClashParser.swift
class ClashParser {
  static const List<String> _placeholderPrefixes = [
    '剩余流量',
    '距离下次重置',
    '套餐到期',
    '下次重置',
  ];

  static bool isPlaceholder(String name) =>
      _placeholderPrefixes.any((p) => name.startsWith(p));

  /// 解析 Clash YAML，提取 VLESS 节点
  static List<VlessNode> parseNodes(String yaml) {
    final nodes = <VlessNode>[];
    var inProxies = false;

    for (final rawLine in yaml.split('\n')) {
      final t = rawLine.trim();
      if (t.startsWith('proxies:')) {
        inProxies = true;
        continue;
      }
      if (!inProxies) continue;
      if (t.startsWith('proxy-groups:') ||
          t.startsWith('rules:') ||
          t.startsWith('rule-providers:')) {
        break;
      }
      if (!t.startsWith('-')) continue;

      final flowMap = _extractFlowMap(t);
      if (flowMap == null) continue;
      final map = _parseFlowMap(flowMap);

      if (map['type'] != 'vless') continue;
      final name = map['name'];
      final server = map['server'];
      final portStr = map['port'];
      final uuid = map['uuid'];
      if (name == null ||
          isPlaceholder(name) ||
          server == null ||
          portStr == null ||
          int.tryParse(portStr) == null ||
          uuid == null) {
        continue;
      }

      var publicKey = '';
      var shortId = '';
      final reality = map['reality-opts'];
      if (reality != null) {
        final r = _parseFlowMap(reality);
        publicKey = r['public-key'] ?? '';
        shortId = r['short-id'] ?? '';
      }

      nodes.add(VlessNode(
        name: name,
        server: server,
        port: int.parse(portStr),
        uuid: uuid,
        flow: map['flow'] ?? 'xtls-rprx-vision',
        fingerprint: map['client-fingerprint'] ?? 'chrome',
        servername: map['servername'] ?? '',
        publicKey: publicKey,
        shortId: shortId,
      ));
    }
    return nodes;
  }

  /// 从一行里提取最外层 `{ ... }`
  static String? _extractFlowMap(String line) {
    final start = line.indexOf('{');
    final end = line.lastIndexOf('}');
    if (start == -1 || end == -1 || start >= end) return null;
    return line.substring(start + 1, end);
  }

  /// 拆 `key: value, nested: { a: b }` 成 Map（value 去引号）
  static Map<String, String> _parseFlowMap(String rawContent) {
    var content = rawContent.trim();
    if (content.startsWith('{') && content.endsWith('}')) {
      content = content.substring(1, content.length - 1);
    }

    final result = <String, String>{};
    final pairs = <String>[];
    var current = '';
    var depth = 0;
    String? quote;

    for (final ch in content.split('')) {
      if (quote != null) {
        current += ch;
        if (ch == quote) quote = null;
        continue;
      }
      switch (ch) {
        case "'":
        case '"':
          quote = ch;
          current += ch;
        case '{':
          depth += 1;
          current += ch;
        case '}':
          depth -= 1;
          current += ch;
        case ',':
          if (depth == 0) {
            pairs.add(current);
            current = '';
          } else {
            current += ch;
          }
        default:
          current += ch;
      }
    }
    if (current.trim().isNotEmpty) pairs.add(current);

    for (final pair in pairs) {
      final p = pair.trim();
      final ci = p.indexOf(':');
      if (ci == -1) continue;
      final key = p.substring(0, ci).trim();
      var value = p.substring(ci + 1).trim();
      value = _unquote(value);
      result[key] = value;
    }
    return result;
  }

  static String _unquote(String s) {
    if (s.length >= 2) {
      final f = s[0];
      final l = s[s.length - 1];
      if ((f == "'" && l == "'") || (f == '"' && l == '"')) {
        return s.substring(1, s.length - 1);
      }
    }
    return s;
  }
}
