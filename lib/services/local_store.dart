import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_session.dart';

/// Stockage local : apps bloquées, durée par défaut, historique des sessions.
class LocalStore {
  LocalStore._(this._prefs);

  static const _kBlockedApps = 'cocon.blocked_apps';
  static const _kDefaultMinutes = 'cocon.default_minutes';
  static const _kHistory = 'cocon.history';
  static const int kMaxHistoryEntries = 100;

  final SharedPreferences _prefs;

  static Future<LocalStore> load() async =>
      LocalStore._(await SharedPreferences.getInstance());

  // --- Apps bloquées -------------------------------------------------------

  List<String> getBlockedApps() => _prefs.getStringList(_kBlockedApps) ?? <String>[];

  Future<void> setBlockedApps(List<String> packages) =>
      _prefs.setStringList(_kBlockedApps, packages);

  // --- Durée par défaut ----------------------------------------------------

  int getDefaultMinutes() => _prefs.getInt(_kDefaultMinutes) ?? 25;

  Future<void> setDefaultMinutes(int minutes) =>
      _prefs.setInt(_kDefaultMinutes, minutes.clamp(1, 240));

  // --- Historique ----------------------------------------------------------

  List<FocusSession> getHistory() {
    final raw = _prefs.getStringList(_kHistory) ?? const <String>[];
    return raw
        .map((s) {
          try {
            return FocusSession.decode(s);
          } on FormatException {
            return null;
          }
        })
        .whereType<FocusSession>()
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> addSession(FocusSession session) async {
    final history = getHistory()..insert(0, session);
    if (history.length > kMaxHistoryEntries) {
      history.removeRange(kMaxHistoryEntries, history.length);
    }
    await _prefs.setStringList(
        _kHistory, history.map((s) => s.encode()).toList());
  }

  Future<void> clearHistory() => _prefs.remove(_kHistory);
}
