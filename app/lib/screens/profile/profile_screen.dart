import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/providers.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/league_badge.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _enablingPush = false;

  Future<void> _enablePush() async {
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour activer les notifications.')),
      );
      return;
    }
    final push = ref.read(pushServiceProvider);
    if (!push.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications non supportées sur cet appareil/navigateur.')),
      );
      return;
    }
    setState(() => _enablingPush = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await push.enable();
      messenger.showSnackBar(const SnackBar(content: Text('Notifications activées 🔔')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _enablingPush = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final isLoggedIn = ref.watch(currentUserIdProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (profile) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isLoggedIn) ...[
                const DemoModeBanner(),
                const SizedBox(height: 16),
              ],
              CircleAvatar(radius: 40, child: Text(profile.pseudo.substring(0, 1).toUpperCase())),
              const SizedBox(height: 12),
              Center(child: Text(profile.pseudo, style: Theme.of(context).textTheme.titleLarge)),
              Center(child: Text(profile.email)),
              const SizedBox(height: 12),
              Center(child: LeagueBadge(leagueLevel: profile.leagueLevel)),
              const SizedBox(height: 24),
              ListTile(
                leading: _enablingPush
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                title: const Text('Activer les notifications'),
                subtitle: const Text('Nouveaux messages, défis, résultats — même appli fermée'),
                onTap: _enablingPush ? null : _enablePush,
              ),
              ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('Espace staff'),
                subtitle: const Text('Valider les performances niveau 3 de ta salle'),
                onTap: () => context.push('/validation/staff'),
              ),
              ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('Tribunal des Pairs'),
                subtitle: const Text('Voter sur les vidéos de la communauté'),
                onTap: () => context.push('/validation/jury'),
              ),
              const Divider(height: 32),
              if (isLoggedIn)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Se déconnecter'),
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Se connecter'),
                  subtitle: const Text('Pour sauvegarder tes vraies données'),
                  onTap: () => context.push('/login'),
                ),
            ],
          );
        },
      ),
    );
  }
}
