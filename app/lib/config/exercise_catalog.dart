import 'package:flutter/material.dart';

/// Un exercice du catalogue prédéfini, pour construire un programme sans
/// tout taper à la main — reste entièrement personnalisable : on peut aussi
/// taper un nom d'exercice qui n'y figure pas.
class ExerciseCatalogEntry {
  const ExerciseCatalogEntry({
    required this.name,
    required this.muscleGroup,
    this.defaultSets = 3,
    this.defaultReps = 10,
  });

  final String name;
  final String muscleGroup;
  final int defaultSets;
  final int defaultReps;
}

/// Icône représentant le groupe musculaire (repère visuel rapide, pas une
/// photo de l'exécution du mouvement — voir le lien "Voir la technique"
/// pour une vraie démonstration vidéo).
IconData iconForMuscleGroup(String? muscleGroup) {
  switch (muscleGroup) {
    case 'Pectoraux':
      return Icons.fitness_center;
    case 'Dos':
      return Icons.rowing;
    case 'Épaules':
      return Icons.accessibility_new;
    case 'Biceps':
    case 'Triceps':
      return Icons.sports_gymnastics;
    case 'Quadriceps':
    case 'Ischio-jambiers':
    case 'Mollets':
      return Icons.directions_walk;
    case 'Abdominaux':
      return Icons.self_improvement;
    default:
      return Icons.fitness_center;
  }
}

const exerciseCatalog = <ExerciseCatalogEntry>[
  // Pectoraux
  ExerciseCatalogEntry(name: 'Développé couché', muscleGroup: 'Pectoraux', defaultSets: 4, defaultReps: 10),
  ExerciseCatalogEntry(name: 'Développé incliné haltères', muscleGroup: 'Pectoraux', defaultSets: 4, defaultReps: 10),
  ExerciseCatalogEntry(name: 'Écarté couché', muscleGroup: 'Pectoraux', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Pompes', muscleGroup: 'Pectoraux', defaultSets: 3, defaultReps: 15),
  ExerciseCatalogEntry(name: 'Dips (pectoraux)', muscleGroup: 'Pectoraux', defaultSets: 3, defaultReps: 12),
  // Dos
  ExerciseCatalogEntry(name: 'Tractions', muscleGroup: 'Dos', defaultSets: 4, defaultReps: 8),
  ExerciseCatalogEntry(name: 'Rowing barre', muscleGroup: 'Dos', defaultSets: 4, defaultReps: 10),
  ExerciseCatalogEntry(name: 'Tirage vertical', muscleGroup: 'Dos', defaultSets: 4, defaultReps: 10),
  ExerciseCatalogEntry(name: 'Rowing haltère unilatéral', muscleGroup: 'Dos', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Soulevé de terre', muscleGroup: 'Dos', defaultSets: 4, defaultReps: 6),
  ExerciseCatalogEntry(name: 'Tirage horizontal poulie', muscleGroup: 'Dos', defaultSets: 4, defaultReps: 10),
  // Épaules
  ExerciseCatalogEntry(name: 'Développé militaire', muscleGroup: 'Épaules', defaultSets: 3, defaultReps: 10),
  ExerciseCatalogEntry(name: 'Élévations latérales', muscleGroup: 'Épaules', defaultSets: 3, defaultReps: 15),
  ExerciseCatalogEntry(name: 'Élévations frontales', muscleGroup: 'Épaules', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Face pull', muscleGroup: 'Épaules', defaultSets: 3, defaultReps: 15),
  ExerciseCatalogEntry(name: 'Oiseau (élévations arrière)', muscleGroup: 'Épaules', defaultSets: 3, defaultReps: 15),
  // Biceps
  ExerciseCatalogEntry(name: 'Curl biceps barre', muscleGroup: 'Biceps', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Curl marteau', muscleGroup: 'Biceps', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Curl incliné haltères', muscleGroup: 'Biceps', defaultSets: 3, defaultReps: 12),
  // Triceps
  ExerciseCatalogEntry(name: 'Dips (triceps)', muscleGroup: 'Triceps', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Extension triceps poulie', muscleGroup: 'Triceps', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Barre au front', muscleGroup: 'Triceps', defaultSets: 3, defaultReps: 12),
  // Quadriceps
  ExerciseCatalogEntry(name: 'Squat', muscleGroup: 'Quadriceps', defaultSets: 4, defaultReps: 8),
  ExerciseCatalogEntry(name: 'Presse à cuisses', muscleGroup: 'Quadriceps', defaultSets: 4, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Fentes', muscleGroup: 'Quadriceps', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Leg extension', muscleGroup: 'Quadriceps', defaultSets: 3, defaultReps: 15),
  ExerciseCatalogEntry(name: 'Squat bulgare', muscleGroup: 'Quadriceps', defaultSets: 3, defaultReps: 10),
  // Ischio-jambiers
  ExerciseCatalogEntry(name: 'Leg curl', muscleGroup: 'Ischio-jambiers', defaultSets: 3, defaultReps: 12),
  ExerciseCatalogEntry(name: 'Soulevé de terre jambes tendues', muscleGroup: 'Ischio-jambiers', defaultSets: 3, defaultReps: 10),
  ExerciseCatalogEntry(name: 'Hip thrust', muscleGroup: 'Ischio-jambiers', defaultSets: 3, defaultReps: 12),
  // Mollets
  ExerciseCatalogEntry(name: 'Mollets debout', muscleGroup: 'Mollets', defaultSets: 4, defaultReps: 15),
  ExerciseCatalogEntry(name: 'Mollets assis', muscleGroup: 'Mollets', defaultSets: 3, defaultReps: 15),
  // Abdominaux
  ExerciseCatalogEntry(name: 'Crunch', muscleGroup: 'Abdominaux', defaultSets: 3, defaultReps: 20),
  ExerciseCatalogEntry(name: 'Gainage (planche)', muscleGroup: 'Abdominaux', defaultSets: 3, defaultReps: 1),
  ExerciseCatalogEntry(name: 'Relevé de jambes', muscleGroup: 'Abdominaux', defaultSets: 3, defaultReps: 15),
];

const muscleGroups = <String>[
  'Pectoraux', 'Dos', 'Épaules', 'Biceps', 'Triceps', 'Quadriceps', 'Ischio-jambiers', 'Mollets', 'Abdominaux',
];
