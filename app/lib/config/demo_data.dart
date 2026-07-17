import '../models/program_exercise_model.dart';
import '../models/program_model.dart';
import '../models/user_model.dart';

/// Profil affiché quand personne n'est connecté, pour permettre de visiter
/// l'intégralité de l'app (design, écrans) sans compte ni backend configuré.
final demoProfile = UserModel(
  id: 'demo-user',
  pseudo: 'Toi (aperçu)',
  email: 'demo@gymquest.app',
  leagueLevel: 3,
  totalPoints: 1240,
  streakHistory: List.generate(12, (_) => const <String, dynamic>{}),
);

/// Programme affiché en aperçu quand personne n'est connecté.
final demoUserProgram = UserProgramModel(
  currentDayLabel: 'Jour 1 — Push',
  program: ProgramModel(
    id: 'demo-program',
    name: 'Programme Découverte',
    description: 'Full-body en 3 séances, pensé pour débuter sur GymQuest.',
    exercises: [
      ProgramExerciseModel(
        id: 'demo-1',
        dayLabel: 'Jour 1 — Push',
        orderIndex: 1,
        exerciseName: 'Développé couché',
        targetedMuscle: 'Pectoraux',
        targetSets: 4,
        targetReps: 10,
        targetWeightKg: 40,
      ),
      ProgramExerciseModel(
        id: 'demo-2',
        dayLabel: 'Jour 1 — Push',
        orderIndex: 2,
        exerciseName: 'Développé militaire',
        targetedMuscle: 'Épaules',
        targetSets: 3,
        targetReps: 10,
        targetWeightKg: 20,
      ),
      ProgramExerciseModel(
        id: 'demo-3',
        dayLabel: 'Jour 1 — Push',
        orderIndex: 3,
        exerciseName: 'Dips',
        targetedMuscle: 'Triceps',
        targetSets: 3,
        targetReps: 12,
        targetWeightKg: 0,
      ),
      ProgramExerciseModel(
        id: 'demo-4',
        dayLabel: 'Jour 1 — Push',
        orderIndex: 4,
        exerciseName: 'Élévations latérales',
        targetedMuscle: 'Épaules',
        targetSets: 3,
        targetReps: 15,
        targetWeightKg: 8,
      ),
      ProgramExerciseModel(
        id: 'demo-5',
        dayLabel: 'Jour 2 — Pull',
        orderIndex: 1,
        exerciseName: 'Tractions',
        targetedMuscle: 'Dos',
        targetSets: 4,
        targetReps: 8,
        targetWeightKg: 0,
      ),
      ProgramExerciseModel(
        id: 'demo-6',
        dayLabel: 'Jour 3 — Legs',
        orderIndex: 1,
        exerciseName: 'Squat',
        targetedMuscle: 'Quadriceps',
        targetSets: 4,
        targetReps: 8,
        targetWeightKg: 60,
      ),
    ],
  ),
);
