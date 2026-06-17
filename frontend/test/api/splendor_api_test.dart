import 'package:board_game_ai/api/api_config.dart';
import 'package:board_game_ai/api/api_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('has default backend base url for local device debugging', () {
    expect(ApiConfig.defaultBaseUrl, startsWith('http://'));
    expect(ApiConfig.defaultBaseUrl, endsWith(':3000'));
  });

  test('builds splendor endpoint paths', () {
    expect(ApiPaths.splendorCatalog, '/api/splendor/catalog');
    expect(ApiPaths.splendorSession('abc'), '/api/splendor/sessions/abc');
    expect(
      ApiPaths.splendorLegalActions('abc'),
      '/api/splendor/sessions/abc/legal-actions',
    );
    expect(
      ApiPaths.splendorActions('abc'),
      '/api/splendor/sessions/abc/actions',
    );
  });
}
