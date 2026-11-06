import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_app/services/clash_parser.dart';
import 'package:vpn_app/services/config_generator.dart';
import 'package:vpn_app/services/shadowrocket_parser.dart';

void main() {
  test('Clash YAML 解析 VLESS Reality 节点', () {
    const yaml = '''
proxies:
  - {name: HK-01, type: vless, server: hk.example.com, port: 443, uuid: 12345678-abcd-1234-abcd-1234567890ab, flow: xtls-rprx-vision, client-fingerprint: chrome, servername: hk.example.com, reality-opts: {public-key: pubkey123, short-id: abcd}}
''';
    final nodes = ClashParser.parseNodes(yaml);
    expect(nodes, hasLength(1));
    expect(nodes.first.name, 'HK-01');
    expect(nodes.first.publicKey, 'pubkey123');
    expect(nodes.first.transport, 'tcp');
  });

  test('Clash YAML 解析 VLESS WebSocket 节点（flow: null 不再污染配置）', () {
    const yaml = '''
proxies:
  - { name: JP-CDN, type: vless, server: cdn.example.com, port: 443, uuid: u-1, flow: null, tls: true, client-fingerprint: chrome, servername: sni.example.com, network: ws, ws-opts: { path: /3021/index, headers: { Host: host.example.com } } }
'''; 
    final nodes = ClashParser.parseNodes(yaml);
    expect(nodes, hasLength(1));
    final n = nodes.first;
    expect(n.transport, 'ws');
    expect(n.wsPath, '/3021/index');
    expect(n.wsHost, 'host.example.com');
    expect(n.flow, isEmpty);
    final config = ConfigGenerator.makeConfig(n);
    expect(config, contains('"type": "ws"'));
    expect(config, isNot(contains('"flow": "null"')));
    expect(config, isNot(contains('"reality"')));
  });

  test('小火箭 base64 订阅解析', () {
    final uri = 'vless://uuid@1.2.3.4:443?type=ws&security=tls&host=cdn.com&path=%2Fws&sni=cdn.com#NodeA';
    final nodes = ShadowrocketParser.parseNodes(uri);
    expect(nodes, hasLength(1));
    expect(nodes.first.name, 'NodeA');
    expect(nodes.first.transport, 'ws');
    expect(nodes.first.wsPath, '/ws');
  });

  test('配置生成包含分流规则', () {
    final node = ShadowrocketParser.parseNodes(
      'vless://u@1.2.3.4:443?security=reality&pbk=K&sid=s#N',
    ).first;
    final config = ConfigGenerator.makeConfig(node);
    expect(config, contains('"type": "vless"'));
    expect(config, contains('geosite-cn'));
    expect(config, contains('geoip-cn'));
    expect(config, contains('"reality"'));
  });
}
