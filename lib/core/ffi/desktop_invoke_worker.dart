import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/tools/logger.dart';

typedef StartInvokeWorker = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Persistent desktop worker running `OneXrayCore serve-invoke` over stdio.
///
/// Shares a single Go process across `invoke` and `invokeConcurrent` calls
/// without bundling a duplicate `libXray.dll` / `libXray.so` library.
class DesktopInvokeWorker {
  DesktopInvokeWorker({
    required this.resolveExecutable,
    StartInvokeWorker? startProcess,
    this.startupTimeout = const Duration(seconds: 15),
  }) : _startProcess = startProcess ?? Process.start;

  /// Active worker PIDs excluded from desktop VPN lifecycle checks.
  static final Set<int> activePids = <int>{};

  final String Function() resolveExecutable;
  final StartInvokeWorker _startProcess;
  final Duration startupTimeout;

  Process? _process;
  int? _pid;
  Future<void>? _starting;
  int _nextId = 1;
  final Map<int, Completer<String>> _pending = <int, Completer<String>>{};
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  bool _stopping = false;

  Future<String> invoke(String requestJson) async {
    await _ensureStarted();
    final process = _process;
    if (process == null) {
      throw StateError('Desktop invoke worker is unavailable');
    }
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    try {
      final line = jsonEncode({'id': id, 'request': requestJson});
      process.stdin.writeln(line);
      await process.stdin.flush();
    } catch (error, stackTrace) {
      final removed = _pending.remove(id);
      if (removed != null && !removed.isCompleted) {
        removed.completeError(error, stackTrace);
      }
      rethrow;
    }
    return completer.future;
  }

  Future<void> _ensureStarted() async {
    if (_process != null) return;
    final inFlight = _starting;
    if (inFlight != null) return inFlight;
    final future = _start();
    _starting = future;
    try {
      await future;
    } finally {
      if (identical(_starting, future)) {
        _starting = null;
      }
    }
  }

  Future<void> _start() async {
    _stopping = false;
    final executable = resolveExecutable();
    final process = await _startProcess(executable, const ['serve-invoke']);
    final pid = process.pid;
    activePids.add(pid);
    final ready = Completer<void>();

    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _handleStdoutLine(line, ready),
          onError: (Object error, StackTrace stackTrace) {
            if (!ready.isCompleted) {
              ready.completeError(error, stackTrace);
            }
          },
          onDone: () {
            if (!ready.isCompleted) {
              ready.completeError(
                StateError('Desktop invoke worker closed stdout before ready'),
              );
            }
          },
        );
    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (!kReleaseMode && line.isNotEmpty) {
            ygLogger('invoke worker: $line');
          }
        });

    unawaited(
      process.exitCode.then(
        (code) => _handleExit(process, pid, code, ready),
        onError: (Object error, StackTrace stackTrace) =>
            _handleExit(process, pid, -1, ready),
      ),
    );

    try {
      await ready.future.timeout(startupTimeout);
    } catch (_) {
      activePids.remove(pid);
      await _cleanupProcess(process, pid);
      rethrow;
    }
    _process = process;
    _pid = pid;
  }

  void _handleStdoutLine(String line, Completer<void> ready) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['ready'] == true) {
        if (!ready.isCompleted) {
          ready.complete();
        }
        return;
      }
      final id = (decoded['id'] as num?)?.toInt();
      if (id == null) return;
      final completer = _pending.remove(id);
      if (completer == null || completer.isCompleted) return;
      final response = decoded['response'];
      if (response is String) {
        completer.complete(response);
      } else {
        completer.completeError(
          const FormatException('Invalid worker response envelope'),
        );
      }
    } catch (error, stackTrace) {
      if (!ready.isCompleted) {
        ready.completeError(error, stackTrace);
      }
    }
  }

  void _handleExit(Process process, int pid, int code, Completer<void> ready) {
    activePids.remove(pid);
    if (identical(_process, process)) {
      _process = null;
      _pid = null;
    }
    final error = StateError('Desktop invoke worker exited (code $code)');
    if (!ready.isCompleted) {
      ready.completeError(error);
    }
    _failPending(error);
  }

  void _failPending(Object error) {
    if (_pending.isEmpty) return;
    final entries = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in entries) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  Future<void> _cleanupProcess(Process process, int pid) async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    try {
      await process.stdin.close();
    } catch (_) {}
    try {
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
    } catch (_) {
      process.kill();
    } finally {
      activePids.remove(pid);
    }
  }

  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    final process = _process;
    final pid = _pid;
    _process = null;
    _pid = null;
    _failPending(StateError('Desktop invoke worker stopped'));
    if (process != null && pid != null) {
      await _cleanupProcess(process, pid);
    } else {
      await _stdoutSub?.cancel();
      await _stderrSub?.cancel();
      _stdoutSub = null;
      _stderrSub = null;
    }
  }
}
