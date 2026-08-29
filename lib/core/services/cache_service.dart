import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Multi-level cache service for Grazia Stones
/// Provides memory + disk caching with TTL and size limits
class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  CacheService._();

  // Memory cache (L1) - fast, small
  final Map<String, CacheEntry> _memoryCache = {};
  final int _maxMemoryEntries = 100;
  final Duration _memoryTTL = const Duration(minutes: 30);

  // Disk cache (L2) - persistent, larger
  late Directory _diskCacheDir;
  final int _maxDiskSizeMB = 200;
  final Duration _diskTTL = const Duration(days: 7);

  bool _initialized = false;

  /// Initialize cache service
  Future<void> init() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _diskCacheDir = Directory('${appDir.path}/cache');
      if (!await _diskCacheDir.exists()) {
        await _diskCacheDir.create(recursive: true);
      }
      
      // Clean expired entries on startup
      await _cleanExpiredDiskCache();
      
      _initialized = true;
      debugPrint('✅ Cache service initialized (memory: ${_maxMemoryEntries} entries, disk: ${_maxDiskSizeMB}MB)');
    } catch (e) {
      debugPrint('❌ Cache initialization failed: $e');
    }
  }

  /// Generate cache key from input
  String _generateKey(String namespace, String key) {
    final input = '$namespace:$key';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Get from memory cache
  CacheEntry? _getFromMemory(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    
    // Update access time for LRU
    entry.lastAccessed = DateTime.now();
    return entry;
  }

  /// Put in memory cache
  void _putInMemory(String key, dynamic value, Duration ttl) {
    // Evict oldest if at capacity
    if (_memoryCache.length >= _maxMemoryEntries) {
      _evictOldestMemory();
    }
    
    _memoryCache[key] = CacheEntry(
      key: key,
      value: value,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
      lastAccessed: DateTime.now(),
    );
  }

  /// Evict oldest entry from memory cache (LRU)
  void _evictOldestMemory() {
    if (_memoryCache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _memoryCache.entries) {
      if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime!)) {
        oldestTime = entry.value.lastAccessed;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _memoryCache.remove(oldestKey);
    }
  }

  /// Get from disk cache
  Future<CacheEntry?> _getFromDisk(String key) async {
    try {
      final file = File('${_diskCacheDir.path}/$key.cache');
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      final entry = CacheEntry.fromJson(data);
      if (entry.isExpired) {
        await file.delete();
        return null;
      }
      
      // Update access time
      entry.lastAccessed = DateTime.now();
      await file.writeAsString(jsonEncode(entry.toJson()));
      
      return entry;
    } catch (e) {
      debugPrint('Cache disk read error: $e');
      return null;
    }
  }

  /// Put in disk cache
  Future<void> _putInDisk(String key, dynamic value, Duration ttl) async {
    try {
      final entry = CacheEntry(
        key: key,
        value: value,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(ttl),
        lastAccessed: DateTime.now(),
      );
      
      final file = File('${_diskCacheDir.path}/$key.cache');
      await file.writeAsString(jsonEncode(entry.toJson()));
      
      // Check disk size limit
      await _enforceDiskSizeLimit();
    } catch (e) {
      debugPrint('Cache disk write error: $e');
    }
  }

  /// Enforce disk size limit
  Future<void> _enforceDiskSizeLimit() async {
    try {
      final files = _diskCacheDir.listSync().whereType<File>().toList();
      int totalSize = 0;
      final fileInfos = <_FileInfo>[];
      
      for (final file in files) {
        final stat = await file.stat();
        totalSize += stat.size;
        fileInfos.add(_FileInfo(file: file, size: stat.size, modified: stat.modified));
      }
      
      final maxBytes = _maxDiskSizeMB * 1024 * 1024;
      if (totalSize <= maxBytes) return;
      
      // Sort by modification time (oldest first)
      fileInfos.sort((a, b) => a.modified.compareTo(b.modified));
      
      // Delete oldest files until under limit
      for (final info in fileInfos) {
        if (totalSize <= maxBytes) break;
        await info.file.delete();
        totalSize -= info.size;
      }
    } catch (e) {
      debugPrint('Cache size enforcement error: $e');
    }
  }

  /// Clean expired entries from disk cache
  Future<void> _cleanExpiredDiskCache() async {
    try {
      final files = _diskCacheDir.listSync().whereType<File>().toList();
      
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final expiresAt = DateTime.parse(data['expiresAt'] as String);
          
          if (expiresAt.isBefore(DateTime.now())) {
            await file.delete();
          }
        } catch (e) {
          // Corrupted cache file, delete it
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Cache cleanup error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  /// Get cached value (checks memory first, then disk)
  Future<T?> get<T>(String namespace, String key) async {
    if (!_initialized) await init();
    
    final cacheKey = _generateKey(namespace, key);
    
    // L1: Memory cache
    final memEntry = _getFromMemory(cacheKey);
    if (memEntry != null) {
      debugPrint('💾 Cache HIT (memory): $namespace/$key');
      return memEntry.value as T;
    }
    
    // L2: Disk cache
    final diskEntry = await _getFromDisk(cacheKey);
    if (diskEntry != null) {
      debugPrint('💾 Cache HIT (disk): $namespace/$key');
      // Promote to memory
      _putInMemory(cacheKey, diskEntry.value, diskEntry.ttl);
      return diskEntry.value as T;
    }
    
    debugPrint('💾 Cache MISS: $namespace/$key');
    return null;
  }

  /// Put value in cache (both memory and disk)
  Future<void> set<T>(String namespace, String key, T value, {Duration? ttl}) async {
    if (!_initialized) await init();
    
    final cacheKey = _generateKey(namespace, key);
    final effectiveTtl = ttl ?? _memoryTTL;
    
    // Store in both caches
    _putInMemory(cacheKey, value, effectiveTtl);
    await _putInDisk(cacheKey, value, effectiveTtl);
    
    debugPrint('💾 Cache SET: $namespace/$key (TTL: ${effectiveTtl.inMinutes}min)');
  }

  /// Invalidate cache entry
  Future<void> invalidate(String namespace, String key) async {
    final cacheKey = _generateKey(namespace, key);
    
    _memoryCache.remove(cacheKey);
    
    try {
      final file = File('${_diskCacheDir.path}/$cacheKey.cache');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Cache invalidate error: $e');
    }
    
    debugPrint('💾 Cache INVALIDATE: $namespace/$key');
  }

  /// Invalidate all entries in a namespace
  Future<void> invalidateNamespace(String namespace) async {
    // Memory
    _memoryCache.removeWhere((key, _) => key.startsWith('${sha256.convert(utf8.encode(namespace))}'));
    
    // Disk
    try {
      final prefix = _generateKey(namespace, '');
      final files = _diskCacheDir.listSync().whereType<File>().toList();
      
      for (final file in files) {
        if (file.path.contains(prefix)) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Cache namespace invalidate error: $e');
    }
    
    debugPrint('💾 Cache INVALIDATE NAMESPACE: $namespace');
  }

  /// Clear all cache
  Future<void> clearAll() async {
    await clear();
  }

  /// Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    
    try {
      final files = _diskCacheDir.listSync().whereType<File>().toList();
      for (final file in files) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Cache clear error: $e');
    }
    
    debugPrint('💾 Cache CLEARED');
  }

  /// Get cache statistics
  Future<CacheStats> getStats() async {
    int memoryEntries = _memoryCache.length;
    int diskEntries = 0;
    int diskSizeBytes = 0;
    
    try {
      final files = _diskCacheDir.listSync().whereType<File>().toList();
      diskEntries = files.length;
      for (final file in files) {
        final stat = await file.stat();
        diskSizeBytes += stat.size;
      }
    } catch (e) {
      debugPrint('Cache stats error: $e');
    }
    
    return CacheStats(
      memoryEntries: memoryEntries,
      diskEntries: diskEntries,
      diskSizeMB: diskSizeBytes / (1024 * 1024),
    );
  }

  /// Preload textures for instant switching
  Future<void> preloadTextures(List<String> urls) async {
    for (final url in urls) {
      final key = _generateKey('texture', url);
      // Check if already cached
      if (_memoryCache.containsKey(key)) continue;
      
      try {
        // For asset images, load from bundle
        if (url.startsWith('assets/')) {
          final data = await rootBundle.load(url);
          final bytes = data.buffer.asUint8List();
          await set('texture', url, bytes, ttl: const Duration(days: 30));
        }
        // For network images, we'd need to download
        // This would be implemented with Dio
      } catch (e) {
        debugPrint('Texture preload error: $e');
      }
    }
  }
}

/// Cache entry with metadata
class CacheEntry {
  final String key;
  final dynamic value;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime lastAccessed;

  CacheEntry({
    required this.key,
    required this.value,
    required this.createdAt,
    required this.expiresAt,
    required this.lastAccessed,
  });

  Duration get ttl => expiresAt.difference(createdAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'lastAccessed': lastAccessed.toIso8601String(),
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    key: json['key'] as String,
    value: json['value'],
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    lastAccessed: DateTime.parse(json['lastAccessed'] as String),
  );
}

/// Cache statistics
class CacheStats {
  final int memoryEntries;
  final int diskEntries;
  final double diskSizeMB;

  const CacheStats({
    required this.memoryEntries,
    required this.diskEntries,
    required this.diskSizeMB,
  });

  @override
  String toString() => 'CacheStats(memory: $memoryEntries, disk: $diskEntries, size: ${diskSizeMB.toStringAsFixed(2)}MB)';
}

class _FileInfo {
  final File file;
  final int size;
  final DateTime modified;

  _FileInfo({required this.file, required this.size, required this.modified});
}