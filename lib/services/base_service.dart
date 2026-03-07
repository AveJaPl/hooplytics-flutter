import 'package:supabase_flutter/supabase_flutter.dart';

/// Base class for all Supabase-backed services.
/// Extend this to create new services (e.g. SessionService, StatsService).
abstract class BaseService {
  SupabaseClient get client => Supabase.instance.client;
}
