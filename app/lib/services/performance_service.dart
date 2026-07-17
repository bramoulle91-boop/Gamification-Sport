import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/performance_model.dart';
import 'geolocation_service.dart';
import 'supabase_service.dart';

/// Orchestration des trois niveaux de validation (voir docs/ARCHITECTURE.md, section V).
class PerformanceService {
  PerformanceService({GeolocationService? geolocationService})
      : _geolocation = geolocationService ?? GeolocationService();

  final SupabaseClient _client = SupabaseService.client;
  final GeolocationService _geolocation;
  final _uuid = const Uuid();

  /// Niveau 1 — routine : géolocalisation + cohérence temporelle, tout est
  /// vérifié côté serveur (RPC `log_performance_level1`) pour éviter la triche client.
  Future<PerformanceModel> logLevel1({
    required String machineId,
    required double weightKg,
    required int reps,
  }) async {
    final position = await _geolocation.getCurrentPosition();
    final row = await _client.rpc('log_performance_level1', params: {
      'p_machine_id': machineId,
      'p_weight_kg': weightKg,
      'p_reps': reps,
      'p_user_lat': position.latitude,
      'p_user_lon': position.longitude,
    });
    return PerformanceModel.fromMap(row as Map<String, dynamic>);
  }

  /// Niveau 2 — preuve photo : upload dans le bucket privé `proof-media`
  /// (fichier éphémère, purgé côté serveur après 24h) puis enregistrement.
  Future<PerformanceModel> logLevel2WithPhoto({
    required String machineId,
    required double weightKg,
    required int reps,
    required File photoFile,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final path = '$userId/${_uuid.v4()}.jpg';
    await _client.storage.from('proof-media').upload(path, photoFile);

    final row = await _client.rpc('log_performance_level2_photo', params: {
      'p_machine_id': machineId,
      'p_weight_kg': weightKg,
      'p_reps': reps,
      'p_proof_photo_path': path,
    });
    return PerformanceModel.fromMap(row as Map<String, dynamic>);
  }

  /// Niveau 2 — variante QR ami : crée la performance en attente avant de
  /// générer le QR temporaire que l'ami va scanner.
  Future<PerformanceModel> createPendingLevel2({
    required String machineId,
    required double weightKg,
    required int reps,
  }) async {
    final row = await _client.rpc('log_performance_level2_pending', params: {
      'p_machine_id': machineId,
      'p_weight_kg': weightKg,
      'p_reps': reps,
    });
    return PerformanceModel.fromMap(row as Map<String, dynamic>);
  }

  /// Niveau 2 — validation croisée par un ami : génère le QR temporaire (2 min).
  Future<Map<String, dynamic>> requestFriendValidationToken(String performanceId) async {
    final row = await _client.rpc('request_friend_validation_token', params: {
      'p_performance_id': performanceId,
    });
    return row as Map<String, dynamic>;
  }

  /// Niveau 2 — l'ami scanne le QR de son côté : le token est consommé côté serveur.
  Future<PerformanceModel> redeemFriendValidationToken(String token) async {
    final row = await _client.rpc('redeem_friend_validation_token', params: {
      'p_token': token,
    });
    return PerformanceModel.fromMap(row as Map<String, dynamic>);
  }

  /// Niveau 3 — soumission pour validation staff, ou pour le Tribunal des Pairs
  /// si une vidéo de preuve est fournie.
  Future<PerformanceModel> logLevel3({
    required String machineId,
    required double weightKg,
    required int reps,
    File? proofVideoFile,
  }) async {
    String? videoPath;
    if (proofVideoFile != null) {
      final userId = _client.auth.currentUser!.id;
      videoPath = '$userId/${_uuid.v4()}.mp4';
      await _client.storage.from('proof-media').upload(videoPath, proofVideoFile);
    }

    final row = await _client.rpc('log_performance_level3', params: {
      'p_machine_id': machineId,
      'p_weight_kg': weightKg,
      'p_reps': reps,
      'p_proof_video_path': videoPath,
    });
    return PerformanceModel.fromMap(row as Map<String, dynamic>);
  }

  Future<PerformanceModel> staffValidate({
    required String performanceId,
    required bool approve,
  }) async {
    final row = await _client.rpc('staff_validate_performance', params: {
      'p_performance_id': performanceId,
      'p_approve': approve,
    });
    return PerformanceModel.fromMap(row as Map<String, dynamic>);
  }

  Future<void> castPeerJuryVote({
    required String performanceId,
    required bool approve,
  }) async {
    await _client.from('peer_jury_votes').insert({
      'performance_id': performanceId,
      'voter_id': _client.auth.currentUser!.id,
      'approve': approve,
    });
  }

  /// URL signée temporaire pour lire une photo/vidéo de preuve stockée dans le
  /// bucket privé `proof-media`.
  Future<String> getSignedProofUrl(String path, {int expiresInSeconds = 300}) {
    return _client.storage.from('proof-media').createSignedUrl(path, expiresInSeconds);
  }

  Future<List<PerformanceModel>> fetchPendingLevel3ForJury() async {
    final rows = await _client
        .from('performances')
        .select()
        .eq('validation_level', '3')
        .eq('validation_status', 'PENDING')
        .not('proof_video_path', 'is', null)
        .order('performed_at');
    return (rows as List<dynamic>)
        .map((e) => PerformanceModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Le meilleur poids déjà validé par l'utilisateur courant sur cette
  /// machine, ou `null` s'il n'a encore rien validé dessus. Sert à détecter
  /// les records personnels — l'idée étant que se dépasser soi-même compte
  /// autant que de viser la meilleure performance absolue de la salle.
  Future<double?> fetchPersonalBest(String machineId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _client
        .from('performances')
        .select('weight_kg')
        .eq('user_id', userId)
        .eq('machine_id', machineId)
        .eq('validation_status', 'VALIDATED')
        .order('weight_kg', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return ((list.first as Map<String, dynamic>)['weight_kg'] as num).toDouble();
  }

  Future<List<PerformanceModel>> fetchPendingLevel3ForStaff(String gymId) async {
    final rows = await _client
        .from('performances')
        .select('*, machines!inner(gym_id)')
        .eq('validation_level', '3')
        .eq('validation_status', 'PENDING')
        .eq('machines.gym_id', gymId)
        .order('performed_at');
    return (rows as List<dynamic>)
        .map((e) => PerformanceModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
