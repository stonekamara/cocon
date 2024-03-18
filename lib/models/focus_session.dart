import 'dart:convert';

/// Une session de concentration terminée (ou interrompue).
class FocusSession {
  const FocusSession({
    required this.startedAt,
    required this.plannedMinutes,
    required this.endedAt,
    required this.completed,
  });

  final DateTime startedAt;
  final int plannedMinutes;
  final DateTime endedAt;

  /// Vrai si l'utilisateur est allé au bout de la durée prévue.
  final bool completed;

  int get actualMinutes => endedAt.difference(startedAt).inMinutes;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'startedAt': startedAt.toIso8601String(),
        'plannedMinutes': plannedMinutes,
        'endedAt': endedAt.toIso8601String(),
        'completed': completed,
      };

  factory FocusSession.fromMap(Map<String, dynamic> map) => FocusSession(
        startedAt: DateTime.parse(map['startedAt'] as String),
        plannedMinutes: map['plannedMinutes'] as int,
        endedAt: DateTime.parse(map['endedAt'] as String),
        completed: map['completed'] as bool,
      );

  String encode() => jsonEncode(toMap());

  factory FocusSession.decode(String source) =>
      FocusSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
