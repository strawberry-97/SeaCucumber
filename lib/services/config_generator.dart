import 'dart:convert';
import 'dart:io' show Platform;

import '../models/vless_node.dart';

/// 由选中节点生成 sing-box JSON 配置（分流模式：国内直连、国外走代理）
///
/// 移植自 clash-verg 的 ConfigGenerator.swift
class ConfigGenerator {
  /// 生成 sing-box 配置
  static String makeConfig(VlessNode node) {
    final Map<String, dynamic> vless;
    if (node.transport == 'ws') {
      // VLESS + WebSocket + TLS
      final transport = <String, dynamic>{
        'type': 'ws',
        'path': node.wsPath.isEmpty ? '/' : node.wsPath,
      };
      if (node.wsHost.isNotEmpty) {
        transport['headers'] = {'Host': node.wsHost};
      }
      vless = {
        'type': 'vless',
        'tag': 'proxy',
        'server': node.server,
        'server_port': node.port,
        'uuid': node.uuid,
        'domain_resolver': 'local',
        'transport': transport,
        'tls': {
          'enabled': true,
          'server_name': node.servername,
          'utls': {
            'enabled': true,
            'fingerprint':
                node.fingerprint.isEmpty ? 'chrome' : node.fingerprint,
          },
        },
      };
    } else {
      // VLESS + Reality（tcp）
      vless = {
        'type': 'vless',
        'tag': 'proxy',
        'server': node.server,
        'server_port': node.port,
        'uuid': node.uuid,
        'flow': node.flow.isEmpty ? 'xtls-rprx-vision' : node.flow,
        'domain_resolver': 'local',
        'tls': {
          'enabled': true,
          'server_name': node.servername,
          'utls': {
            'enabled': true,
            'fingerprint':
                node.fingerprint.isEmpty ? 'chrome' : node.fingerprint,
          },
          'reality': {
            'enabled': true,
            'public_key': node.publicKey,
            'short_id': node.shortId,
          },
        },
      };
    }

    // 国内直连 + 国外走代理 的分流规则集
    final ruleSets = [
      {
        'tag': 'geosite-cn',
        'type': 'local',
        'format': 'binary',
        'path': 'geosite-cn.srs',
      },
      {
        'tag': 'geoip-cn',
        'type': 'local',
        'format': 'binary',
        'path': 'geoip-cn.srs',
      },
    ];

    final config = <String, dynamic>{
      'log': {'level': 'warn', 'timestamp': false},
      'dns': {
        'servers': [
          // Android 上没有系统 DNS（/etc/resolv.conf 为空），
          // “local” 会退化为 127.0.0.1:53 / ::1:53 导致 connection refused。
          // 改为国内公共 DNS 直连解析（direct 的 socket 会被 protect 绕过 tun0）。
          {'tag': 'local', 'address': '223.5.5.5', 'detour': 'direct'},
          {
            'tag': 'remote',
            'address': 'https://8.8.8.8/dns-query',
            'detour': 'proxy',
          },
        ],
        'rules': [
          {
            'rule_set': ['geosite-cn'],
            'server': 'local',
          },
          {
            'rule_set': ['geoip-cn'],
            'server': 'local',
          },
        ],
        'final': 'remote',
        'strategy': 'ipv4_only',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'mtu': 9000,
          'address': ['198.18.0.1/30'],
          'auto_route': true,
          'strict_route': true,
          // Apple 网络扩展（iOS/macOS）沙盒禁止 system 栈绑定 TUN 地址
          // （bind: operation not permitted），需使用 gvisor 用户态栈。
          'stack': _tunStack,
        },
      ],
      'outbounds': [
        vless,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': {
        'rule_set': ruleSets,
        'rules': [
          {'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
          {
            'rule_set': ['geosite-cn'],
            'outbound': 'direct',
          },
          {
            'rule_set': ['geoip-cn'],
            'outbound': 'direct',
          },
          {'ip_is_private': true, 'outbound': 'direct'},
        ],
        'auto_detect_interface': true,
        'final': 'proxy',
      },
    };

    return const JsonEncoder.withIndent('  ').convert(config);
  }

  /// Apple 平台（iOS/macOS）用 gvisor，Android/Windows 保持 system。
  static String get _tunStack =>
      (Platform.isMacOS || Platform.isIOS) ? 'gvisor' : 'system';
}
