import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/environment.dart';
import '../core/models.dart';
import '../data/repositories.dart';

final environmentProvider = Provider<EnvironmentConfig>(
  (_) => EnvironmentConfig.compileTime(),
);
final repositoryProvider = Provider<ChatRepository>((ref) {
  final env = ref.watch(environmentProvider);
  return env.sampleData
      ? SampleChatRepository()
      : FirebaseChatRepository(
          firestore: FirebaseFirestore.instance,
          auth: FirebaseAuth.instance,
          backendUrl: env.backendUrl,
        );
});
final statusFilterProvider = StateProvider<ConversationStatus?>((_) => null);
final searchProvider = StateProvider<String>((_) => '');
final selectedConversationIdProvider = StateProvider<String?>((_) => null);
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final env = ref.watch(environmentProvider);
  final filter = ref.watch(statusFilterProvider);
  final search = ref.watch(searchProvider).toLowerCase().trim();
  return ref
      .watch(repositoryProvider)
      .watchConversations(env.sampleData ? 'sample' : env.workspaceId)
      .map(
        (items) => items
            .where(
              (c) =>
                  (filter == null || c.status == filter) &&
                  (search.isEmpty ||
                      c.name.toLowerCase().contains(search) ||
                      c.email?.toLowerCase().contains(search) == true ||
                      c.lastMessagePreview.toLowerCase().contains(search)),
            )
            .toList(),
      );
});
final messagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, id) => ref.watch(repositoryProvider).watchMessages(id),
);
