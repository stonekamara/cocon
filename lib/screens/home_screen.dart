import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/focus_provider.dart';
import '../services/native_bridge.dart';
import '../theme.dart';
import 'apps_screen.dart';
import 'history_screen.dart';

/// Écran d'accueil : minuteur circulaire, choix de durée, lancement.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _accessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccessibility();
    _restoreSessionIfNeeded();
  }

  /// Si une session tourne déjà (côté natif, même après redémarrage de l'app),
  /// on restaure le compte à rebours à l'écran.
  Future<void> _restoreSessionIfNeeded() async {
    await context.read<FocusProvider>().restoreFromNative();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Rafraîchit l'état du service (une réinstallation peut le désactiver)
      // et resynchronise la session avec l'état natif (ex : arrêt via code
      // PIN sur l'écran de blocage → la session locale se termine aussi).
      _refreshAccessibility();
      _syncSessionState();
      _refreshDeviceAdminStatus();
    }
  }

  /// Met à jour le statut de l'admin après le dialogue système : dès qu'il
  /// est actif, la bannière "admin requis" disparaît.
  Future<void> _refreshDeviceAdminStatus() async {
    await context.read<FocusProvider>().refreshDeviceAdminStatus();
  }

  /// Synchronise l'état local avec le natif : si la session native a été
  /// arrêtée (code trouvé) alors que le chrono local tournait encore, on
  /// termine proprement l'état local.
  Future<void> _syncSessionState() async {
    final focus = context.read<FocusProvider>();
    final nativeActive = await NativeBridge.getActiveSession() != null;
    if (!nativeActive && focus.phase != FocusPhase.idle) {
      await focus.stopSession(completed: false);
    } else {
      await focus.restoreFromNative();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshAccessibility() async {
    final enabled = await NativeBridge.isAccessibilityEnabled;
    if (!mounted) return;
    setState(() => _accessibilityEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    final running = focus.phase != FocusPhase.idle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cocon',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
              _refreshAccessibility();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _TimerRing(),
                const SizedBox(height: 32),
                if (!running) ...[
                  if (!_accessibilityEnabled)
                    _AccessibilityBanner(
                        onEnabled: _refreshAccessibility),
                  const SizedBox(height: 16),
                  if (focus.deviceAdminRequired)
                    _AdminBanner(onEnabled: _refreshDeviceAdminStatus),
                  const SizedBox(height: 16),
                  const _DurationPicker(),
                  const SizedBox(height: 24),
                  _BlockedAppsBanner(count: focus.blockedApps.length),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.self_improvement),
                    label: const Text('Entrer dans le cocon',
                        style: TextStyle(fontSize: 16)),
                    onPressed: focus.hasBlockedApps
                        ? () => context
                            .read<FocusProvider>()
                            .startSession(focus.defaultMinutes)
                        : null,
                  ),
                ] else ...[
                  Text(
                    'Reste concentré…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  // Pas de pause ni d'arrêt : la session ne peut être
                  // interrompue que via le code PIN (écran de blocage).
                  Text(
                    'Pour arrêter avant la fin, trouve le code '
                    'sur l\'écran de blocage.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CoconColors.ink.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// Bannière invitante à activer le service d'accessibilité (requis pour le
/// blocage). Se masque une fois le service activé.
class _AccessibilityBanner extends StatelessWidget {
  const _AccessibilityBanner({required this.onEnabled});

  final VoidCallback onEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CoconColors.amber.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.shield_outlined, color: CoconColors.amber),
            const SizedBox(height: 8),
            const Text(
              'Active le service Cocon pour que le blocage fonctionne.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Dans les réglages Android : Services installés → Cocon → activer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await NativeBridge.openAccessibilitySettings();
                // L'utilisateur revient des réglages : on rafraîchit l'état.
                await Future<void>.delayed(const Duration(seconds: 2));
                onEnabled();
              },
              child: const Text('Ouvrir les réglages'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bannière d'admin d'appareil requis : une session ne démarre que si Cocon
/// est administrateur (verrou anti-désinstallation garanti). Se masque dès
/// que l'admin est activé.
class _AdminBanner extends StatelessWidget {
  const _AdminBanner({required this.onEnabled});

  final VoidCallback onEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CoconColors.amber.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.admin_panel_settings_outlined,
                color: CoconColors.amber),
            const SizedBox(height: 8),
            const Text(
              'Active Cocon comme administrateur pour lancer une session.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pendant une session, Cocon ne pourra pas être désinstallé. '
              'L\'admin sera retiré automatiquement à la fin du chrono.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await NativeBridge.activateDeviceAdmin();
                // L'utilisateur revient du dialogue système : on re-vérifie.
                await Future<void>.delayed(const Duration(seconds: 2));
                onEnabled();
              },
              child: const Text('Activer l\'admin'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grand cercle de progression avec le temps restant au centre.
class _TimerRing extends StatelessWidget {
  const _TimerRing();

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    final remaining = Duration(seconds: focus.secondsLeft);
    final label =
        '${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: CircularProgressIndicator(
              value: focus.progress,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              backgroundColor: CoconColors.cloud.withValues(alpha: 0.35),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(CoconColors.deepBlue),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontWeight: FontWeight.w300)),
              const SizedBox(height: 4),
              const Icon(Icons.center_focus_strong, color: CoconColors.blue),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de durée (chips).
class _DurationPicker extends StatelessWidget {
  const _DurationPicker();

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: FocusProvider.presetDurations.map((minutes) {
        final selected = focus.defaultMinutes == minutes;
        return ChoiceChip(
          label: Text('$minutes min'),
          selected: selected,
          onSelected: (_) =>
              context.read<FocusProvider>().setDefaultMinutes(minutes),
          selectedColor: CoconColors.deepBlue,
          labelStyle: TextStyle(
            color: selected ? Colors.white : CoconColors.ink,
          ),
        );
      }).toList(),
    );
  }
}

/// Rappel des apps bloquées + accès à la sélection.
class _BlockedAppsBanner extends StatelessWidget {
  const _BlockedAppsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_outline, color: CoconColors.deepBlue),
        title: Text(count == 0
            ? 'Aucune app sélectionnée'
            : '$count app${count > 1 ? 's' : ''} à bloquer'),
        subtitle: count == 0
            ? const Text('Choisis les apps à bloquer pendant les sessions')
            : const Text('Toucher pour modifier'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AppsScreen()),
        ),
      ),
    );
  }
}
