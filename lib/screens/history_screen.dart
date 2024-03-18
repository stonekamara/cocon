import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/focus_provider.dart';
import '../theme.dart';

/// Historique des sessions avec petites stats.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    final sessions = focus.history;
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));

    final weekSessions =
        sessions.where((s) => s.startedAt.isAfter(weekAgo)).toList();
    final weekMinutes =
        weekSessions.fold<int>(0, (sum, s) => sum + s.actualMinutes);

    final dateFormat = DateFormat('EEEE d MMMM', 'fr_FR');

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: sessions.isEmpty
          ? const Center(
              child: Text(
                'Aucune session pour le moment.\n'
                'Lance ta première session !',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _StatCard(
                      label: 'Cette semaine',
                      value: '$weekMinutes min',
                      icon: Icons.timer_outlined,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Sessions (7 j)',
                      value: '${weekSessions.length}',
                      icon: Icons.event_available_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...sessions.map(
                  (s) => Card(
                    child: ListTile(
                      leading: Icon(
                        s.completed
                            ? Icons.check_circle
                            : Icons.cancel_outlined,                        color: s.completed
                            ? CoconColors.deepBlue
                            : CoconColors.amber,
                      ),
                      title: Text(
                        s.completed
                            ? '${s.plannedMinutes} min terminées'
                            : 'Interrompue après ${s.actualMinutes} min',
                      ),
                      subtitle: Text(dateFormat.format(s.startedAt)),
                      trailing: Text(
                        '${s.actualMinutes} min',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: CoconColors.deepBlue),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: CoconColors.ink.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}
