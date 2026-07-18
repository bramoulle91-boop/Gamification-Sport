import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';

const _weekdayLabels = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _weekdayShort = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _monthNames = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

/// Calendrier hebdomadaire : quelle séance faire chaque jour de la
/// semaine (modifiable à tout moment, contrairement à l'ancienne rotation
/// figée jour après jour), et un mois calendaire montrant les jours
/// "streak" où au moins un exercice a été validé.
class ProgramCalendarScreen extends ConsumerStatefulWidget {
  const ProgramCalendarScreen({super.key});

  @override
  ConsumerState<ProgramCalendarScreen> createState() => _ProgramCalendarScreenState();
}

class _ProgramCalendarScreenState extends ConsumerState<ProgramCalendarScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<int, String?>? _draftSchedule;
  bool _saving = false;

  void _initDraftIfNeeded(Map<int, String?> serverSchedule) {
    if (_draftSchedule != null) return;
    _draftSchedule = {
      for (var w = 1; w <= 7; w++) w: serverSchedule.containsKey(w) ? serverSchedule[w] : null,
    };
  }

  Future<void> _save() async {
    final draft = _draftSchedule;
    if (draft == null) return;
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour modifier ton calendrier.')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(programServiceProvider).setWeeklySchedule(draft);
      ref.invalidate(myProgramProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Calendrier enregistré 📅')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programAsync = ref.watch(myProgramProvider);
    final completionsAsync = ref.watch(myCompletionDatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon calendrier')),
      body: programAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (userProgram) {
          if (userProgram == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Choisis ou crée d'abord un programme sur l'accueil pour configurer ton calendrier.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          _initDraftIfNeeded(userProgram.weeklySchedule);
          final dayLabels = userProgram.program.dayLabels;
          final completions = completionsAsync.valueOrNull ?? <DateTime>{};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonthGrid(
                month: _visibleMonth,
                completionDates: completions,
                onPrevMonth: () => setState(
                  () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1),
                ),
                onNextMonth: () => setState(
                  () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Text(
                    '${completions.length} jour${completions.length > 1 ? 's' : ''} actif${completions.length > 1 ? 's' : ''} au total',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Calendrier hebdomadaire', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Choisis quelle séance faire chaque jour de la semaine — change ça quand tu veux.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (var weekday = 1; weekday <= 7; weekday++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 90, child: Text(_weekdayLabels[weekday - 1])),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _draftSchedule![weekday],
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Repos')),
                            ...dayLabels.map((d) => DropdownMenuItem<String?>(value: d, child: Text(d))),
                          ],
                          onChanged: (v) => setState(() => _draftSchedule![weekday] = v),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer mon calendrier'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Grille mensuelle : un point coloré + une flamme sur les jours où
/// l'utilisateur a validé au moins un exercice ("streak"), un contour sur
/// aujourd'hui.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.completionDates,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final Set<DateTime> completionDates;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  bool _isCompleted(DateTime day) =>
      completionDates.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // lundi = 1 -> 0 case vide
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: onPrevMonth, icon: const Icon(Icons.chevron_left)),
            Text('${_monthNames[month.month - 1]} ${month.year}', style: Theme.of(context).textTheme.titleMedium),
            IconButton(onPressed: onNextMonth, icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: _weekdayShort
              .map((l) => Expanded(child: Center(child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)))))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              Builder(
                builder: (context) {
                  final date = DateTime(month.year, month.month, d);
                  final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                  final done = _isCompleted(date);
                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: done ? scheme.primary.withOpacity(0.16) : null,
                      shape: BoxShape.circle,
                      border: isToday ? Border.all(color: scheme.primary, width: 2) : null,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$d', style: TextStyle(fontWeight: isToday ? FontWeight.bold : null, fontSize: 13)),
                        if (done) const Icon(Icons.local_fire_department, size: 9, color: Colors.deepOrange),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
