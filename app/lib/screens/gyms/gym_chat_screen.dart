import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/gym_message_model.dart';
import '../../services/providers.dart';
import '../../widgets/demo_mode_banner.dart';

final _gymNameProvider = FutureProvider.family<String, String>((ref, gymId) async {
  final gym = await ref.watch(gymServiceProvider).fetchGymById(gymId);
  return gym?.name ?? 'Salle';
});

final _gymMessagesStreamProvider = StreamProvider.family<List<GymMessageModel>, String>((ref, gymId) {
  return ref.watch(gymChatServiceProvider).streamMessages(gymId);
});

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Tchat en direct d'une salle (Supabase Realtime) — visible par tous,
/// pour ceux qui la fréquentent.
class GymChatScreen extends ConsumerStatefulWidget {
  const GymChatScreen({required this.gymId, super.key});

  final String gymId;

  @override
  ConsumerState<GymChatScreen> createState() => _GymChatScreenState();
}

class _GymChatScreenState extends ConsumerState<GymChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  Future<void> _deleteMessage(GymMessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: Text(msg.message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(gymChatServiceProvider).deleteMessage(msg.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour discuter.')),
      );
      return;
    }
    final profile = ref.read(currentProfileProvider).valueOrNull;
    setState(() => _sending = true);
    try {
      await ref.read(gymChatServiceProvider).sendMessage(
            gymId: widget.gymId,
            pseudo: profile?.pseudo ?? '?',
            message: text,
          );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nameAsync = ref.watch(_gymNameProvider(widget.gymId));
    final messagesAsync = ref.watch(_gymMessagesStreamProvider(widget.gymId));
    final myId = ref.watch(currentUserIdProvider);
    final isLoggedIn = myId != null;

    return Scaffold(
      appBar: AppBar(
        title: nameAsync.when(
          data: (name) => Text('💬 $name'),
          loading: () => const Text('💬 Discussion'),
          error: (_, __) => const Text('💬 Discussion'),
        ),
      ),
      body: Column(
        children: [
          if (!isLoggedIn)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DemoModeBanner(),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Aucun message pour l'instant — sois le premier à écrire !",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.userId == myId;
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMine ? () => _deleteMessage(msg) : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMine)
                                Text(
                                  msg.pseudo,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              Text(msg.message),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(msg.createdAt),
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                                  ),
                                  if (isMine) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.more_horiz, size: 12, color: Theme.of(context).colorScheme.outline),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Écris un message...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
