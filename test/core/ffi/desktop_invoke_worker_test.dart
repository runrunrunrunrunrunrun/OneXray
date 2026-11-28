import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/desktop_invoke_worker.dart';

void main() {
  test(
    'worker completes ready handshake, concurrent calls, and cleans up pid',
    () async {
    final proc = _FakeProcess(pid: 424242);
    late String launchedExe;
    late List<String> launchedArgs;
    final worker = DesktopInvokeWorker(
      resolveExecutable: () => '/opt/OneXray/OneXrayCore',
      startProcess: (exe, args) async {
        launchedExe = exe;
        launchedArgs = args;
        expect(DesktopInvokeWorker.activePids, isNot(contains(proc.pid)));
        return proc;
      },
    );

    final f1 = worker.invoke('{"method":"first"}');
    await Future<void>.delayed(Duration.zero);
    expect(launchedExe, '/opt/OneXray/OneXrayCore');
    expect(launchedArgs, ['serve-invoke']);
    expect(DesktopInvokeWorker.activePids, contains(424242));

    proc.emitStdoutLine('{"ready":true}');
    final f2 = worker.invoke('{"method":"second"}');
    await proc.waitForLines(2);

    final req1 = jsonDecode(proc.writtenLines[0]) as Map<String, dynamic>;
    final req2 = jsonDecode(proc.writtenLines[1]) as Map<String, dynamic>;
    expect(req1['request'], '{"method":"first"}');
    expect(req2['request'], '{"method":"second"}');

    // Deliver responses out of order to prove concurrent routing.
    proc.emitStdoutLine(jsonEncode({'id': req2['id'], 'response': '{"n":2}'}));
    proc.emitStdoutLine(jsonEncode({'id': req1['id'], 'response': '{"n":1}'}));

    expect(await f1, '{"n":1}');
    expect(await f2, '{"n":2}');

    await worker.stop();
    expect(DesktopInvokeWorker.activePids, isNot(contains(424242)));
  });

  test(
    'worker fails pending calls and clears activePids on unexpected exit',
    () async {
    final proc = _FakeProcess(pid: 515151);
    final worker = DesktopInvokeWorker(
      resolveExecutable: () => '/opt/OneXray/OneXrayCore',
      startProcess: (_, _) async => proc,
    );

    final pending = worker.invoke('{"method":"hang"}');
    await Future<void>.delayed(Duration.zero);
    proc.emitStdoutLine('{"ready":true}');
    await proc.waitForLines(1);
    expect(DesktopInvokeWorker.activePids, contains(515151));

    proc.finish(7);
    await expectLater(pending, throwsStateError);
    expect(DesktopInvokeWorker.activePids, isNot(contains(515151)));
  });
}

class _FakeProcess implements Process {
  _FakeProcess({required this.pid}) {
    _stdin = _RecordingIOSink(writtenLines, () => _lineSignal.add(null));
  }

  @override
  final int pid;

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exitCode = Completer<int>();
  final _lineSignal = StreamController<void>.broadcast();
  final List<String> writtenLines = [];
  late final IOSink _stdin;

  void emitStdoutLine(String line) {
    _stdout.add(utf8.encode('$line\n'));
  }

  Future<void> waitForLines(int count) async {
    while (writtenLines.length < count) {
      await _lineSignal.stream.first;
    }
  }

  void finish(int code) {
    if (!_exitCode.isCompleted) {
      _exitCode.complete(code);
    }
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    finish(-1);
    return true;
  }

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;
}

class _RecordingIOSink implements IOSink {
  _RecordingIOSink(this._lines, this._onLine);

  final List<String> _lines;
  final void Function() _onLine;
  final _buffer = StringBuffer();
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    _buffer.write(encoding.decode(data));
    _drain();
  }

  @override
  void write(Object? object) {
    _buffer.write(object);
    _drain();
  }

  @override
  void writeln([Object? object = '']) {
    _buffer.write(object);
    _buffer.write('\n');
    _drain();
  }

  void _drain() {
    var text = _buffer.toString();
    while (true) {
      final index = text.indexOf('\n');
      if (index < 0) break;
      _lines.add(text.substring(0, index));
      _onLine();
      text = text.substring(index + 1);
    }
    _buffer
      ..clear()
      ..write(text);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future close() async {}

  @override
  Future get done => Future<void>.value();

  @override
  Future flush() async {}

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
}
