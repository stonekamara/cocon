import 'package:flutter_test/flutter_test.dart';

import 'package:cocon/models/focus_session.dart';

void main() {
  group('FocusSession', () {
    test('encode/decode round-trip', () {
      final start = DateTime(2026, 9, 11, 8, 30);
      final end = DateTime(2026, 9, 11, 8, 55);
      final session = FocusSession(
        startedAt: start,
        plannedMinutes: 25,
        endedAt: end,
        completed: true,
      );

      final decoded = FocusSession.decode(session.encode());

      expect(decoded.startedAt, start);
      expect(decoded.plannedMinutes, 25);
      expect(decoded.endedAt, end);
      expect(decoded.completed, isTrue);
      expect(decoded.actualMinutes, 25);
    });

    test('actualMinutes reflects a shortened session', () {
      final session = FocusSession(
        startedAt: DateTime(2026, 9, 11, 9, 0),
        plannedMinutes: 45,
        endedAt: DateTime(2026, 9, 11, 9, 20),
        completed: false,
      );
      expect(session.completed, isFalse);
      expect(session.actualMinutes, 20);
    });
  });
}
