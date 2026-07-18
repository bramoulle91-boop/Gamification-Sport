import 'dart:convert';
import 'dart:js_util' as js_util;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Clé publique VAPID — sans risque à exposer côté client (c'est tout son
/// rôle), l'appariement se fait avec la clé privée détenue uniquement par
/// la fonction Supabase Edge `send-push`.
const _vapidPublicKey = 'BFsVNPPnaMmyRpD3DMv8b8l1PeVT-vY_VU72qRy33cxLqRvHJtUoC1hb1wpag1jKrWYo2oioKBj109v7bM2ABU0';

class PushService {
  final SupabaseClient _client = SupabaseService.client;

  bool get isSupported {
    final bridge = js_util.getProperty<Object?>(js_util.globalThis, 'gymquestPush');
    if (bridge == null) return false;
    return js_util.callMethod<bool>(bridge, 'isSupported', const []);
  }

  /// Demande la permission de notification au navigateur, s'abonne au push,
  /// et enregistre l'abonnement pour l'utilisateur courant.
  Future<void> enable() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour activer les notifications.');
    }
    final bridge = js_util.getProperty<Object?>(js_util.globalThis, 'gymquestPush');
    if (bridge == null) {
      throw Exception('Notifications non disponibles sur cet appareil.');
    }
    final promise = js_util.callMethod<Object>(bridge, 'subscribe', [_vapidPublicKey]);
    final subJsonString = await js_util.promiseToFuture<String>(promise);
    final sub = jsonDecode(subJsonString) as Map<String, dynamic>;
    final keys = sub['keys'] as Map<String, dynamic>;

    await _client.from('push_subscriptions').upsert({
      'user_id': userId,
      'endpoint': sub['endpoint'] as String,
      'p256dh': keys['p256dh'] as String,
      'auth_key': keys['auth'] as String,
    }, onConflict: 'endpoint');
  }
}
