import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/subscription_type.dart';
import 'file_service.dart';

/// 订阅下载错误
class SubscriptionException implements Exception {
  final String message;
  SubscriptionException(this.message);

  @override
  String toString() => message;
}

/// 下载订阅（不同协议风格的服务器会校验不同的 User-Agent，否则可能 404）
///
/// 移植自 clash-verg 的 SubscriptionLoader.swift
class SubscriptionLoader {
  /// 下载订阅内容
  static Future<String> download({
    required Uri url,
    required SubscriptionType type,
  }) async {
    final sw = Stopwatch()..start();
    await FileService.log('sub download begin: ${url.host}:${url.port}');
    final client = http.Client();
    try {
      final req = http.Request('GET', url)
        ..headers['User-Agent'] = type.userAgent
        ..headers['Accept'] = type.acceptHeader;
      final streamed = await client
          .send(req)
          .timeout(const Duration(seconds: 30));
      await FileService.log(
          'sub download headers: status=${streamed.statusCode} '
          'after ${sw.elapsedMilliseconds}ms');
      final resp = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 30));
      await FileService.log(
          'sub download body: ${resp.bodyBytes.length} bytes '
          'after ${sw.elapsedMilliseconds}ms');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw SubscriptionException('服务器返回 HTTP ${resp.statusCode}');
      }
      if (resp.bodyBytes.isEmpty) {
        throw SubscriptionException('订阅内容为空');
      }
      // 尝试常见编码
      try {
        return utf8.decode(resp.bodyBytes);
      } catch (_) {
        return latin1.decode(resp.bodyBytes);
      }
    } on Exception catch (e) {
      await FileService.log(
          'sub download error after ${sw.elapsedMilliseconds}ms: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
