import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'storage_exceptions.dart';

/// Injected custom resolver function type for testing or dependency injection.
typedef CustomPathResolver = FutureOr<String?> Function();

/// Injected application support directory provider for path_provider mocking.
typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();

/// Resolves native application persistent storage directory across platforms.
///
/// Resolution precedence:
/// 1. Priority 1: Injected custom resolver function.
/// 2. Priority 2: Explicit LUMIVO_STORAGE_DIR environment variable.
/// 3. Priority 3: Platform native app-support directory:
///    - Desktop (Windows/macOS/Linux): environment variables or path_provider.
///    - Mobile (Android/iOS): getApplicationSupportDirectory() via path_provider.
///    - If unresolvable or plugin throws: throws [StoragePathException].
///      Never silently falls back to RAM, current working directory, or temp!
abstract final class PlatformStorageResolver {
  static CustomPathResolver? _customResolver;
  static Map<String, String>? _environmentOverride;
  static ApplicationSupportDirectoryProvider? _appSupportDirProvider;
  static TargetPlatform? _platformOverride;
  static String? _cachedResolvedPath;

  /// Injects a custom storage path resolver (Priority 1).
  static void setCustomResolver(CustomPathResolver? resolver) {
    _customResolver = resolver;
  }

  /// Sets an environment variables map override (primarily for tests).
  static void setEnvironmentOverride(Map<String, String>? environment) {
    _environmentOverride = environment;
  }

  /// Injects a custom application support directory provider (for testing mobile/desktop path_provider).
  static void setApplicationSupportDirectoryProvider(
    ApplicationSupportDirectoryProvider? provider,
  ) {
    _appSupportDirProvider = provider;
  }

  /// Overrides the target platform (primarily for tests).
  static void setPlatformOverride(TargetPlatform? platform) {
    _platformOverride = platform;
  }

  /// Resets all injected test hooks and cached paths.
  static void reset() {
    _customResolver = null;
    _environmentOverride = null;
    _appSupportDirProvider = null;
    _platformOverride = null;
    _cachedResolvedPath = null;
  }

  /// Returns the cached resolved path, if resolved previously.
  static String? get cachedResolvedPath => _cachedResolvedPath;

  static TargetPlatform _detectPlatform(TargetPlatform? override) {
    if (override != null) return override;
    if (_platformOverride != null) return _platformOverride!;
    if (kIsWeb) {
      throw const StoragePathException(
        'PlatformStorageResolver is not supported on Web. Use WebStorageAdapter.',
      );
    }
    if (Platform.isWindows) return TargetPlatform.windows;
    if (Platform.isMacOS) return TargetPlatform.macOS;
    if (Platform.isLinux) return TargetPlatform.linux;
    if (Platform.isAndroid) return TargetPlatform.android;
    if (Platform.isIOS) return TargetPlatform.iOS;
    if (Platform.isFuchsia) return TargetPlatform.fuchsia;
    return defaultTargetPlatform;
  }

  /// Asynchronously resolves the platform storage path according to strict priority rules.
  static Future<String> resolve({
    CustomPathResolver? customResolver,
    Map<String, String>? environment,
    TargetPlatform? platformOverride,
    ApplicationSupportDirectoryProvider? appSupportDirProvider,
  }) async {
    // Priority 1: Injected custom resolver
    final resolver = customResolver ?? _customResolver;
    if (resolver != null) {
      try {
        final customPath = await resolver();
        if (customPath != null && customPath.trim().isNotEmpty) {
          final trimmed = customPath.trim();
          _cachedResolvedPath = trimmed;
          return trimmed;
        }
      } catch (e) {
        if (e is StoragePathException) rethrow;
        throw StoragePathException(
          'Failed to resolve custom storage path: $e',
          e,
        );
      }
    }

    // Priority 2: Explicit LUMIVO_STORAGE_DIR environment variable
    final env = environment ?? _environmentOverride ?? Platform.environment;
    final lumivoStorageDir = env['LUMIVO_STORAGE_DIR'];
    if (lumivoStorageDir != null && lumivoStorageDir.trim().isNotEmpty) {
      final trimmed = lumivoStorageDir.trim();
      _cachedResolvedPath = trimmed;
      return trimmed;
    }

    // Priority 3: Platform native app-support directory
    final platform = _detectPlatform(platformOverride);

    if (platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux) {
      // Check desktop environment variables first
      final desktopEnvPath = _resolveDesktopEnvPath(platform, env);
      if (desktopEnvPath != null) {
        _cachedResolvedPath = desktopEnvPath;
        return desktopEnvPath;
      }

      // If env vars are absent on desktop, fallback to path_provider
      final resolved = await _resolveFromPathProvider(
        provider: appSupportDirProvider ?? _appSupportDirProvider,
      );
      _cachedResolvedPath = resolved;
      return resolved;
    } else if (platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS) {
      // Mobile: must call getApplicationSupportDirectory() via path_provider
      final resolved = await _resolveFromPathProvider(
        provider: appSupportDirProvider ?? _appSupportDirProvider,
      );
      _cachedResolvedPath = resolved;
      return resolved;
    }

    throw StoragePathException(
      'Failed to resolve platform storage directory: unsupported platform $platform',
    );
  }

