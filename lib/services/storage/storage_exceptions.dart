/// Base exception for all storage failures in Lumivo.
class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'StorageException: $message (Caused by: $cause)';
    }
    return 'StorageException: $message';
  }
}

/// Thrown when an underlying I/O, file system, or permission operation fails.
class StorageIOException extends StorageException {
  const StorageIOException(
    String message, {
    this.operation,
    this.targetKey,
    this.targetPath,
    Object? cause,
  }) : super(message, cause);

  final String? operation;
  final String? targetKey;
  final String? targetPath;

  @override
  String toString() {
    final details = <String>[];
    if (operation != null) details.add('op=$operation');
    if (targetKey != null) details.add('key=$targetKey');
    if (targetPath != null) details.add('path=$targetPath');
    if (cause != null) details.add('cause=$cause');
    final suffix = details.isNotEmpty ? ' [${details.join(', ')}]' : '';
    return 'StorageIOException: $message$suffix';
  }
}

/// Thrown when platform application support path cannot be safely resolved.
class StoragePathException extends StorageException {
  const StoragePathException(super.message, [super.cause]);

  @override
  String toString() => 'StoragePathException: $message';
}
