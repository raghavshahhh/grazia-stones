import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase client wrapper.
/// Replaces MockDataService and REST API layer.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;
  User? get currentUser => auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Initialize Supabase — call once in main()
  Future<void> init() async {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://jrrmjtbauimrrxwjvmzh.supabase.co',
    );
    const anonKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_l0K305hiCMwZ8Mh3lON3YQ_ueSMXo4a',
      ),
    );

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
      );
      debugPrint('✅ Supabase initialized');
    } else {
      debugPrint('⚠️ Supabase URL or key missing');
    }
  }

  // ─── Auth helpers ───

  /// Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    await auth.signInWithOtp(phone: phone);
  }

  /// Verify OTP
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    return await auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  /// Sign up with email
  Future<AuthResponse> signUp(String email, String password, {String? fullName}) async {
    return await auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  /// Sign in with email
  Future<AuthResponse> signIn(String email, String password) async {
    return await auth.signInWithPassword(email: email, password: password);
  }

  /// Sign out
  Future<void> signOut() async {
    await auth.signOut();
  }

  /// Get current user profile from profiles table
  Future<Map<String, dynamic>?> getProfile() async {
    if (!isLoggedIn) return null;
    final data = await client
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .maybeSingle();
    return data;
  }

  /// Update profile
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (!isLoggedIn) return;
    await client.from('profiles').upsert({
      'id': currentUser!.id,
      ...updates,
    });
  }

  // ─── Table query helpers ───

  /// Generic select with filters
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    dynamic query = client.from(table).select(select ?? '*');

    if (filters != null) {
      for (final entry in filters.entries) {
        if (entry.value is List) {
          query = query.inFilter(entry.key, entry.value);
        } else {
          query = query.eq(entry.key, entry.value);
        }
      }
    }

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    if (offset != null) {
      query = query.range(offset, offset + (limit ?? 50) - 1);
    }

    return await query;
  }

  /// Insert row(s)
  Future<List<Map<String, dynamic>>> insert(String table, Map<String, dynamic> data) async {
    return await client.from(table).insert(data).select();
  }

  /// Update row
  Future<List<Map<String, dynamic>>> update(
    String table, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> match,
  }) async {
    var builder = client.from(table).update(data);
    for (final entry in match.entries) {
      builder = builder.eq(entry.key, entry.value);
    }
    return await builder.select();
  }

  /// Delete row
  Future<void> delete(String table, {required Map<String, dynamic> match}) async {
    var builder = client.from(table).delete();
    for (final entry in match.entries) {
      builder = builder.eq(entry.key, entry.value);
    }
    await builder;
  }

  /// RPC call
  Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    return await client.rpc(fn, params: params);
  }
}
