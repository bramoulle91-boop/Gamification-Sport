import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/exercise_catalog.dart';
import '../../models/duel_model.dart';
import '../../models/friendship_model.dart';
import '../../services/providers.dart';

final _myDuelsProvider = FutureProvider<List<DuelModel>>((ref) {
  return ref.watch(duelServiceProvider).fetchMyDuels();
});

final _duelScoresProvider = FutureProvider.family<(double, double), String>((ref, duelId) {
  return ref.watch(duelServiceProvider).fetchScores(duelId);
});

final _myFriendshipsForDuelsProvider = FutureProvider<List<FriendshipModel>>((ref) {
  return ref.watch(friendshipServiceProvider).fetchMyFriendships();
});

String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _timeRemaining(DateTime endsAt) {
  final diff = endsAt.toUtc().difference(DateTime.now().toUtc());
  if (diff.isNegative) return 'Terminé, calcul en cours...';
  if (diff.inDays >= 1) return 'Encore ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
  if (diff.inHours >= 1) return 'Encore ${diff.inHours} h';
  return 'Encore ${diff.inMinutes} min';
}

/// Défis entre amis : qui soulève le plus lourd sur un exercice donné
/// pendant une période fixée. Le score vient des vraies performances/
/// exercices déjà validés — rien à saisir en plus.
class DuelsScreen extends ConsumerStatefulWidget {
  const DuelsScreen({super.key});

  @override
  ConsumerState<DuelsScreen> createState() => _DuelsScreenState();
}

class _DuelsScreenState extends ConsumerState<DuelsScreen> {
  bool _busy = false;

