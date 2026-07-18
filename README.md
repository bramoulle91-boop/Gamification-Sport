# GymQuest

GymQuest est une application de gamification de la pratique sportive en salle : les utilisateurs valident leurs performances sur les machines, gagnent des points, grimpent dans des ligues et défient leurs amis.

Ce dépôt contient la documentation d'architecture du produit ainsi que le schéma de base de données de référence (Supabase/PostgreSQL).

## Contenu du dépôt

- [`app/`](app) : application mobile Flutter (auth, scan de machine, les 3 niveaux de validation, classement, amis, boutique de récompenses). Voir [`app/README.md`](app/README.md) pour l'installation.
- [`supabase/migrations/`](supabase/migrations) : schéma Supabase/PostgreSQL (tables, RLS, fonctions RPC de validation).
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) : système de validation progressif, modèle de données conceptuel, plan de déploiement terrain.

## Stack technique

- **Application mobile** : Flutter
- **Backend / base de données** : Supabase (PostgreSQL, Auth, Storage)
