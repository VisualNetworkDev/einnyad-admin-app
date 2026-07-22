import 'dart:convert';
import 'dart:typed_data';

import 'package:einnyad_admin_mobile/core/admin_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const endpoint = 'https://script.google.com/macros/s/test-deployment/exec';

  test(
    'follows the Apps Script POST to GET redirect and decodes JSON',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests += 1;
        if (requests == 1) {
          expect(request.method, 'POST');
          final fields = Uri.splitQueryString(request.body);
          expect(fields['mobile'], '1');
          expect(fields['action'], 'login');
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://script.googleusercontent.com/macros/echo?token=test',
            },
          );
        }
        expect(request.method, 'GET');
        expect(request.url.host, 'script.googleusercontent.com');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'sessionToken': 'session-test',
              'email': 'owner@example.com',
            },
            'message': 'OK',
          }),
          200,
        );
      });
      final api = AdminApi(client: client, endpoint: endpoint);
      addTearDown(api.close);

      final result = await api.login('owner@example.com', 'test-password');

      expect(result['sessionToken'], 'session-test');
      expect(requests, 2);
    },
  );

  test('rejects redirects outside Google Apps Script', () async {
    final client = MockClient(
      (_) async => http.Response(
        '',
        302,
        headers: {'location': 'https://attacker.example/steal'},
      ),
    );
    final api = AdminApi(client: client, endpoint: endpoint);
    addTearDown(api.close);

    await expectLater(
      api.login('owner@example.com', 'test-password'),
      throwsA(
        isA<AdminApiException>().having(
          (error) => error.message,
          'message',
          contains('redirección no válida'),
        ),
      ),
    );
  });

  test('uploads images through the JSON mobile endpoint', () async {
    final client = MockClient((request) async {
      final fields = Uri.splitQueryString(request.body);
      expect(fields['mobile'], '1');
      expect(fields['action'], 'uploadImage');
      final payload = jsonDecode(fields['payload']!) as Map<String, dynamic>;
      expect(payload['sessionToken'], 'session-test');
      expect(payload['dataUrl'], startsWith('data:image/jpeg;base64,'));
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'url': 'https://example.com/photo.jpg'},
          'message': 'OK',
        }),
        200,
      );
    });
    final api = AdminApi(client: client, endpoint: endpoint)
      ..sessionToken = 'session-test';
    addTearDown(api.close);

    final result = await api.uploadImage(
      Uint8List.fromList([1, 2, 3]),
      fileName: 'photo.jpg',
      context: 'service',
    );

    expect(result['url'], 'https://example.com/photo.jpg');
  });
}
