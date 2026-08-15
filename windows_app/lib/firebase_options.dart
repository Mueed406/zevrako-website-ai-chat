import 'package:firebase_core/firebase_core.dart';

enum FirebaseEnvironment { development, staging, production }

class WebsiteChatFirebaseOptions {
  // Reused FlutterFire Windows client for zevrako-auto-reply-ai-dev.
  static const developmentWindows = FirebaseOptions(
    apiKey: 'AIzaSyAcUe9CQXcx7UsIDTrycCLGI1yZNcbzS4k',
    appId: '1:285607270084:web:2abbe0488f298af6769b91',
    messagingSenderId: '285607270084',
    projectId: 'zevrako-auto-reply-ai-dev',
    authDomain: 'zevrako-auto-reply-ai-dev.firebaseapp.com',
    storageBucket: 'zevrako-auto-reply-ai-dev.firebasestorage.app',
    measurementId: 'G-ZZQYNN7D12',
  );
  static FirebaseOptions forEnvironment(FirebaseEnvironment environment) {
    if (environment == FirebaseEnvironment.development) {
      return developmentWindows;
    }
    const apiKey = String.fromEnvironment('ZEVRAKO_FIREBASE_API_KEY');
    const appId = String.fromEnvironment('ZEVRAKO_FIREBASE_APP_ID');
    const sender = String.fromEnvironment(
      'ZEVRAKO_FIREBASE_MESSAGING_SENDER_ID',
    );
    const project = String.fromEnvironment('ZEVRAKO_FIREBASE_PROJECT_ID');
    if ([apiKey, appId, sender, project].any((v) => v.isEmpty)) {
      throw StateError(
        'Firebase configuration is missing for this environment.',
      );
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: project,
      authDomain: String.fromEnvironment('ZEVRAKO_FIREBASE_AUTH_DOMAIN'),
    );
  }
}
