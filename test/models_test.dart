import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/features/absen/attendance_models.dart';

void main() {
  test('status absen dari API terbaca', () {
    final s = AttendanceStatusDto.fromJson({
      'server_time': '2026-11-25T07:50:00+07:00',
      'work_date': '2026-11-25',
      'session': {'open': true, 'clock_in_at': '2026-11-25T07:50:00+07:00', 'expires_at': '2026-11-26T07:40:00+07:00'},
      'next_action': 'out',
      'attendance': null,
      'schedule': {
        'is_day_off': false,
        'shift': {'name': 'Reguler', 'start': '08:00', 'end': '17:00'},
      },
      'mode': 'office',
      'mode_label': 'Kantor',
      'location': {'name': 'Kantor Pusat', 'enabled': true, 'latitude': -6.2, 'longitude': 106.8, 'radius_m': 100, 'strict': false, 'has_wifi': false},
      'settings': {'session_max_minutes': 1430, 'blink_timeout_seconds': 10},
    });
    expect(s.sessionOpen, isTrue);
    expect(s.nextAction, 'out');
    expect(s.shiftLabel, 'Reguler · 08:00 – 17:00');
    expect(s.location!.hasGeofence, isTrue);
    expect(s.isRemote, isFalse);
  });
}
