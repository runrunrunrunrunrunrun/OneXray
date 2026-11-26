import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/connect/traffic.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:onexray/service/shared/xray/metrics/netbird_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalePolicy.localizationsDelegates,
    builder: (context, child) => LayoutBuilder(
      builder: (context, constraints) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: constraints.biggest),
        child: ShadTheme(data: AppTheme.shad(Brightness.light), child: child!),
      ),
    ),
    home: Scaffold(body: child),
  );

  Widget screen({ConnectionView view = const ConnectionView()}) => ConnectView(
    view: view,
    hasServers: true,
    expert: false,
    raws: const [],
    activeRawId: null,
    location: 'NetBird Mesh',
    method: 'Smart Routing',
    onConnection: () {},
    onAddServers: () {},
    onServer: () {},
    onMethod: () {},
  );

  testWidgets('netbird card is hidden unless connected with netbird metrics', (
    tester,
  ) async {
    await tester.pumpWidget(app(screen()));
    expect(find.byKey(const ValueKey('runtime-netbird-status')), findsNothing);

    await tester.pumpWidget(
      app(
        screen(
          view: ConnectionView(
            phase: ConnectionPhase.connected,
            runtime: _runtime(),
            traffic: const ConnectionTraffic(
              uplink: 100,
              downlink: 200,
              sampledAtMs: 1000,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('runtime-netbird-status')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'netbird standalone card shows all scrollable peers and peer detail dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final peers = List<XrayMetricsNetBirdPeer>.generate(
        10,
        (i) => XrayMetricsNetBirdPeer(
          ip: '100.64.0.${i + 10}',
          ipv6: 'fd00::${i + 10}',
          fqdn: 'node-${i.toString().padLeft(2, '0')}.netbird.selfhosted',
          pubKey: 'pubkey-$i-abcdef',
          status: i < 7 ? 'connected' : 'disconnected',
          relayed: i == 0,
          relayServerAddress: i == 0 ? 'rels://relay.example.com:3478' : '',
          latencyMs: i < 7 ? 12 + i : 0,
          bytesTx: 2048 * (i + 1),
          bytesRx: 4096 * (i + 1),
          routes: i == 0 ? const ['10.10.0.0/16'] : const [],
        ),
      );
      final status = XrayMetricsNetBirdStatus(
        tag: 'proxy',
        state: 'started',
        deviceName: 'workstation',
        managementConnected: true,
        signalConnected: true,
        localIp: '100.64.0.2/16',
        fqdn: 'workstation.netbird.selfhosted',
        hasDefaultDns: true,
        peersTotal: peers.length,
        peersConnected: 7,
        peers: peers,
        routes: const ['10.10.0.0/16'],
        dnsDomains: const ['netbird.selfhosted'],
      );
      await tester.pumpWidget(
        app(
          screen(
            view: ConnectionView(
              phase: ConnectionPhase.connected,
              runtime: _runtime(),
              metricsAvailable: true,
              traffic: ConnectionTraffic(
                uplink: 1024,
                downlink: 2048,
                sampledAtMs: 1000,
                netbird: {'proxy': status},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final sessionFinder = find.byKey(const ValueKey('connection-session'));
      final netbirdFinder = find.byKey(
        const ValueKey('runtime-netbird-status'),
      );
      expect(sessionFinder, findsOneWidget);
      expect(netbirdFinder, findsOneWidget);
      expect(
        find.descendant(of: sessionFinder, matching: netbirdFinder),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('netbird-peer-scrollbar')),
        findsOneWidget,
      );

      final peerListFinder = find.byKey(const ValueKey('netbird-peer-list'));
      expect(peerListFinder, findsOneWidget);
      expect(find.text('node-00.netbird.selfhosted'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('node-09.netbird.selfhosted'),
        120,
        scrollable: find.descendant(
          of: peerListFinder,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('node-09.netbird.selfhosted'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('node-00.netbird.selfhosted'),
        -120,
        scrollable: find.descendant(
          of: peerListFinder,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('node-00.netbird.selfhosted'));
      await tester.pumpAndSettle();

      expect(find.text('rels://relay.example.com:3478'), findsOneWidget);
      expect(find.text('pubkey-0-abcdef'), findsOneWidget);
      expect(find.text('fd00::10'), findsOneWidget);
      expect(find.text('10.10.0.0/16'), findsWidgets);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('rels://relay.example.com:3478'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

ConnectionRuntime _runtime() {
  final configuration = ConnectionConfiguration();
  return ConnectionRuntime.create(
    configuration: configuration,
    compiled: CompiledConnection(
      xrayJson: '{}',
      entries: [
        ResolvedServer(
          id: 1,
          sourceId: 0,
          outbound: {'protocol': 'netbird', 'tag': 'proxy'},
        ),
      ],
      finalExit: null,
      nodeTags: const {},
    ),
    platform: ConnectionPlatform.windows,
    request: StartVpnRequest(
      configuration.policy.toTun(ConnectionPlatform.windows),
      null,
      null,
      '{}',
      captureMode: 'tun',
    ),
  );
}
