# GymQuest — Architecture

## V. Système de validation progressif

La fiabilité d'une performance déclarée dépend de son enjeu. GymQuest applique donc un niveau de preuve croissant, pour rester fluide sur l'usage courant tout en restant fiable sur les usages sensibles (classements, récompenses).

### 🟢 Niveau 1 — Routine (≈ 90 % des cas)

Validation automatique via :
- la géolocalisation de l'appareil (confirmation de présence dans la salle) ;
- un algorithme de cohérence temporelle (il est par exemple impossible de valider 5 machines différentes en 2 minutes).

Aucune action manuelle n'est demandée à l'utilisateur : c'est le mode par défaut pour l'usage quotidien.

### 🟡 Niveau 2 — Records & Duels

Nécessite une preuve renforcée, au choix :
- une **photo éphémère** de la goupille de poids, prise uniquement via l'appareil photo sécurisé intégré à l'application (pas d'import depuis la galerie) ;
- ou la **validation croisée** par un ami : scan d'un QR code temporaire, l'ami devant être géolocalisé à proximité immédiate.

### 🔴 Niveau 3 — Gros enjeux / Cadeaux physiques

Validation manuelle, réservée aux situations à forte valeur (récompenses physiques, classements majeurs) :
- validation par le **staff de la salle** via un compte dédié "Staff" (gérant / coach) ;
- ou **vote asynchrone de la communauté** ("Tribunal des Pairs") sur une courte vidéo de l'exécution du mouvement.

## VI. Structure de la base de données (modèle conceptuel)

Architecture cible : FlutterFlow (front mobile no-code) + Supabase (backend/BDD Postgres).

| Table | Champs principaux |
|---|---|
| `Users` | ID, Pseudo, Vrai Nom (optionnel), Email, Niveau de Ligue, Points Cumulés, Historique des Streaks |
| `Gyms` | ID, Nom, Coordonnées GPS, Périmètre de Geofencing, Taux d'affluence en direct |
| `Machines` | ID, Nom de la machine, Muscle ciblé, Gym_ID (salle liée), QR_Code_Hash |
| `Friendships` | User_ID_1, User_ID_2, Status (PENDING / DEBLOCKED), Date de connexion |
| `Performances` | ID, User_ID, Machine_ID, Poids (kg), Reps, Timestamp, Niveau de validation (1, 2, 3), Statut de validation |

Voir le script SQL de référence : [`supabase/schema.sql`](../supabase/schema.sql).

## VII. Plan de déploiement & validation terrain

Stratégie en trois étapes, pensée pour un lancement à coût et risque quasi nuls.

### 1. Le Prétotype Papier (semaines 1-4)

Validation du concept d'animation de salle dans un seul club local :
- impression de 4 QR codes collés sur des machines, renvoyant vers un formulaire gratuit (Tally / Google Forms) ;
- envoi hebdomadaire d'un classement de régularité par e-mail ou WhatsApp.

### 2. Le MVP No-Code (semaines 5-12)

Développement de l'application mobile de base sur FlutterFlow connectée à Supabase, puis bêta-test fermée avec les 30 premiers utilisateurs de la salle pilote.

### 3. Le Lancement Commercial (mois 4+)

Proposition de l'outil SaaS d'animation clé en main aux gérants de salles indépendantes ou franchisées, puis intégration des premières marques partenaires pour la boutique de récompenses.
