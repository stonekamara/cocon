import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/focus_provider.dart';
import '../services/native_bridge.dart';
import '../theme.dart';

/// Sélection des applications à bloquer pendant les sessions.
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<Map<String, Object?>> _apps = const [];
  bool _loading = true;
  String _query = '';
  bool _supported = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final supported = await NativeBridge.isBlockingSupported;
    final apps = await NativeBridge.getInstalledApps();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _apps = apps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    final filtered = _apps.where((app) {
      final name = (app['label'] as String?)?.toLowerCase() ?? '';
      return name.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Apps à bloquer')),
      body: Column(
        children: [
          if (!_supported) _UnsupportedBanner(onRetry: _loadApps),
          if (_supported) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher une application…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${focus.blockedApps.length} sélectionnée${focus.blockedApps.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (focus.blockedApps.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        for (final pkg in List<String>.of(focus.blockedApps)) {
                          await focus.toggleApp(pkg);
                        }
                      },
                      child: const Text('Tout désélectionner'),
                    ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _supported && filtered.isNotEmpty
                    ? ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final app = filtered[index];
                          final pkg = app['package'] as String;
                          final label = app['label'] as String;
                          final selected = focus.blockedApps.contains(pkg);
                          return CheckboxListTile(
                            value: selected,
                            controlAffinity: ListTileControlAffinity.trailing,
                            secondary: _AppIcon(bytes: app['icon'] as Uint8List?),
                            title: Text(label,
                                style: const TextStyle(fontSize: 15)),
                            subtitle: Text(pkg,
                                style: const TextStyle(fontSize: 11)),
                            onChanged: (_) => focus.toggleApp(pkg),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          _supported
                              ? 'Aucune app trouvée'
                              : 'Blocage indisponible sur cette plateforme',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Icône de l'app décodée depuis les octets renvoyés par le natif.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return const CircleAvatar(
        radius: 18,
        child: Icon(Icons.android, size: 20),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundImage: MemoryImage(bytes!),
    );
  }
}

/// Bannière affichée hors Android ou si les permissions manquent.
class _UnsupportedBanner extends StatelessWidget {
  const _UnsupportedBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: CoconColors.amber.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: CoconColors.amber),
            const SizedBox(height: 8),
            const Text(
              "La liste des applications n'est disponible que sur Android. "
              "Sur d'autres plateformes, la sélection est simulée.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
