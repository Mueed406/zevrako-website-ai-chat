import 'package:cloud_firestore/cloud_firestore.dart';

enum ConversationStatus { open, waiting, resolved, spam }

enum DeliveryState { sending, delivered, failed }

enum MessageRole { visitor, operator, assistant, system }

DateTime utcDate(Object? value) => switch (value) {
  Timestamp v => v.toDate().toUtc(),
  DateTime v => v.toUtc(),
  String v => DateTime.parse(v).toUtc(),
  _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
};

class Conversation {
  const Conversation({
    required this.id,
    required this.workspaceId,
    required this.siteId,
    required this.visitorId,
    required this.status,
    required this.updatedAt,
    this.name = 'Website visitor',
    this.email,
    this.pageUrl,
    this.referrer,
    this.browser,
    this.deviceType,
    this.firstSeenAt,
    this.lastMessagePreview = '',
    this.unread = 0,
    this.assignedOperatorId,
    this.tags = const [],
    this.blocked = false,
  });
  final String id, workspaceId, siteId, visitorId, name, lastMessagePreview;
  final String? email,
      pageUrl,
      referrer,
      browser,
      deviceType,
      assignedOperatorId;
  final DateTime updatedAt;
  final DateTime? firstSeenAt;
  final ConversationStatus status;
  final int unread;
  final List<String> tags;
  final bool blocked;
  factory Conversation.fromMap(String id, Map<String, dynamic> map) =>
      Conversation(
        id: id,
        workspaceId: map['workspaceId'] as String? ?? '',
        siteId: map['siteId'] as String? ?? '',
        visitorId: map['visitorId'] as String? ?? '',
        name: map['visitorName'] as String? ?? 'Website visitor',
        email: map['visitorEmail'] as String?,
        pageUrl: map['pageUrl'] as String?,
        referrer: map['referrer'] as String?,
        browser: map['browser'] as String?,
        deviceType: map['deviceType'] as String?,
        firstSeenAt: map['firstSeenAt'] == null
            ? null
            : utcDate(map['firstSeenAt']),
        status:
            ConversationStatus.values
                .where((e) => e.name == map['status'])
                .firstOrNull ??
            ConversationStatus.open,
        updatedAt: utcDate(map['updatedAt']),
        lastMessagePreview: map['lastMessagePreview'] as String? ?? '',
        unread: map['unreadOperator'] as int? ?? 0,
        assignedOperatorId: map['assignedOperatorId'] as String?,
        tags: List<String>.from(map['tags'] as List? ?? const []),
        blocked: map['blocked'] as bool? ?? false,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    required this.deliveryState,
    this.senderId = '',
  });
  final String id, text, senderId;
  final MessageRole role;
  final DateTime createdAt;
  final DeliveryState deliveryState;
  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) =>
      ChatMessage(
        id: id,
        role:
            MessageRole.values
                .where((e) => e.name == map['role'])
                .firstOrNull ??
            MessageRole.system,
        text: map['text'] as String? ?? '',
        senderId: map['senderId'] as String? ?? '',
        createdAt: utcDate(map['createdAt']),
        deliveryState:
            DeliveryState.values
                .where((e) => e.name == map['deliveryState'])
                .firstOrNull ??
            DeliveryState.delivered,
      );
}

sealed class AppFailure implements Exception {
  const AppFailure(this.code, this.message, {this.retryable = false});
  final String code, message;
  final bool retryable;
}

class InitializationFailure extends AppFailure {
  const InitializationFailure(super.code, super.message, {super.retryable});
}

class RepositoryFailure extends AppFailure {
  const RepositoryFailure(super.code, super.message, {super.retryable});
}

class PermissionFailure extends AppFailure {
  const PermissionFailure(super.code, super.message) : super(retryable: false);
}

class AiSuggestion {
  const AiSuggestion({
    required this.text,
    required this.confidence,
    required this.confidenceSignals,
    required this.knowledgeIds,
    required this.model,
    required this.generatedAt,
    required this.fallback,
  });
  final String text, model;
  final double confidence;
  final List<String> confidenceSignals, knowledgeIds;
  final DateTime generatedAt;
  final bool fallback;
  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
    text: json['text'] as String,
    confidence: (json['confidence'] as num).toDouble(),
    confidenceSignals: List<String>.from(json['confidenceSignals'] as List),
    knowledgeIds: List<String>.from(json['knowledgeIds'] as List),
    model: json['model'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String).toUtc(),
    fallback: json['fallback'] as bool,
  );
}
