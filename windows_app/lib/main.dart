import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/inbox.dart';
import 'app/providers.dart';
import 'core/environment.dart';
import 'core/models.dart';
import 'data/repositories.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = EnvironmentConfig.compileTime();
  final failure = env.validate();
  if (failure != null) return runApp(BootFailureApp(failure: failure));
  if (!env.sampleData) {
    try {
      await Firebase.initializeApp(
        options: WebsiteChatFirebaseOptions.forEnvironment(
          FirebaseEnvironment.values.byName(env.environment.name),
        ),
      );
      if (env.useEmulators) {
        await FirebaseAuth.instance.useAuthEmulator(env.emulatorHost, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(env.emulatorHost, 8080);
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
        );
      }
      await FirebaseDeviceSessionRepository(
        FirebaseAuth.instance,
      ).ensureSession();
    } catch (_) {
      return runApp(
        const BootFailureApp(
          failure: InitializationFailure(
            'firebase_initialization_failed',
            'Firebase could not be initialized. Check the selected environment and try again.',
            retryable: true,
          ),
        ),
      );
    }
  }
  runApp(
    ProviderScope(
      overrides: [environmentProvider.overrideWithValue(env)],
      child: const ZevrakoApp(),
    ),
  );
}

class ZevrakoApp extends StatelessWidget {
  const ZevrakoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Zevrako Website AI Chat',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6750a4)),
      scaffoldBackgroundColor: const Color(0xfffbf9ff),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xfff2eff8),
        border: OutlineInputBorder(borderSide: BorderSide.none),
        isDense: true,
      ),
      useMaterial3: true,
    ),
    home: const InboxScreen(),
  );
}

class BootFailureApp extends StatelessWidget {
  const BootFailureApp({required this.failure, super.key});
  final AppFailure failure;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sync_problem, size: 56),
                const SizedBox(height: 18),
                const Text(
                  'Website Chat could not start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(failure.message, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Error: ${failure.code}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
