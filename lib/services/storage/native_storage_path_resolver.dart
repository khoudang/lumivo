/// Pure path policy: resolving never reads or creates application data.
abstract final class NativeStoragePathResolver {
  static String? resolve({
    String? storagePath,
    required String operatingSystem,
    required Map<String, String> environment,
  }) {
    final explicit = storagePath ?? environment['LUMIVO_STORAGE_PATH'];
    if (explicit != null) return _absolute(explicit, operatingSystem);
    final directory = environment['LUMIVO_STORAGE_DIR'];
    if (directory != null) {
      return '${_absolute(directory, operatingSystem)}/storage.json';
    }
    // Flutter's test runner sets this marker. No implicit disk I/O in tests;
    // callers must opt in using an explicit QA file/directory above.
    if (environment.containsKey('FLUTTER_TEST')) return null;

    String? base;
    switch (operatingSystem) {
      case 'windows':
        base = environment['LOCALAPPDATA'] ?? environment['APPDATA'];
        if (base != null) base = '${_absolute(base, operatingSystem)}/Lumivo';
      case 'macos':
        base = environment['HOME'];
        if (base != null) {
          base =
              '${_absolute(base, operatingSystem)}/Library/Application Support/Lumivo';
        }
      case 'linux':
        final xdg = environment['XDG_DATA_HOME'];
        final home = environment['HOME'];
        if (xdg != null && xdg.isNotEmpty) {
          base = '${_absolute(xdg, operatingSystem)}/lumivo';
        } else if (home != null) {
          base = '${_absolute(home, operatingSystem)}/.local/share/lumivo';
        }
      case 'android':
      case 'ios':
        // Preserve the existing mobile in-memory behavior until a platform
        // app-support directory is supplied by bootstrap. Desktop persistence
        // must not turn an otherwise usable mobile app into a startup crash.
        // Explicit mobile paths above still opt into durable storage.
        return null;
      default:
        throw UnsupportedError('Unsupported native storage platform');
    }
    if (base == null) {
      throw StateError('Cannot resolve native application storage');
    }
    return '$base/storage.json';
  }

  static String _absolute(String path, String operatingSystem) {
    final absolute = operatingSystem == 'windows'
        ? RegExp(r'^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+)').hasMatch(path)
        : path.startsWith('/');
    if (path.trim().isEmpty || !absolute) {
      throw ArgumentError('Native storage requires an absolute path');
    }
    return path;
  }
}
