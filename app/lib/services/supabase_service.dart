import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Point d'accès unique au client Supabase, initialisé au démarrage de l'app.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }
}
