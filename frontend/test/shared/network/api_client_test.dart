import 'package:board_game_ai/shared/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient', () {
    test('configures default json options', () {
      final client = ApiClient(baseUrl: 'https://example.com');

      expect(client.dio.options.baseUrl, 'https://example.com');
      expect(client.dio.options.contentType, Headers.jsonContentType);
      expect(client.dio.options.responseType, ResponseType.json);
      expect(client.dio.options.connectTimeout, const Duration(seconds: 15));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 15));
    });

    test('sets and clears bearer token', () {
      final client = ApiClient();

      client.setBearerToken('abc');
      expect(
        client.dio.options.headers[ApiClient.authorizationHeader],
        'Bearer abc',
      );

      client.setBearerToken(null);
      expect(
        client.dio.options.headers.containsKey(ApiClient.authorizationHeader),
        isFalse,
      );
    });
  });
}
