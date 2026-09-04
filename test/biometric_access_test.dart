import 'package:einnyad_admin_mobile/core/biometric_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('einnyad/biometric_access');
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('each credential read requires a new native vault call', () async {
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'read');
          reads++;
          return {'email': 'owner@example.com', 'password': 'test-only'};
        });
    final access = BiometricAccess();
    expect((await access.read()).email, 'owner@example.com');
    await access.read();
    expect(reads, 2);
  });
  test('cancellation is returned without credentials', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'cancelled',
            message: 'Verificación cancelada.',
          );
        });
    await expectLater(
      BiometricAccess().read(),
      throwsA(
        isA<BiometricAccessException>().having(
          (e) => e.cancelled,
          'cancelled',
          true,
        ),
      ),
    );
  });
  test('unsupported platforms keep password login available', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final state = await BiometricAccess().status();
    expect(state.available, isFalse);
    expect(state.enabled, isFalse);
  });

  test('platform status failure does not bypass biometric gate', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
    expect((await BiometricAccess().status()).enabled, isTrue);
  });
}
