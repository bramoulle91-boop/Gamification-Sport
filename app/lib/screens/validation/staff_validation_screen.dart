import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/gym_model.dart';
import '../../models/performance_model.dart';
import '../../services/providers.dart';

/// Réservé aux comptes "Staff" (gérant/coach) : file d'attente des performances
/// niveau 3 de leur(s) salle(s), à approuver ou rejeter.
class StaffValidationScreen extends ConsumerStatefulWidget {
  const StaffValidationScreen({super.key});

  @override
  ConsumerState<StaffValidationScreen> createState() => _StaffValidationScreenState();
}

class _StaffValidationScreenState extends ConsumerState<StaffValidationScreen> {
  List<GymModel> _gyms = [];
  List<PerformanceModel> _pending = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final gyms = await ref.read(staffServiceProvider).fetchMyStaffGyms();
      final pending = <PerformanceModel>[];
      for (final gym in gyms) {
        pending.addAll(await ref.read(performanceServiceProvider).fetchPendingLevel3ForStaff(gym.id));
      }
      setState(() {
        _gyms = gyms;
        _pending = pending;
      });
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(PerformanceModel performance, bool approve) async {
    await ref.read(performanceServiceProvider).staffValidate(
          performanceId: performance.id,
          approve: approve,
        );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validation staff')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _gyms.isEmpty
                  ? const Center(child: Text("Tu n'es rattaché à aucune salle en tant que staff."))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _pending.isEmpty
                          ? const Center(child: Text('Aucune performance en attente 🎉'))
                          : ListView.builder(
                              itemCount: _pending.length,
                              itemBuilder: (context, index) {
                                final performance = _pending[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text('${performance.weightKg}kg × ${performance.reps}'),
                                    subtitle: Text('Utilisateur : ${performance.userId}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green),
                                          onPressed: () => _decide(performance, true),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.red),
                                          onPressed: () => _decide(performance, false),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
    );
  }
}
