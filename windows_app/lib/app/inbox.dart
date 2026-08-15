import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/models.dart';
import 'providers.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(environmentProvider);
    final conversations = ref.watch(conversationsProvider);
    final selectedId = ref.watch(selectedConversationIdProvider);
    final selected = conversations.value
        ?.where((c) => c.id == selectedId)
        .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (env.sampleData)
              Container(
                width: double.infinity,
                color: const Color(0xffffe8a3),
                padding: const EdgeInsets.all(7),
                child: const Text(
                  'Sample data — not connected to Firebase',
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, size) {
                  if (size.maxWidth < 760) {
                    return selectedId == null
                        ? ConversationRail(conversations: conversations)
                        : ConversationPane(
                            conversation: selected,
                            onBack: () =>
                                ref
                                        .read(
                                          selectedConversationIdProvider
                                              .notifier,
                                        )
                                        .state =
                                    null,
                          );
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: size.maxWidth < 1050 ? 300 : 360,
                        child: ConversationRail(conversations: conversations),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: ConversationPane(conversation: selected)),
                      if (size.maxWidth >= 1180) ...[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 300,
                          child: CustomerPanel(conversation: selected),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const ConnectionBar(),
          ],
        ),
      ),
    );
  }
}

class ConversationRail extends ConsumerWidget {
  const ConversationRail({required this.conversations, super.key});
  final AsyncValue<List<Conversation>> conversations;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
        child: Row(
          children: [
            const Icon(Icons.forum_rounded, color: Color(0xff6750a4)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Website Chat',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          onChanged: (v) => ref.read(searchProvider.notifier).state = v,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search conversations',
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            FilterChip(
              label: const Text('All'),
              selected: ref.watch(statusFilterProvider) == null,
              onSelected: (_) =>
                  ref.read(statusFilterProvider.notifier).state = null,
            ),
            ...ConversationStatus.values.map(
              (s) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: Text(_title(s.name)),
                  selected: ref.watch(statusFilterProvider) == s,
                  onSelected: (_) =>
                      ref.read(statusFilterProvider.notifier).state = s,
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(),
      Expanded(
        child: conversations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: e is AppFailure
                ? e.message
                : 'Conversations could not be loaded.',
            onRetry: () => ref.invalidate(conversationsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState()
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return ListTile(
                      selected:
                          ref.watch(selectedConversationIdProvider) == c.id,
                      onTap: () =>
                          ref
                                  .read(selectedConversationIdProvider.notifier)
                                  .state =
                              c.id,
                      leading: CircleAvatar(
                        child: Text(c.name.characters.first.toUpperCase()),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.unread > 0) Badge(label: Text('${c.unread}')),
                        ],
                      ),
                      subtitle: Text(
                        c.lastMessagePreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        DateFormat.Hm().format(c.updatedAt.toLocal()),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
        ),
      ),
    ],
  );
}

class ConversationPane extends ConsumerStatefulWidget {
  const ConversationPane({this.conversation, this.onBack, super.key});
  final Conversation? conversation;
  final VoidCallback? onBack;
  @override
  ConsumerState<ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends ConsumerState<ConversationPane> {
  final controller = TextEditingController();
  AiSuggestion? suggestion;
  bool busy = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    if (c == null) {
      return const Center(child: Text('Select a website conversation'));
    }
    final messages = ref.watch(messagesProvider(c.id));
    return Column(
      children: [
        ListTile(
          leading: widget.onBack == null
              ? null
              : IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: Text(
            c.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${c.status.name} • ${c.assignedOperatorId ?? 'Unassigned'}',
          ),
          trailing: PopupMenuButton<ConversationStatus>(
            tooltip: 'Change status',
            onSelected: (s) =>
                _perform(() => ref.read(repositoryProvider).setStatus(c.id, s)),
            itemBuilder: (_) => ConversationStatus.values
                .map(
                  (s) => PopupMenuItem(value: s, child: Text('Mark ${s.name}')),
                )
                .toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              message: e is AppFailure
                  ? e.message
                  : 'Messages are unavailable.',
              onRetry: () => ref.invalidate(messagesProvider(c.id)),
            ),
            data: (items) => items.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    itemBuilder: (_, index) =>
                        MessageBubble(message: items[items.length - index - 1]),
                  ),
          ),
        ),
        if (suggestion != null)
          SuggestionCard(
            suggestion: suggestion!,
            onInsert: () => setState(() {
              controller.text = suggestion!.text;
              suggestion = null;
            }),
            onDiscard: () => setState(() => suggestion = null),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Generate AI suggestion',
                onPressed: busy ? null : () => _suggest(c),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Reply to visitor…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: busy ? null : () => _send(c),
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send(Conversation c) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final ok = await _perform(
      () => ref.read(repositoryProvider).sendMessage(c.id, text),
    );
    if (ok) controller.clear();
  }

  Future<void> _suggest(Conversation c) async {
    final value = await _performValue(
      () => ref
          .read(repositoryProvider)
          .suggest(
            c.id,
            controller.text.trim().isEmpty
                ? 'Suggest a helpful reply based on the conversation.'
                : controller.text,
          ),
    );
    if (value != null && mounted) setState(() => suggestion = value);
  }

  Future<bool> _perform(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
      return true;
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<T?> _performValue<T>(Future<T> Function() action) async {
    setState(() => busy = true);
    try {
      return await action();
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final outgoing = message.role != MessageRole.visitor;
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: outgoing ? const Color(0xff6750a4) : const Color(0xfff0edf7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: outgoing ? Colors.white : null),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat.Hm().format(message.createdAt.toLocal())} • ${message.deliveryState.name}',
              style: TextStyle(
                fontSize: 10,
                color: outgoing ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    required this.suggestion,
    required this.onInsert,
    required this.onDiscard,
    super.key,
  });
  final AiSuggestion suggestion;
  final VoidCallback onInsert, onDiscard;
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xfff7f2ff),
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI suggestion • ${(suggestion.confidence * 100).round()}% application confidence',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(suggestion.text),
              if (suggestion.knowledgeIds.isNotEmpty)
                Text(
                  'Sources: ${suggestion.knowledgeIds.join(', ')}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
        TextButton(onPressed: onInsert, child: const Text('Insert')),
        IconButton(
          tooltip: 'Discard',
          onPressed: onDiscard,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class CustomerPanel extends StatelessWidget {
  const CustomerPanel({this.conversation, super.key});
  final Conversation? conversation;
  @override
  Widget build(BuildContext context) {
    final c = conversation;
    if (c == null) return const Center(child: Text('Customer details'));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Customer', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        _detail(Icons.person_outline, c.name),
        _detail(Icons.email_outlined, c.email ?? 'Email not provided'),
        _detail(Icons.link, c.pageUrl ?? 'Page URL unavailable'),
        _detail(Icons.alt_route, c.referrer ?? 'Referrer unavailable'),
        _detail(Icons.language, c.browser ?? 'Browser unavailable'),
        _detail(Icons.devices, c.deviceType ?? 'Device unavailable'),
        _detail(
          Icons.schedule,
          c.firstSeenAt == null
              ? 'First seen unavailable'
              : DateFormat.yMMMd().add_jm().format(c.firstSeenAt!.toLocal()),
        ),
        const Divider(height: 32),
        Text('Tags', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 6,
          children: c.tags.map((t) => Chip(label: Text(t))).toList(),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Add internal note'),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.block),
          label: Text(c.blocked ? 'Visitor blocked' : 'Block visitor'),
        ),
      ],
    );
  }

  Widget _detail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48),
          SizedBox(height: 12),
          Text('No website conversations'),
          SizedBox(height: 6),
          Text(
            'New visitor conversations will appear here in real time.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class ConnectionBar extends StatelessWidget {
  const ConnectionBar({super.key});
  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    color: const Color(0xffedf7ed),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: const Row(
      children: [
        Icon(Icons.cloud_done_outlined, size: 14, color: Color(0xff2e7d32)),
        SizedBox(width: 6),
        Text('Firebase live sync', style: TextStyle(fontSize: 11)),
        Spacer(),
        Text('Website conversations only', style: TextStyle(fontSize: 11)),
      ],
    ),
  );
}

String _title(String value) => value[0].toUpperCase() + value.substring(1);
