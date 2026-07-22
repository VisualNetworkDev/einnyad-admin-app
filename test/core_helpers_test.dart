import 'package:einnyad_admin_mobile/core/update_service.dart';
import 'package:einnyad_admin_mobile/core/value_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('version comparison', () {
    test('compares semantic versions', () {
      expect(compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0'), 0);
      expect(compareVersions('2.0.0+4', '2.0.1+1'), lessThan(0));
    });
  });

  group('admin value helpers', () {
    test('normalizes 24 hour time', () {
      expect(normalizeTime12('00:05'), '12:05 AM');
      expect(normalizeTime12('13:30'), '1:30 PM');
      expect(normalizeTime12('9:15 PM'), '9:15 PM');
    });

    test('maps admin statuses to Spanish', () {
      expect(statusEs('Client arrived'), 'Clienta llegó');
      expect(statusEs('Completed'), 'Completada');
    });

    test('recognizes backend yes values', () {
      expect(yesOf('Sí'), isTrue);
      expect(yesOf('No'), isFalse);
    });
  });
}
