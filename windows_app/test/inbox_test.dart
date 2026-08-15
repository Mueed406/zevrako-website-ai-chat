import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zevrako_website_ai_chat/app/inbox.dart';
import 'package:zevrako_website_ai_chat/app/providers.dart';
import 'package:zevrako_website_ai_chat/core/environment.dart';
import 'package:zevrako_website_ai_chat/core/models.dart';
import 'package:zevrako_website_ai_chat/data/repositories.dart';

void main() {
  Widget app({Size size = const Size(1280, 800)}) {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = size;
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    return ProviderScope(
      overrides: [
        environmentProvider.overrideWithValue(
          EnvironmentConfig(
            environment: AppEnvironment.development,
            firebaseEnvironment: 'development',
            workspaceId: 'sample',
            backendUrl: Uri.parse('http://localhost:8787'),
            useEmulators: false,
            sampleData: true,
          ),
        ),
        repositoryProvider.overrideWithValue(SampleChatRepository()),
      ],
      child: const MaterialApp(home: InboxScreen()),
    );
  }

  testWidgets('labels sample data and selects a conversation', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text('Sample data — not connected to Firebase'),
      findsOneWidget,
    );
    expect(find.text('Sample visitor'), findsOneWidget);
    await tester.tap(find.text('Sample visitor'));
    await tester.pump();
    expect(find.text('Is delivery available?'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact layout avoids overflow and supports back navigation', (
    tester,
  ) async {
    await tester.pumpWidget(app(size: const Size(620, 720)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample visitor'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('filters can produce an honest empty state', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InboxScreen)),
    );
    container.read(statusFilterProvider.notifier).state =
        ConversationStatus.resolved;
    await tester.pumpAndSettle();
    expect(find.text('No website conversations'), findsOneWidget);
  });
}
