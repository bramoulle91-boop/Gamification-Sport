# GymQuest

GymQuest est une application de gamification de la pratique sportive en salle : les utilisateurs valident leurs performances sur les machines, gagnent des points, grimpent dans des ligues et défient leurs amis.

Ce dépôt contient la documentation d'architecture du produit ainsi que le schéma de base de données de référence (Supabase/PostgreSQL).

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) : système de validation progressif des performances, modèle de données conceptuel, et plan de déploiement terrain.
- [`supabase/schema.sql`](supabase/schema.sql) : script SQL créant les tables du modèle de données (`Users`, `Gyms`, `Machines`, `Friendships`, `Performances`).

## Stack technique envisagée

- **Application mobile** : FlutterFlow (no-code)
- **Backend / base de données** : Supabase (PostgreSQL)
