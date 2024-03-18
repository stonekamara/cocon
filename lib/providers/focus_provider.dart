import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/focus_session.dart';
import '../services/local_store.dart';
import '../services/native_bridge.dart';

/// États possibles d'une session de concentration.
enum FocusPhase { idle, running, paused }

/// Contrôleur central de l'application.
class FocusProvider extends ChangeNotifier {
  FocusProvider(this._store) {
    blockedApps = _store.getBlockedApps();
    defaultMinutes = _store.getDefaultMinutes();
    history = _store.getHistory();
  }

  final LocalStore _store;

  // --- État session --------------------------------------------------------
  FocusPhase phase = FocusPhase.idle;
  int plannedMinutes = 25;
  int _secondsLeft = 25 * 60;
  Timer? _ticker;

  int get secondsLeft => _secondsLeft;

  double get progress {
    final total = plannedMinutes * 60;
    if (total == 0) return 0;
    return 1 - _secondsLeft / total;
  }

  /// Durées proposées sur l'écran d'accueil.
  static const List<int> presetDurations = <int>[15, 25, 45, 60, 90];

  // --- Données persistées --------------------------------------------------
  List<String> blockedApps = <String>[];
  int defaultMinutes = 25;
  List<FocusSession> history = <FocusSession>[];

  bool get hasBlockedApps => blockedApps.isNotEmpty;

  // --- Contrôle de session -------------------------------------------------

  /// Restaure une session active depuis l'état natif (au démarrage de l'app
  /// ou au retour au premier plan). Retourne vrai si une session existait.
  Future<bool> restoreFromNative() async {
    final active = await NativeBridge.getActiveSession();
    if (active == null) return false;
    final remaining = (active['remainingSeconds'] as num?)?.toInt() ?? 0;
    final planned = (active['plannedMinutes'] as num?)?.toInt() ?? 0;
    if (remaining <= 0) return false;
    plannedMinutes = planned > 0 ? planned : defaultMinutes;
    _secondsLeft = remaining;
    if (phase == FocusPhase.idle) {
      phase = FocusPhase.running;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    notifyListeners();
    return true;
  }

  /// Démarre une session. Refusé si une session (même native, app relancée)
  /// est déjà en cours. Retourne vrai si la session a bien démarré.
  Future<bool> startSession(int minutes) async {
    if (phase != FocusPhase.idle) return false;
    // Garde-fou anti-double session : l'état natif fait foi.
    if (await NativeBridge.getActiveSession() != null) {
      await restoreFromNative();
      return false;
    }
    plannedMinutes = minutes;
    _secondsLeft = minutes * 60;
    phase = FocusPhase.running;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    await NativeBridge.scheduleSessionEnd(minutes, blockedApps);
    // Le PIN est généré côté natif : on le récupère pour l'afficher.
    await restoreFromNative();
    return true;
  }

  void pauseSession() {
    if (phase != FocusPhase.running) return;
    _ticker?.cancel();
    phase = FocusPhase.paused;
    notifyListeners();
  }

  void resumeSession() {
    if (phase != FocusPhase.paused) return;
    phase = FocusPhase.running;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  Future<void> stopSession({required bool completed}) async {
    if (phase == FocusPhase.idle) return;
    _ticker?.cancel();
    _ticker = null;
    await _recordSession(completed: completed);
    phase = FocusPhase.idle;
    _secondsLeft = defaultMinutes * 60;
    await NativeBridge.cancelSessionEnd();
    notifyListeners();
  }

  void _tick() {
    if (_secondsLeft > 0) _secondsLeft--;
    if (_secondsLeft == 0) {
      _ticker?.cancel();
      _ticker = null;
      _finishSession();
    }
    notifyListeners();
  }

  Future<void> _finishSession() async {
    await _recordSession(completed: true);
    phase = FocusPhase.idle;
    _secondsLeft = defaultMinutes * 60;
    // Nettoyage natif (l'alarme a déjà purgé l'état, ceci est redondant
    // volontairement pour couvrir le cas app au premier plan).
    await NativeBridge.cancelSessionEnd();
    notifyListeners();
  }

  Future<void> _recordSession({required bool completed}) async {
    final session = FocusSession(
      startedAt: DateTime.now().subtract(Duration(minutes: plannedMinutes)),
      plannedMinutes: plannedMinutes,
      endedAt: DateTime.now(),
      completed: completed,
    );
    await _store.addSession(session);
    history = _store.getHistory();
  }

  // --- Préférences ---------------------------------------------------------

  Future<void> toggleApp(String package) async {
    final next = List<String>.of(blockedApps);
    next.contains(package) ? next.remove(package) : next.add(package);
    blockedApps = next;
    await _store.setBlockedApps(next);
    notifyListeners();
  }

  Future<void> setDefaultMinutes(int minutes) async {
    defaultMinutes = minutes;
    await _store.setDefaultMinutes(minutes);
    if (phase == FocusPhase.idle) {
      _secondsLeft = minutes * 60;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
