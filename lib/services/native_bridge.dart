import 'package:flutter/services.dart';

/// Pont natif vers la couche Android de Cocon (AccessibilityService, alarmes,
/// notifications). Toutes les méthodes sont no-op sur les plateformes non
/// supportées pour permettre de développer l'UI sur Linux/Chrome.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('cocon/native');

  static bool _supported = true;

  /// Détecte si la plateforme supporte le blocage (Android uniquement).
  static Future<bool> get isBlockingSupported async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isBlockingSupported') ?? false;
    } on PlatformException {
      _supported = false;
      return false;
    } on MissingPluginException {
      _supported = false;
      return false;
    }
  }

  /// Retourne la liste des applications installées.
  static Future<List<Map<String, Object?>>> getInstalledApps() async {
    if (!_supported) return const [];
    try {
      final result = await _channel
          .invokeMethod<List<Object?>>('getInstalledApps');
      return (result ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map((m) => m.cast<String, Object?>())
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  /// Vrai si le service d'accessibilité Cocon est activé.
  static Future<bool> get isAccessibilityEnabled async {
    if (!_supported) return false;
    try {
      return await _channel
              .invokeMethod<bool>('isAccessibilityEnabled') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Ouvre les réglages système pour activer le service d'accessibilité.
  static Future<void> openAccessibilitySettings() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException {
      // silencieux : l'utilisateur activera manuellement
    }
  }

  /// Vrai si Cocon est administrateur d'appareil actif (verrou
  /// anti-désinstallation pendant une session).
  static Future<bool> get isDeviceAdminEnabled async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Ouvre le dialogue système d'activation de l'administrateur d'appareil.
  static Future<void> activateDeviceAdmin() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('activateDeviceAdmin');
    } on PlatformException {
      // silencieux : l'utilisateur activera via les réglages
    }
  }

  /// Arme un timer natif exact (AlarmManager) pour la fin de session et
  /// transmet la liste des apps à bloquer au côté natif.
  ///
  /// Retourne faux si la session a été refusée côté natif : sur Android,
  /// Cocon doit être administrateur actif pour démarrer une session
  /// (protection anti-désinstallation garantie).
  static Future<bool> scheduleSessionEnd(
    int durationMinutes,
    List<String> blockedPackages,
  ) async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>('scheduleSessionEnd', <String, Object?>{
            'minutes': durationMinutes,
            'packages': blockedPackages,
          }) ??
          true;
    } on PlatformException {
      return true;
    }
  }

  /// Annule le timer natif (session arrêtée manuellement).
  static Future<void> cancelSessionEnd() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('cancelSessionEnd');
    } on PlatformException {
      // silencieux
    }
  }

  /// Retourne la session native active, ou null s'il n'y en a pas.
  static Future<Map<String, Object?>?> getActiveSession() async {
    if (!_supported) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
          'getActiveSession');
      return result?.cast<String, Object?>();
    } on PlatformException {
      return null;
    }
  }
}
