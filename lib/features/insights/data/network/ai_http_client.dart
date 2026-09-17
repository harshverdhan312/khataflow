import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import '../../domain/models/ai_insight_exception.dart';

/// Pure response data object returned from [AiHttpClient].
class AiHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const AiHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}

/// Provider-independent network transport abstraction for AI communications.
abstract class AiHttpClient {
  /// Sends an HTTP POST request to [url] with [headers] and [body], timing out after [timeout].
  Future<AiHttpResponse> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 15),
  });
}

/// Platform network implementation using internal sockets while encapsulating all platform
/// details and mapping socket/transport exceptions into domain-safe [AIInsightException]s.
class PlatformAiHttpClient implements AiHttpClient {
  const PlatformAiHttpClient();

  @override
  Future<AiHttpResponse> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    io.HttpClient? client;
    try {
      client = io.HttpClient();
      client.connectionTimeout = timeout;

      final request = await client.postUrl(url).timeout(
        timeout,
        onTimeout: () => throw const AITimeoutException(),
      );

      // Apply headers
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      // Write UTF-8 encoded payload
      final encodedBody = utf8.encode(body);
      request.headers.contentLength = encodedBody.length;
      request.add(encodedBody);

      final response = await request.close().timeout(
        timeout,
        onTimeout: () => throw const AITimeoutException(),
      );

      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(
            timeout,
            onTimeout: () => throw const AITimeoutException(),
          );

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          responseHeaders[name] = values.join(', ');
        }
      });

      return AiHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
        headers: responseHeaders,
      );
    } on AITimeoutException {
      rethrow;
    } on TimeoutException {
      throw const AITimeoutException();
    } on io.SocketException catch (e) {
      throw AINetworkException('Network transport failure: ${e.message}');
    } on io.HttpException catch (e) {
      throw AINetworkException('HTTP protocol error: ${e.message}');
    } on io.HandshakeException catch (e) {
      throw AINetworkException('SSL/TLS handshake failure: ${e.message}');
    } catch (e) {
      if (e is AIInsightException) rethrow;
      throw AINetworkException('Failed to communicate with AI provider: $e');
    } finally {
      client?.close(force: true);
    }
  }
}
