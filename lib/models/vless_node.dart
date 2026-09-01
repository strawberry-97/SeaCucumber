import 'package:flutter/foundation.dart';

/// VLESS 节点模型（与 clash-verg 的 VlessNode 保持一致）
@immutable
class VlessNode {
  final String name;
  final String server;
  final int port;
  final String uuid;
  final String flow;
  final String fingerprint;
  final String servername;
  final String publicKey;
  final String shortId;

  /// 传输方式：`tcp`（Reality）或 `ws`（WebSocket + TLS）
  final String transport;

  /// WebSocket Host 头（ws 传输时使用）
  final String wsHost;

  /// WebSocket 路径（ws 传输时使用）
  final String wsPath;

  const VlessNode({
    required this.name,
    required this.server,
    required this.port,
    required this.uuid,
    this.flow = 'xtls-rprx-vision',
    this.fingerprint = 'chrome',
    this.servername = '',
    this.publicKey = '',
    this.shortId = '',
    this.transport = 'tcp',
    this.wsHost = '',
    this.wsPath = '',
  });

  String get id => name;

  bool get isWebSocket => transport == 'ws';
  bool get isReality => transport == 'tcp' && publicKey.isNotEmpty;

  /// 传输方式展示标签
  String get transportLabel => isWebSocket ? 'WS+TLS' : 'REALITY';

  Map<String, dynamic> toJson() => {
        'name': name,
        'server': server,
        'port': port,
        'uuid': uuid,
        'flow': flow,
        'fingerprint': fingerprint,
        'servername': servername,
        'publicKey': publicKey,
        'shortId': shortId,
        'transport': transport,
        'wsHost': wsHost,
        'wsPath': wsPath,
      };

  factory VlessNode.fromJson(Map<String, dynamic> json) => VlessNode(
        name: json['name'] as String? ?? '',
        server: json['server'] as String? ?? '',
        port: (json['port'] as num?)?.toInt() ?? 443,
        uuid: json['uuid'] as String? ?? '',
        flow: json['flow'] as String? ?? 'xtls-rprx-vision',
        fingerprint: json['fingerprint'] as String? ?? 'chrome',
        servername: json['servername'] as String? ?? '',
        publicKey: json['publicKey'] as String? ?? '',
        shortId: json['shortId'] as String? ?? '',
        transport: json['transport'] as String? ?? 'tcp',
        wsHost: json['wsHost'] as String? ?? '',
        wsPath: json['wsPath'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is VlessNode && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'VlessNode($name, $server:$port)';
}