  Future<void> _respond(DuelModel duel, bool accept) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(duelServiceProvider).respondToDuel(duelId: duel.id, accept: accept);
      ref.invalidate(_myDuelsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCreateSheet() async {
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour lancer un défi.')),
      );
      return;
    }
    final myId = ref.read(currentUserIdProvider)!;
    final friendships = await ref.read(_myFriendshipsForDuelsProvider.future);
    final friends = friendships.where((f) => f.status == FriendshipStatus.unlocked).toList();
    if (friends.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoute au moins un ami avant de lancer un défi.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateDuelSheet(friends: friends, myId: myId),
    );
    if (created == true) {
      ref.invalidate(_myDuelsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duelsAsync = ref.watch(_myDuelsProvider);
    final myId = ref.watch(currentUserIdProvider);
    final isLoggedIn = myId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Défis')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _openCreateSheet,
        icon: const Icon(Icons.bolt),
        label: const Text('Nouveau défi'),
      ),
      body: !isLoggedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Connecte-toi pour défier tes amis.', textAlign: TextAlign.center),
              ),
            )
          : duelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (duels) {
                if (duels.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Aucun défi pour l'instant — lance-en un à un ami sur un exercice !",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final pending = duels.where((d) => d.status == DuelStatus.pending && d.opponentId == myId).toList();
                final active = duels.where((d) => d.status == DuelStatus.active).toList();
                final finished =
                    duels.where((d) => d.status == DuelStatus.finished || d.status == DuelStatus.declined).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    if (pending.isNotEmpty) ...[
                      const _SectionTitle('En attente de ta réponse'),
                      ...pending.map((d) => _PendingDuelTile(duel: d, onRespond: (accept) => _respond(d, accept))),
                      const SizedBox(height: 16),
                    ],
                    if (active.isNotEmpty) ...[
                      const _SectionTitle('En cours'),
                      ...active.map((d) => _ActiveDuelTile(duel: d, myId: myId)),
                      const SizedBox(height: 16),
                    ],
                    if (finished.isNotEmpty) ...[
                      const _SectionTitle('Terminés'),
                      ...finished.map((d) => _FinishedDuelTile(duel: d, myId: myId)),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _PendingDuelTile extends StatelessWidget {
  const _PendingDuelTile({required this.duel, required this.onRespond});

  final DuelModel duel;
  final void Function(bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bolt, color: Colors.orange),
        title: Text('${duel.challengerPseudo ?? '?'} te défie sur ${duel.exerciseName}'),
        subtitle: Text('Jusqu\'au ${_formatDate(duel.endsAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => onRespond(true),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => onRespond(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveDuelTile extends ConsumerStatefulWidget {
  const _ActiveDuelTile({required this.duel, required this.myId});

  final DuelModel duel;
  final String? myId;

  @override
  ConsumerState<_ActiveDuelTile> createState() => _ActiveDuelTileState();
}

class _ActiveDuelTileState extends ConsumerState<_ActiveDuelTile> {
  @override
  void initState() {
    super.initState();
    if (widget.duel.isPastDue) {
      Future.microtask(() async {
        await ref.read(duelServiceProvider).settleIfNeeded(widget.duel.id);
        if (mounted) ref.invalidate(_myDuelsProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoresAsync = ref.watch(_duelScoresProvider(widget.duel.id));
    final myId = widget.myId;
    final isChallenger = myId == widget.duel.challengerId;
    final opponentPseudo = myId == null ? '?' : widget.duel.opponentPseudoFor(myId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toi vs $opponentPseudo — ${widget.duel.exerciseName}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              _timeRemaining(widget.duel.endsAt),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            scoresAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Scores indisponibles pour le moment.'),
              data: (scores) {
                final myBest = isChallenger ? scores.$1 : scores.$2;
                final theirBest = isChallenger ? scores.$2 : scores.$1;
                return Row(
                  children: [
                    Expanded(
                      child: _ScoreBar(label: 'Toi', value: myBest, isLeading: myBest > theirBest),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ScoreBar(label: opponentPseudo, value: theirBest, isLeading: theirBest > myBest),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value, required this.isLeading});

  final String label;
  final double value;
  final bool isLeading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          '${value.toStringAsFixed(0)} kg',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isLeading ? scheme.primary : null),
        ),
        if (isLeading && value > 0) const Text('En tête 🔥', style: TextStyle(fontSize: 11, color: Colors.deepOrange)),
      ],
    );
  }
}

class _FinishedDuelTile extends StatelessWidget {
  const _FinishedDuelTile({required this.duel, required this.myId});

  final DuelModel duel;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    if (duel.status == DuelStatus.declined) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.block, color: Colors.grey),
          title: Text('${duel.exerciseName} — refusé'),
        ),
      );
    }
    final iWon = duel.winnerId != null && duel.winnerId == myId;
    final draw = duel.winnerId == null;
    final localMyId = myId;
    final opponentPseudo = localMyId == null ? '?' : duel.opponentPseudoFor(localMyId);
    return Card(
      child: ListTile(
        leading: Icon(
          draw ? Icons.handshake : (iWon ? Icons.emoji_events : Icons.sentiment_dissatisfied),
          color: draw ? Colors.grey : (iWon ? Colors.amber.shade700 : Colors.grey),
        ),
        title: Text('${duel.exerciseName} vs $opponentPseudo'),
        subtitle: Text(draw ? 'Égalité' : (iWon ? 'Tu as gagné 🏆 +50 pts' : 'Perdu')),
      ),
    );
  }
}

class _CreateDuelSheet extends StatefulWidget {
  const _CreateDuelSheet({required this.friends, required this.myId});

  final List<FriendshipModel> friends;
  final String myId;

  @override
  State<_CreateDuelSheet> createState() => _CreateDuelSheetState();
}

class _CreateDuelSheetState extends State<_CreateDuelSheet> {
  String? _opponentId;
  TextEditingController? _exerciseFieldController;
  Duration _duration = const Duration(days: 7);
  bool _saving = false;

  Future<void> _submit(WidgetRef ref) async {
    final exerciseName = (_exerciseFieldController?.text ?? '').trim();
    if (_opponentId == null || exerciseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis un ami et un exercice.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(duelServiceProvider).createDuel(
            opponentId: _opponentId!,
            exerciseName: exerciseName,
            duration: _duration,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _durationChip(String label, Duration d) {
    return ChoiceChip(
      label: Text(label),
      selected: _duration == d,
      onSelected: (_) => setState(() => _duration = d),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Consumer(
        builder: (context, ref, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouveau défi', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _opponentId,
                decoration: const InputDecoration(labelText: 'Défier'),
                items: widget.friends.map((f) {
                  final id = f.userId1 == widget.myId ? f.userId2 : f.userId1;
                  return DropdownMenuItem(value: id, child: Text(f.pseudoForOther(widget.myId)));
                }).toList(),
                onChanged: (v) => setState(() => _opponentId = v),
              ),
              const SizedBox(height: 8),
              Autocomplete<ExerciseCatalogEntry>(
                displayStringForOption: (e) => e.name,
                optionsBuilder: (value) => value.text.isEmpty
                    ? const Iterable<ExerciseCatalogEntry>.empty()
                    : exerciseCatalog.where((e) => e.name.toLowerCase().contains(value.text.toLowerCase())),
                onSelected: (e) => _exerciseFieldController?.text = e.name,
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  _exerciseFieldController = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Exercice (ex: Développé couché)'),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text('Durée', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _durationChip('3 jours', const Duration(days: 3)),
                  _durationChip('7 jours', const Duration(days: 7)),
                  _durationChip('14 jours', const Duration(days: 14)),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : () => _submit(ref),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Lancer le défi'),
              ),
            ],
          );
        },
      ),
    );
  }
}
