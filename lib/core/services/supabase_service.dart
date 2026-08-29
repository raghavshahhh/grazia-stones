import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/retry.dart';

/// Central Supabase client wrapper with retry logic and error handling.
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
      
      // Test connection
      await _testConnection();
    } else {
      debugPrint('⚠️ Supabase URL or key missing');
    }
  }

  Future<void> _testConnection() async {
    try {
      await client.from('collections').select('id').limit(1).timeout(const Duration(seconds: 5));
      debugPrint('✅ Supabase connection verified');
    } catch (e) {
      debugPrint('⚠️ Supabase connection test failed: $e');
    }
  }

  /// Normalize phone number to E.164 format (+91XXXXXXXXXX)
  static String normalizePhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+91+91')) {
      cleaned = '+91${cleaned.substring(6)}';
    }
    if (!cleaned.startsWith('+')) {
      if (cleaned.startsWith('91') && cleaned.length == 12) {
        cleaned = '+$cleaned';
      } else if (cleaned.startsWith('0')) {
        cleaned = '+91${cleaned.substring(1)}';
      } else {
        cleaned = '+91$cleaned';
      }
    }
    return cleaned;
  }

  // ─── Auth helpers with retry ───

  /// Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    final normalized = normalizePhoneNumber(phone);
    await _withAuthRetry(() => auth.signInWithOtp(phone: normalized));
  }

  /// Verify OTP
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    final normalized = normalizePhoneNumber(phone);
    return await _withAuthRetry(() => auth.verifyOTP(phone: normalized, token: token, type: OtpType.sms));
  }

  /// Sign up with email
  Future<AuthResponse> signUp(String email, String password, {String? fullName}) async {
    return await _withAuthRetry(() => auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    ));
  }

  /// Sign in with email
  Future<AuthResponse> signIn(String email, String password) async {
    return await _withAuthRetry(() => auth.signInWithPassword(email: email, password: password));
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return await _withAuthRetryBool(() => auth.signInWithOAuth(provider));
  }

  /// Sign out
  Future<void> signOut() async {
    await _withAuthRetryVoid(() => auth.signOut());
  }

  /// Delete account
  Future<void> deleteAccount() async {
    await auth.admin.deleteUser(currentUser!.id);
  }

  /// Get current user profile from profiles table
  Future<Map<String, dynamic>?> getProfile() async {
    if (!isLoggedIn) return null;
    return await _withRetry(() async {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();
      return data;
    });
  }

  /// Update profile
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (!isLoggedIn) return;
    await _withRetry(() async {
      await client.from('profiles').upsert({
        'id': currentUser!.id,
        ...updates,
      });
    });
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _withAuthRetry(() => auth.resetPasswordForEmail(email));
  }

  /// Update password (when logged in)
  Future<void> updatePassword(String newPassword) async {
    await _withAuthRetry(() => auth.updateUser(UserAttributes(password: newPassword)));
  }

  // ─── Generic retry wrapper ───

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    return withRetry<T>(
      operation: operation,
      config: RetryConfig.database,
      onRetry: (error, attempt) {
        debugPrint('[SupabaseService] Retry attempt ${attempt + 1}: $error');
      },
    );
  }

  Future<T> _withAuthRetry<T>(Future<T> Function() operation) async {
    return withRetry<T>(
      operation: operation,
      config: RetryConfig(maxAttempts: 2, baseDelay: Duration(seconds: 1)),
      onRetry: (error, attempt) {
        debugPrint('[SupabaseAuth] Retry attempt ${attempt + 1}: $error');
      },
    );
  }

  Future<void> _withAuthRetryVoid(Future<void> Function() operation) async {
    return withRetry<void>(
      operation: operation,
      config: RetryConfig(maxAttempts: 2, baseDelay: Duration(seconds: 1)),
      onRetry: (error, attempt) {
        debugPrint('[SupabaseAuth] Retry attempt ${attempt + 1}: $error');
      },
    );
  }

  Future<bool> _withAuthRetryBool(Future<bool> Function() operation) async {
    return withRetry<bool>(
      operation: operation,
      config: RetryConfig(maxAttempts: 2, baseDelay: Duration(seconds: 1)),
      onRetry: (error, attempt) {
        debugPrint('[SupabaseAuth] Retry attempt ${attempt + 1}: $error');
      },
    );
  }

  // ─── Table query helpers with retry ───

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
    return await _withRetry(() async {
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
    });
  }

  /// Insert row(s)
  Future<List<Map<String, dynamic>>> insert(String table, Map<String, dynamic> data) async {
    return await _withRetry(() async {
      return await client.from(table).insert(data).select();
    });
  }

  /// Update row
  Future<List<Map<String, dynamic>>> update(
    String table, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> match,
  }) async {
    return await _withRetry(() async {
      var builder = client.from(table).update(data);
      for (final entry in match.entries) {
        builder = builder.eq(entry.key, entry.value);
      }
      return await builder.select();
    });
  }

  /// Delete row
  Future<void> delete(String table, {required Map<String, dynamic> match}) async {
    await _withRetry(() async {
      var builder = client.from(table).delete();
      for (final entry in match.entries) {
        builder = builder.eq(entry.key, entry.value);
      }
      await builder;
    });
  }

  /// RPC call
  Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    return await _withRetry(() async {
      return await client.rpc(fn, params: params);
    });
  }

  /// Subscribe to realtime changes
  RealtimeChannel subscribe(
    String table, {
    required void Function(List<Map<String, dynamic>>) onChanges,
    String? filterColumn,
    String? filterValue,
  }) {
    var channel = client.channel('public:$table');
    
    if (filterColumn != null && filterValue != null) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: filterColumn,
          value: filterValue,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          onChanges([if (newRecord.isNotEmpty) newRecord, if (oldRecord.isNotEmpty) oldRecord]);
        },
      );
    } else {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          onChanges([if (newRecord.isNotEmpty) newRecord, if (oldRecord.isNotEmpty) oldRecord]);
        },
      );
    }
    
    channel.subscribe();
    return channel;
  }
}