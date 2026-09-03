import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Real notification rows from the `notifications` table.
///
/// - Users see only their own rows (RLS: auth.uid() = user_id).
/// - Guests see an honest empty list — never fabricated content.
/// - Creating an order/quote/sample should insert a notification row
///   so the user gets genuine feedback in the bell sheet.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // info | success | warning | error | order | quote | sample
  final bool read;
  final String? actionUrl;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.actionUrl,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? 'info',
        read: (json['read'] as bool?) ?? false,
        actionUrl: json['action_url'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class NotificationRepository {
  final _client = SupabaseService.instance.client;

  String? get _userId => SupabaseService.instance.currentUser?.id;

  /// Newest-first notifications for the current user. Guests → empty.
  Future<List<AppNotification>> getNotifications({int limit = 30}) async {
    final uid = _userId;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((j) => AppNotification.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      debugPrint('❌ NotificationRepository.getNotifications: $e');
      rethrow;
    }
  }

  /// Unread count for the bell badge. Guests/errors → 0 (never fake).
  Future<int> getUnreadCount() async {
    final uid = _userId;
    if (uid == null) return 0;
    try {
      final data = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('read', false);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Mark one notification read (RLS: own rows only).
  Future<void> markRead(String notificationId) async {
    final uid = _userId;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId)
        .eq('user_id', uid);
  }

  /// Mark all the user's notifications read.
  Future<void> markAllRead() async {
    final uid = _userId;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', uid)
        .eq('read', false);
  }

  /// Insert a real notification (used after order/quote/sample creation).
  /// RLS allows system inserts ("System can create notifications": true).
  Future<void> create({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
    String? actionUrl,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'action_url': actionUrl,
    });
  }
}

final notificationRepositoryProvider = NotificationRepository();