  static String? _resolveDesktopEnvPath(
    TargetPlatform platform,
    Map<String, String> env,
  ) {
    if (platform == TargetPlatform.windows) {
      final appData = env['APPDATA'] ?? env['LOCALAPPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return '${appData.trim()}/Lumivo/storage';
      }
    } else if (platform == TargetPlatform.macOS) {
      final home = env['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        return '${home.trim()}/Library/Application Support/Lumivo/storage';
      }
    } else if (platform == TargetPlatform.linux) {
      final xdg = env['XDG_DATA_HOME'];
      if (xdg != null && xdg.trim().isNotEmpty) {
        return '${xdg.trim()}/lumivo/storage';
      }
      final home = env['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        return '${home.trim()}/.local/share/lumivo/storage';
      }
    }
    return null;
  }

  static Future<String> _resolveFromPathProvider({
    ApplicationSupportDirectoryProvider? provider,
  }) async {
    final dirProvider = provider ?? getApplicationSupportDirectory;
    Directory dir;
    try {
      dir = await dirProvider();
    } catch (e) {
      if (e is StoragePathException) rethrow;
      throw StoragePathException(
        'Failed to resolve application support directory via path_provider: $e',
        e,
      );
    }

    final rawPath = dir.path.trim();
    if (rawPath.isEmpty) {
      throw const StoragePathException(
        'Failed to resolve application support directory: path_provider returned empty path',
      );
    }

    final normalized = rawPath.replaceAll(r'\', '/');
    if (normalized.endsWith('/storage')) {
      return normalized;
    }
    return '$normalized/storage';
  }

  /// Synchronously attempts to resolve storage path (Priority 1 if sync, Priority 2, or Desktop env).
  /// Returns null if asynchronous resolution (e.g. mobile path_provider) is required.
  static String? resolveSync({
    CustomPathResolver? customResolver,
    Map<String, String>? environment,
    TargetPlatform? platformOverride,
  }) {
    // Priority 1: Synchronous custom resolver
    final resolver = customResolver ?? _customResolver;
    if (resolver != null) {
      try {
        final result = resolver();
        if (result is String && result.trim().isNotEmpty) {
          final trimmed = result.trim();
          _cachedResolvedPath = trimmed;
          return trimmed;
        }
      } catch (e) {
        if (e is StoragePathException) rethrow;
        throw StoragePathException(
          'Failed to resolve custom storage path synchronously: $e',
          e,
        );
      }
    }

    // Priority 2: LUMIVO_STORAGE_DIR
    final env = environment ?? _environmentOverride ?? Platform.environment;
    final lumivoStorageDir = env['LUMIVO_STORAGE_DIR'];
    if (lumivoStorageDir != null && lumivoStorageDir.trim().isNotEmpty) {
      final trimmed = lumivoStorageDir.trim();
      _cachedResolvedPath = trimmed;
      return trimmed;
    }

    // Priority 3: Desktop environment variables
    final platform = _detectPlatform(platformOverride);
    final desktopEnvPath = _resolveDesktopEnvPath(platform, env);
    if (desktopEnvPath != null) {
      _cachedResolvedPath = desktopEnvPath;
      return desktopEnvPath;
    }

    if (_cachedResolvedPath != null) {
      return _cachedResolvedPath;
    }

    return null;
  }
}
