import 'dart:convert';
import 'dart:typed_data';

import 'package:einnyad_admin_mobile/core/admin_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const endpoint = 'https://script.google.com/macros/s/test-deployment/exec';

  test('redirected 404 retries GET without duplicating login POST', () async {
    var posts = 0;
    var gets = 0;
    final api = AdminApi(
      endpoint: endpoint,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://script.googleusercontent.com/macros/echo?test=1',
            },
          );
        }
        gets++;
        expect(request.body, isEmpty);
        if (gets == 1) return http.Response('temporary', 404);
        return http.Response(
          '{"success":true,"data":{"sessionToken":"test"}}',
          200,
        );
      }),
    );
    addTearDown(api.close);
    expect(
      (await api.login('owner@example.com', 'test'))['sessionToken'],
      'test',
    );
    expect(posts, 1);
    expect(gets, 2);
  });

  test('read-only data request retries direct 404', () async {
    var calls = 0;
    final api = AdminApi(
      endpoint: endpoint,
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('', 404)
            : http.Response('{"success":true,"data":{}}', 200);
      }),
    );
    addTearDown(api.close);
    await api.call('getAdminData');
    expect(calls, 2);
  });

  test(
    'write operations and login POST are never replayed after HTTP error',
    () async {
      for (final action in ['login', 'createAppointment', 'uploadImage']) {
        var calls = 0;
        final api = AdminApi(
          endpoint: endpoint,
          client: MockClient((_) async {
            calls++;
            return http.Response('', 404);
          }),
        );
        addTearDown(api.close);
        await expectLater(
          api.call(action),
          throwsA(
            isA<AdminApiException>().having((e) => e.httpStatus, 'status', 404),
          ),
        );
        expect(calls, 1);
      }
    },
  );

  test('accented Spanish session expiry is recognized', () async {
    final api = AdminApi(
      endpoint: endpoint,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Sesión inválida.'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.call('getAdminData'),
      throwsA(
        isA<AdminApiException>().having(
          (e) => e.sessionExpired,
          'sessionExpired',
          true,
        ),
      ),
    );
  });

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
