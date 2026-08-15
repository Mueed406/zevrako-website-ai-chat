import 'package:flutter_test/flutter_test.dart';
import 'package:zevrako_website_ai_chat/core/environment.dart';

void main() {
  test('rejects environment mismatch', () {
    final config = EnvironmentConfig(
      environment: AppEnvironment.production,
      firebaseEnvironment: 'development',
      workspaceId: 'workspace',
      backendUrl: Uri.parse('https://api.example.test'),
      useEmulators: false,
      sampleData: false,
    );
    expect(config.validate()?.code, 'firebase_environment_mismatch');
  });
  test('forbids emulator use outside development', () {
    final config = EnvironmentConfig(
      environment: AppEnvironment.production,
      firebaseEnvironment: 'production',
      workspaceId: 'workspace',
      backendUrl: Uri.parse('https://api.example.test'),
      useEmulators: true,
      sampleData: false,
    );
    expect(config.validate()?.code, 'emulator_forbidden');
  });
}
