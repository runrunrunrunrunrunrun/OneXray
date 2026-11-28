import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show protected;
import 'package:onexray/core/ffi/desktop_invoke_worker.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

List<String> desktopCoreRunArguments({
  required String dns,
  required String interfaceName,
  required String configPath,
  String? errorFile,
  bool? setDns,
}) {
  if (configPath.isEmpty ||
      (setDns != false && (dns.isEmpty || interfaceName.isEmpty))) {
    throw const FormatException(
      'Desktop Core DNS, interface, or config path is missing',
    );
  }
  return <String>[
    'run',
    if (setDns != null) '-set-dns=$setDns',
    if (dns.isNotEmpty) ...['-dns', '$dns:53'],
    if (interfaceName.isNotEmpty) ...['-interface', interfaceName],
    '-config',
    configPath,
    if (errorFile != null) ...['-error-file', errorFile],
  ];
}

File desktopCoreErrorFile(String configPath) => File('$configPath.error');

Future<String> readDesktopCoreStartError(
  String configPath,
  String fallback,
) async {
  try {
    final file = desktopCoreErrorFile(configPath);
    final error = (await file.readAsString()).trim();
    if (error.isNotEmpty) return error;
  } on FileSystemException {
    // A crash before the CLI starts may leave no diagnostic file.
  }
  return fallback;
}

abstract class BaseFfiApi {
  Future<String> getTunFilesDir() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  Future<NativeVpnCommandResult> readVpnStatus();

  /// Successful commands return the confirmed terminal status. Each platform
  /// owns its notification/wait mechanism; callers do not poll for completion.
  Future<NativeVpnCommandResult> startVpn();
  Future<NativeVpnCommandResult> stopVpn();
  Future<void> observeVpnStatus();
  void disposeVpnStatus();

  @protected
  LibXrayRunConfig readRunXrayRequest(StartVpnRequest request) {
    if (!EmptyTool.checkString(request.coreInvokeText)) {
      return LibXrayRunConfig(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest(null).toJson(),
        ),
      );
    }
    return LibXrayRunConfig.fromInvokeText(request.coreInvokeText!);
  }

  /// Only call after the previous Core has stopped and before launching its replacement.
  @protected
  Future<void> clearRuntimeLogs() async {
    final directory = p.join(await getTunFilesDir(), 'run');
    final type = await FileSystemEntity.type(directory, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Invalid runtime log directory', directory);
    }
    final files = <File>[];
    for (final name in ['access.log', 'error.log']) {
      final file = File(p.join(directory, name));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw FileSystemException('Invalid runtime log file', file.path);
      }
      files.add(file);
    }
    // Validate both before removing either; never traverse the runtime directory.
    for (final file in files) {
      await file.delete();
    }
  }

  Future<String?> materializeRunXrayConfig(LibXrayRunConfig request) async {
    final runPath = p.join(await getTunFilesDir(), 'run');
    final root = Directory(p.join(runPath, 'core-inputs'));
    final type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await root.delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      throw const FormatException('Invalid desktop Core input directory');
    }
    await root.create(recursive: true);
    final xrayJson = request.request.xrayJson;
    if (xrayJson == null || xrayJson.isEmpty) {
      return null;
    }

    final directory = await root.createTemp('input-');
    try {
      final config = File(p.join(directory.path, 'xray.json'));
      await config.writeAsString(xrayJson, flush: true);
      return config.path;
    } catch (_) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  PlatformPermissionResult _permissionNotRequired() {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.notRequired,
    );
  }

  @protected
  NativeVpnCommandResult commandSuccess({VpnStatus? status}) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.success,
      status: status,
      permission: _permissionNotRequired(),
    );
  }

  @protected
  NativeVpnCommandResult commandFailed([String? message]) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.failed,
      permission: _permissionNotRequired(),
      message: message,
    );
  }

  @protected
  String get desktopInvokeExecutable {
    final name = AppPlatform.isWindows ? 'OneXrayCore.exe' : 'OneXrayCore';
    return p.join(p.dirname(Platform.resolvedExecutable), name);
  }

  DesktopInvokeWorker? _invokeWorker;

  DesktopInvokeWorker get _worker => _invokeWorker ??= DesktopInvokeWorker(
    resolveExecutable: () => desktopInvokeExecutable,
  );

  void stopSharedIsolate() {
    final worker = _invokeWorker;
    _invokeWorker = null;
    if (worker != null) {
      unawaited(worker.stop());
    }
  }

  Future<String> invoke(String requestJson) => _worker.invoke(requestJson);

  Future<String> invokeConcurrent(String requestJson) =>
      _worker.invoke(requestJson);
}
