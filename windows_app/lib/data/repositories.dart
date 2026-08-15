import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/models.dart';

abstract interface class DeviceSessionRepository {
  Future<String> ensureSession();
}

class FirebaseDeviceSessionRepository implements DeviceSessionRepository {
  FirebaseDeviceSessionRepository(this.auth);
  final FirebaseAuth auth;
  @override
  Future<String> ensureSession() async {
    try {
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      final token = await user?.getIdToken();
      if (token == null) {
        throw const RepositoryFailure(
          'device_session_failed',
          'The silent development-device session could not be created.',
          retryable: true,
        );
      }
      return token;
    } on FirebaseAuthException catch (e) {
      throw RepositoryFailure(
        'firebase_auth_${e.code}',
        'The silent development-device session failed.',
        retryable: true,
      );
    }
  }
}

abstract interface class ChatRepository {
  Stream<List<Conversation>> watchConversations(String workspaceId);
  Stream<List<ChatMessage>> watchMessages(String conversationId);
  Future<void> sendMessage(String conversationId, String text);
  Future<AiSuggestion> suggest(String conversationId, String message);
  Future<void> setStatus(String conversationId, ConversationStatus status);
  Future<void> addNote(String conversationId, String text);
  Future<void> setTags(String conversationId, List<String> tags);
}

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({
    required this.firestore,
    required this.auth,
    required this.backendUrl,
  });
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Uri backendUrl;
  @override
  Stream<List<Conversation>> watchConversations(String workspaceId) => firestore
      .collection('websiteChatConversations')
      .where('workspaceId', isEqualTo: workspaceId)
      .orderBy('updatedAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Conversation.fromMap(d.id, d.data())).toList(),
      )
      .handleError((Object e) => throw _failure(e));
  @override
  Stream<List<ChatMessage>> watchMessages(String id) => firestore
      .collection('websiteChatConversations')
      .doc(id)
      .collection('messages')
      .orderBy('createdAt')
      .limit(200)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList(),
      )
      .handleError((Object e) => throw _failure(e));
  @override
  Future<void> sendMessage(String id, String text) async {
    await _post('/v1/operator/conversations/$id/messages', {
      'text': text,
      'clientMessageId': _clientId(),
    });
  }

  @override
  Future<AiSuggestion> suggest(String id, String message) async =>
      AiSuggestion.fromJson(
        await _post('/v1/operator/conversations/$id/ai-suggestion', {
          'message': message,
        }),
      );
  @override
  Future<void> setStatus(String id, ConversationStatus status) async {
    await _post('/v1/operator/conversations/$id/status', {
      'status': status.name,
    });
  }

  @override
  Future<void> addNote(String id, String text) async {
    await _post('/v1/operator/conversations/$id/notes', {'text': text});
  }

  @override
  Future<void> setTags(String id, List<String> tags) async {
    await _post('/v1/operator/conversations/$id/tags', {'tags': tags});
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await auth.currentUser?.getIdToken();
    if (token == null) {
      throw const PermissionFailure(
        'operator_session_required',
        'The development device is not authenticated.',
      );
    }
    final response = await http
        .post(
          backendUrl.resolve(path),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final decoded =
        jsonDecode(response.body.isEmpty ? '{}' : response.body)
            as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw RepositoryFailure(
        error?['code'] as String? ?? 'backend_error',
        error?['message'] as String? ?? 'The backend request failed.',
        retryable: error?['retryable'] as bool? ?? false,
      );
    }
    return decoded;
  }

  String _clientId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${auth.currentUser?.uid ?? 'device'}';
  AppFailure _failure(Object e) =>
      e is FirebaseException && e.code == 'permission-denied'
      ? const PermissionFailure(
          'firestore_permission_denied',
          'This development device is not authorized for the website-chat workspace.',
        )
      : const RepositoryFailure(
          'firestore_unavailable',
          'Live conversation synchronization is unavailable.',
          retryable: true,
        );
}

class SampleChatRepository implements ChatRepository {
  final conversations = [
    Conversation(
      id: 'sample-conversation',
      workspaceId: 'sample',
      siteId: 'sample-site',
      visitorId: 'sample-visitor',
      name: 'Sample visitor',
      email: 'visitor@example.test',
      pageUrl: 'https://example.test/pricing',
      referrer: 'https://search.example.test',
      browser: 'Edge',
      deviceType: 'Desktop',
      firstSeenAt: DateTime.utc(2026),
      status: ConversationStatus.open,
      updatedAt: DateTime.utc(2026, 1, 1, 12),
      lastMessagePreview: 'Is delivery available?',
      unread: 1,
      tags: const ['pricing'],
    ),
  ];
  final messages = [
    ChatMessage(
      id: 'sample-message',
      role: MessageRole.visitor,
      text: 'Is delivery available?',
      createdAt: DateTime.utc(2026, 1, 1, 12),
      deliveryState: DeliveryState.delivered,
    ),
  ];
  @override
  Stream<List<Conversation>> watchConversations(String workspaceId) =>
      Stream.value(conversations);
  @override
  Stream<List<ChatMessage>> watchMessages(String id) => Stream.value(messages);
  @override
  Future<void> sendMessage(String id, String text) async {}
  @override
  Future<AiSuggestion> suggest(String id, String message) async => AiSuggestion(
    text: 'Sample suggestion — confirm delivery policy before sending.',
    confidence: .42,
    confidenceSignals: const ['sampleData:true'],
    knowledgeIds: const [],
    model: 'sample',
    generatedAt: DateTime.now().toUtc(),
    fallback: true,
  );
  @override
  Future<void> setStatus(String id, ConversationStatus status) async {}
  @override
  Future<void> addNote(String id, String text) async {}
  @override
  Future<void> setTags(String id, List<String> tags) async {}
}
