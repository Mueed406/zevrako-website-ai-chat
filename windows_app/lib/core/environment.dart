import 'models.dart';

enum AppEnvironment { development, staging, production }

class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.firebaseEnvironment,
    required this.workspaceId,
    required this.backendUrl,
    required this.useEmulators,
    required this.sampleData,
    this.emulatorHost = '127.0.0.1',
  });
  factory EnvironmentConfig.compileTime() => EnvironmentConfig(
    environment:
        AppEnvironment.values
            .where(
              (v) =>
                  v.name ==
                  const String.fromEnvironment(
                    'ZEVRAKO_ENV',
                    defaultValue: 'development',
                  ),
            )
            .firstOrNull ??
        AppEnvironment.development,
    firebaseEnvironment: const String.fromEnvironment(
      'ZEVRAKO_FIREBASE_ENVIRONMENT',
      defaultValue: 'development',
    ),
    workspaceId: const String.fromEnvironment(
      'ZEVRAKO_WEBSITE_CHAT_WORKSPACE_ID',
    ),
    backendUrl: Uri.parse(
      const String.fromEnvironment(
        'ZEVRAKO_BACKEND_URL',
        defaultValue: 'http://127.0.0.1:8787',
      ),
    ),
    useEmulators: const bool.fromEnvironment('ZEVRAKO_USE_FIREBASE_EMULATORS'),
    sampleData: const bool.fromEnvironment('ZEVRAKO_SAMPLE_DATA'),
    emulatorHost: const String.fromEnvironment(
      'ZEVRAKO_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    ),
  );
  final AppEnvironment environment;
  final String firebaseEnvironment, workspaceId, emulatorHost;
  final Uri backendUrl;
  final bool useEmulators, sampleData;
  AppFailure? validate() {
    if (firebaseEnvironment != environment.name) {
      return const InitializationFailure(
        'firebase_environment_mismatch',
        'Firebase configuration does not match the selected application environment.',
      );
    }
    if (environment != AppEnvironment.development && useEmulators) {
      return const InitializationFailure(
        'emulator_forbidden',
        'Firebase emulators are only permitted in development.',
      );
    }
    if (environment != AppEnvironment.development &&
        backendUrl.scheme != 'https') {
      return const InitializationFailure(
        'https_required',
        'The backend must use HTTPS outside development.',
      );
    }
    if (!sampleData && workspaceId.isEmpty) {
      return const InitializationFailure(
        'workspace_missing',
        'Set ZEVRAKO_WEBSITE_CHAT_WORKSPACE_ID for this development device.',
      );
    }
    return null;
  }
}
