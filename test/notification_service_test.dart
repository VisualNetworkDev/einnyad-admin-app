import 'package:einnyad_admin_mobile/core/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appointment notification diff', () {
    final appointments = <Map<String, dynamic>>[
      {'appointmentId': 'APT-100', 'customerName': 'Ana'},
      {'appointmentId': 'APT-101', 'customerName': 'Mia'},
      {'appointmentId': '', 'customerName': 'Sin ID'},
    ];

    test('extracts only usable appointment identifiers', () {
      expect(appointmentIds(appointments), {'APT-100', 'APT-101'});
    });

    test('does not notify existing reservations on first activation', () {
      expect(unseenAppointments(appointments, null), isEmpty);
    });

    test('returns only reservations not seen before', () {
      final unseen = unseenAppointments(appointments, {'APT-100'});
      expect(unseen, hasLength(1));
      expect(unseen.single['appointmentId'], 'APT-101');
    });
  });
}
