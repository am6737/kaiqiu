// favorites_repository.dart — 统一收藏（pickup / event / user）
import '../services/local_storage.dart';
import '../services/supabase.dart';

enum FavoriteEntity { pickup, event, user }

extension FavoriteEntityX on FavoriteEntity {
  String get value {
    switch (this) {
      case FavoriteEntity.pickup:
        return 'pickup';
      case FavoriteEntity.event:
        return 'event';
      case FavoriteEntity.user:
        return 'user';
    }
  }
}

class FavoritesRepository {
  /// Toggle a favorite; returns the new state (true = favorited).
  Future<bool> toggle(FavoriteEntity type, String entityId) async {
    final already = await isFavorited(type, entityId);
    if (already) {
      await _remove(type, entityId);
      return false;
    }
    await _add(type, entityId);
    return true;
  }

  Future<void> _add(FavoriteEntity type, String entityId) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        await supabase.from('favorites').insert({
          'user_id': uid,
          'entity_type': type.value,
          'entity_id': entityId,
        });
      } catch (_) {
        // fall through
      }
    }
    // Mirror to LocalStore per entity type
    switch (type) {
      case FavoriteEntity.pickup:
        if (!LocalStore.isPickupFavorited(entityId)) {
          await LocalStore.toggleFavoritePickup(entityId);
        }
        break;
      case FavoriteEntity.event:
        if (!LocalStore.isEventFavorited(entityId)) {
          await LocalStore.toggleFavoriteEvent(entityId);
        }
        break;
      case FavoriteEntity.user:
        if (!LocalStore.isFollowing(entityId)) {
          await LocalStore.toggleFollowUser(entityId);
        }
        break;
    }
  }

  Future<void> _remove(FavoriteEntity type, String entityId) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', uid)
            .eq('entity_type', type.value)
            .eq('entity_id', entityId);
      } catch (_) {
        // fall through
      }
    }
    switch (type) {
      case FavoriteEntity.pickup:
        if (LocalStore.isPickupFavorited(entityId)) {
          await LocalStore.toggleFavoritePickup(entityId);
        }
        break;
      case FavoriteEntity.event:
        if (LocalStore.isEventFavorited(entityId)) {
          await LocalStore.toggleFavoriteEvent(entityId);
        }
        break;
      case FavoriteEntity.user:
        if (LocalStore.isFollowing(entityId)) {
          await LocalStore.toggleFollowUser(entityId);
        }
        break;
    }
  }

  Future<bool> isFavorited(FavoriteEntity type, String entityId) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        final row = await supabase
            .from('favorites')
            .select('id')
            .eq('user_id', uid)
            .eq('entity_type', type.value)
            .eq('entity_id', entityId)
            .maybeSingle();
        if (row != null) return true;
      } catch (_) {
        // fall through
      }
    }
    switch (type) {
      case FavoriteEntity.pickup:
        return LocalStore.isPickupFavorited(entityId);
      case FavoriteEntity.event:
        return LocalStore.isEventFavorited(entityId);
      case FavoriteEntity.user:
        return LocalStore.isFollowing(entityId);
    }
  }

  /// List favorited entity ids for the given type.
  Future<List<String>> list(FavoriteEntity type) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        final rows = await supabase
            .from('favorites')
            .select('entity_id')
            .eq('user_id', uid)
            .eq('entity_type', type.value)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((r) => (r as Map)['entity_id'] as String?)
            .whereType<String>()
            .toList();
      } catch (_) {
        // fall through
      }
    }
    switch (type) {
      case FavoriteEntity.pickup:
        return LocalStore.favoritePickups.toList();
      case FavoriteEntity.event:
        return LocalStore.favoriteEvents.toList();
      case FavoriteEntity.user:
        return LocalStore.followedUsers.toList();
    }
  }

  /// One-shot sync: pull all favorites from Supabase into LocalStore cache.
  /// Call after login so that anonymous-era local state and server state
  /// converge.
  Future<void> syncFromServer() async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final rows = await supabase.from('favorites').select().eq('user_id', uid);
      final map = <String, Set<String>>{
        'pickup': <String>{},
        'event': <String>{},
        'user': <String>{},
      };
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final t = r['entity_type'] as String?;
        final id = r['entity_id'] as String?;
        if (t == null || id == null) continue;
        map[t]?.add(id);
      }
      // Reconcile pickup favorites
      for (final id in map['pickup']!) {
        if (!LocalStore.isPickupFavorited(id)) {
          await LocalStore.toggleFavoritePickup(id);
        }
      }
      for (final id in map['event']!) {
        if (!LocalStore.isEventFavorited(id)) {
          await LocalStore.toggleFavoriteEvent(id);
        }
      }
      for (final id in map['user']!) {
        if (!LocalStore.isFollowing(id)) {
          await LocalStore.toggleFollowUser(id);
        }
      }
    } catch (_) {
      // ignore; LocalStore remains last-known-good
    }
  }
}
