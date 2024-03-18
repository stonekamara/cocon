import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/focus_provider.dart';
import 'screens/home_screen.dart';
import 'services/local_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.load();
  runApp(CoconApp(store: store));
}

/// Racine de l'application Cocon.
class CoconApp extends StatelessWidget {
  const CoconApp({super.key, required this.store});

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FocusProvider(store),
      child: MaterialApp(
        title: 'Cocon',
        debugShowCheckedModeBanner: false,
        theme: buildCoconTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
