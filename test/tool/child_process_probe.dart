import 'dart:async';
import 'dart:io';
import 'package:lumivo/services/storage/durable_storage_backend.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: child_process_probe <action> <storageDir> [key] [value]');
    exitCode = 1;
    return;
  }

  final action = args[0];
  final storageDir = args.length > 1 ? args[1] : '';
  final key = args.length > 2 ? args[2] : '';
  final value = args.length > 3 ? args[3] : '';

  final backend = DurableStorageBackend(storagePath: storageDir);

  switch (action) {
    case 'stage-and-pause':
      try {
        await backend.setString(
          key,
          value,
          onStaged: (tempFile) async {
            stdout.writeln('STAGED:${tempFile.path}');
            await stdout.flush();
            // Await a future that never completes, keeping event loop alive until killed
            await Completer<void>().future;
          },
        );
      } catch (e, st) {
        stderr.writeln('ERROR:$e\n$st');
        exitCode = 2;
      }
      break;

    case 'set':
      try {
        await backend.setString(key, value);
        stdout.writeln('COMMITTED');
        await stdout.flush();
      } catch (e, st) {
        stderr.writeln('ERROR:$e\n$st');
        exitCode = 2;
      }
      break;

    case 'get':
      try {
        final res = await backend.getString(key);
        stdout.writeln('VALUE:${res ?? "__NULL__"}');
        await stdout.flush();
      } catch (e, st) {
        stderr.writeln('ERROR:$e\n$st');
        exitCode = 2;
      }
      break;

    case 'remove':
      try {
        await backend.remove(key);
        stdout.writeln('REMOVED');
        await stdout.flush();
      } catch (e, st) {
        stderr.writeln('ERROR:$e\n$st');
        exitCode = 2;
      }
      break;

    case 'clear':
      try {
        await backend.clear();
        stdout.writeln('CLEARED');
        await stdout.flush();
      } catch (e, st) {
        stderr.writeln('ERROR:$e\n$st');
        exitCode = 2;
      }
      break;

    default:
      stderr.writeln('Unknown action: $action');
      exitCode = 1;
  }
}
