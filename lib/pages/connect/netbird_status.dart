import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/tools/traffic_format.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/servers/netbird/l10n.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/widgets/adaptive_dialog.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/shared/xray/metrics/netbird_model.dart';

typedef NetBirdStatusReadout = NetBirdNetworkCard;

class NetBirdNetworkCard extends StatelessWidget {
  const NetBirdNetworkCard({super.key, required this.view});

  final ConnectionView view;

  @override
  Widget build(BuildContext context) {
    final runtime = view.runtime;
    final map = view.traffic?.netbird;
    if (view.phase != ConnectionPhase.connected ||
        runtime == null ||
        map == null ||
        map.isEmpty) {
      return const SizedBox.shrink();
    }
    final statuses = map.values.toList(growable: false);
    final palette = ColorManager.palette(context);
    final nl = NetBirdL10n.of(context);
    var totalConnected = 0;
    var totalPeers = 0;
    for (final status in statuses) {
      totalConnected += status.peersConnected;
      totalPeers += status.peersTotal;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        key: const ValueKey('runtime-netbird-status'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nl.liveNetworkTitle,
                      style: AppTypography.panelTitle,
                    ),
                  ),
                  _StatusChip(
                    label: '${nl.livePeers}: $totalConnected/$totalPeers',
                    color: totalConnected > 0
                        ? palette.runningText
                        : palette.mutedStrong,
                  ),
                ],
              ),
              for (var i = 0; i < statuses.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: palette.border),
                  )
                else
                  const SizedBox(height: 14),
                _NetBirdOutboundSection(status: statuses[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NetBirdOutboundSection extends StatelessWidget {
  const _NetBirdOutboundSection({required this.status});

  final XrayMetricsNetBirdStatus status;

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final (stateLabel, stateColor, stateBg) = switch (status.state) {
      'started' => (
        nl.liveStateStarted,
        palette.runningText,
        palette.runningSurface,
      ),
      'starting' => (
        nl.liveStateStarting,
        palette.restartingText,
        palette.warningSurface,
      ),
      'closed' => (
        nl.liveStateClosed,
        palette.destructive,
        palette.destructiveSurface,
      ),
      _ => (nl.liveStateIdle, palette.mutedStrong, palette.secondary),
    };
    final availableRelays = status.relays.where((r) => r.available).length;
    final peersLabel =
        '${nl.livePeers}: ${status.peersConnected}/${status.peersTotal}';
    final relaysLabel =
        '${nl.liveRelays}: $availableRelays/${status.relays.length}';
    final routesLabel = '${nl.liveRoutes}: ${status.routes.length}';
    final dnsPreviewList = <String>{
      ...status.dnsDomains,
      ...status.searchDomains,
    }.toList(growable: false);
    final dnsLabel = switch ((
      status.dnsDomains.length,
      status.hasDefaultDns,
      status.searchDomains.length,
    )) {
      (> 0, true, _) =>
        '${nl.liveDns}: ${status.dnsDomains.length} (${nl.liveDefaultDns})',
      (> 0, false, _) => '${nl.liveDns}: ${status.dnsDomains.length}',
      (0, true, _) => '${nl.liveDns}: ${nl.liveDefaultDns}',
      (0, false, > 0) => '${nl.liveDns}: ${status.searchDomains.length}',
      _ => null,
    };
    final titleText = status.deviceName.isNotEmpty
        ? status.deviceName
        : (status.tag.isNotEmpty ? status.tag : 'netbird');
    final endpointParts = [
      if (status.localIp.isNotEmpty) '${nl.liveLocalIp}: ${status.localIp}',
      if (status.fqdn.isNotEmpty) status.fqdn,
    ];
    final endpoint = endpointParts.join(' · ');
    final copyTarget = status.localIp.isNotEmpty
        ? status.localIp
        : status.fqdn;
    final mgmtLabel = status.managementConnected
        ? nl.liveMgmtConnected
        : nl.liveMgmtDisconnected;
    final mgmtColor = status.managementConnected
        ? palette.runningText
        : palette.restartingText;
    final signalLabel = status.signalConnected
        ? nl.liveSignalConnected
        : nl.liveSignalDisconnected;
    final signalColor = status.signalConnected
        ? palette.runningText
        : palette.restartingText;
    final hasAlert = status.loginExpired || status.lastError.isNotEmpty;
    final alertColor = status.loginExpired
        ? palette.restartingText
        : palette.destructive;
    final alertBg = status.loginExpired
        ? palette.warningSurface
        : palette.destructiveSurface;
    final alertText = status.loginExpired
        ? (status.lastError.isNotEmpty
              ? '${nl.liveLoginExpiredWarning}\n${status.lastError}'
              : nl.liveLoginExpiredWarning)
        : status.lastError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titleText,
                style: AppTypography.rowTitle.copyWith(
                  color: palette.foreground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: stateBg,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Text(
                stateLabel,
                style: AppTypography.badge.copyWith(color: stateColor),
              ),
            ),
          ],
        ),
        if (endpoint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  endpoint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.supporting.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
              if (copyTarget.isNotEmpty)
                IconButton(
                  tooltip: nl.liveCopy,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _copyValue(context, copyTarget),
                  icon: Icon(
                    LucideIcons.copy,
                    size: 15,
                    color: palette.mutedForeground,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _StatusChip(label: mgmtLabel, color: mgmtColor),
            _StatusChip(label: signalLabel, color: signalColor),
            _StatusChip(label: peersLabel, color: palette.mutedStrong),
            if (status.relays.isNotEmpty)
              _StatusChip(label: relaysLabel, color: palette.mutedStrong),
            if (status.routes.isNotEmpty)
              _StatusChip(label: routesLabel, color: palette.mutedStrong),
            if (dnsLabel != null)
              _StatusChip(
                label: dnsLabel,
                color: status.hasDefaultDns
                    ? palette.runningText
                    : palette.mutedStrong,
              ),
            if (status.exitNodeActive || status.exitNodeAvailable)
              _StatusChip(
                label: status.exitNodeActive
                    ? nl.liveExitNodeActive
                    : nl.liveExitNodeStandby,
                color: status.exitNodeActive
                    ? palette.runningText
                    : palette.mutedStrong,
              ),
          ],
        ),
        if (status.routes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${nl.liveRoutes}: ${status.routes.take(6).join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: AppTypography.code.copyWith(color: palette.mutedForeground),
          ),
        ],
        if (dnsPreviewList.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${nl.liveDns}: ${dnsPreviewList.take(6).join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: AppTypography.code.copyWith(color: palette.mutedForeground),
          ),
        ],
        if (hasAlert) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: alertBg,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: alertColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.circleAlert, size: 16, color: alertColor),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    alertText,
                    style: AppTypography.supporting.copyWith(color: alertColor),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _NetBirdPeerList(
          peers: status.peers,
          connectedCount: status.peersConnected,
          totalCount: status.peersTotal,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.secondary,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(label, style: AppTypography.code.copyWith(color: color)),
    );
  }
}

class _NetBirdPeerList extends StatefulWidget {
  const _NetBirdPeerList({
    required this.peers,
    required this.connectedCount,
    required this.totalCount,
  });

  final List<XrayMetricsNetBirdPeer> peers;
  final int connectedCount;
  final int totalCount;

  @override
  State<_NetBirdPeerList> createState() => _NetBirdPeerListState();
}

class _NetBirdPeerListState extends State<_NetBirdPeerList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final sorted = List<XrayMetricsNetBirdPeer>.of(widget.peers)
      ..sort((a, b) {
        final rankDiff = _peerRank(a).compareTo(_peerRank(b));
        if (rankDiff != 0) return rankDiff;
        return _peerSortKey(a).compareTo(_peerSortKey(b));
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nl.livePeersHeader,
                style: AppTypography.supporting.copyWith(
                  color: palette.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${widget.connectedCount}/${widget.totalCount}',
              style: AppTypography.code.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: palette.secondary,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              nl.liveNoPeers,
              style: AppTypography.supporting.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: palette.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: Scrollbar(
                  key: const ValueKey('netbird-peer-scrollbar'),
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: ListView.separated(
                    key: const ValueKey('netbird-peer-list'),
                    controller: _scrollController,
                    shrinkWrap: true,
                    primary: false,
                    itemCount: sorted.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: palette.border,
                    ),
                    itemBuilder: (context, index) => _PeerRow(
                      peer: sorted[index],
                      onTap: () =>
                          _showPeerDetailDialog(context, sorted[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static int _peerRank(XrayMetricsNetBirdPeer peer) =>
      switch (peer.status.toLowerCase()) {
        'connected' => 0,
        'connecting' => 1,
        _ => 2,
      };

  static String _peerSortKey(XrayMetricsNetBirdPeer peer) =>
      (peer.fqdn.isNotEmpty
              ? peer.fqdn
              : (peer.ip.isNotEmpty ? peer.ip : peer.pubKey))
          .toLowerCase();
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({required this.peer, required this.onTap});

  final XrayMetricsNetBirdPeer peer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final title = peer.fqdn.isNotEmpty
        ? peer.fqdn
        : (peer.ip.isNotEmpty ? peer.ip : peer.pubKey);
    final subtitleParts = [
      if (peer.fqdn.isNotEmpty && peer.ip.isNotEmpty) peer.ip,
      if (peer.routes.isNotEmpty) '${nl.liveRoutes}: ${peer.routes.length}',
    ];
    final subtitle = subtitleParts.join(' · ');
    final statusLower = peer.status.toLowerCase();
    final isConnected = statusLower == 'connected';
    final isConnecting = statusLower == 'connecting';
    final statusColor = isConnected
        ? palette.runningText
        : isConnecting
        ? palette.restartingText
        : palette.mutedForeground;
    final pathKind = peer.relayed ? nl.liveRelayed : nl.liveP2p;
    final latency = peer.latencyMs > 0 ? ' · ${peer.latencyMs} ms' : '';
    final rightPrimary = isConnected
        ? '$pathKind$latency'
        : _peerStatusLabel(nl, peer.status);
    final hasTraffic = peer.bytesTx > 0 || peer.bytesRx > 0;
    final trafficText = hasTraffic
        ? '↑${formatTraffic(peer.bytesTx, connection: true)} '
              '↓${formatTraffic(peer.bytesRx, connection: true)}'
        : null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: AppTypography.supporting.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: AppTypography.code.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rightPrimary,
                    style: AppTypography.code.copyWith(color: statusColor),
                  ),
                  if (trafficText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      trafficText,
                      textDirection: TextDirection.ltr,
                      style: AppTypography.code.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronRightDir,
                size: 16,
                color: palette.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showPeerDetailDialog(
  BuildContext context,
  XrayMetricsNetBirdPeer peer,
) => showAppDialog<void>(
  context,
  (dialogContext) => _NetBirdPeerDetailDialog(peer: peer),
);

class _NetBirdPeerDetailDialog extends StatelessWidget {
  const _NetBirdPeerDetailDialog({required this.peer});

  final XrayMetricsNetBirdPeer peer;

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final statusLower = peer.status.toLowerCase();
    final isConnected = statusLower == 'connected';
    final isConnecting = statusLower == 'connecting';
    final statusColor = isConnected
        ? palette.runningText
        : isConnecting
        ? palette.restartingText
        : palette.mutedForeground;
    final title = peer.fqdn.isNotEmpty
        ? peer.fqdn
        : (peer.ip.isNotEmpty ? peer.ip : nl.livePeerDetailsTitle);
    final subtitle = peer.fqdn.isNotEmpty && peer.ip.isNotEmpty
        ? peer.ip
        : _peerStatusLabel(nl, peer.status);
    final connectionType = isConnected
        ? (peer.relayed ? nl.liveRelayed : nl.livePeerDirect)
        : '—';
    final latency = peer.latencyMs > 0 ? '${peer.latencyMs} ms' : '—';
    final tx = formatTraffic(peer.bytesTx, connection: true);
    final rx = formatTraffic(peer.bytesRx, connection: true);
    return AppDialog(
      title: title,
      subtitle: subtitle,
      expandLastAction: false,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeerDetailRow(
            label: nl.livePeerStatus,
            value: _peerStatusLabel(nl, peer.status),
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            valueColor: statusColor,
          ),
          _PeerDetailRow(
            label: nl.livePeerConnectionType,
            value: connectionType,
          ),
          if (peer.relayServerAddress.isNotEmpty)
            _PeerDetailRow(
              label: nl.livePeerRelayServer,
              value: peer.relayServerAddress,
              monospace: true,
              copyable: true,
            ),
          _PeerDetailRow(label: nl.livePeerLatency, value: latency),
          _PeerDetailRow(label: nl.livePeerTraffic, value: '↑ $tx  ↓ $rx'),
          if (peer.fqdn.isNotEmpty)
            _PeerDetailRow(
              label: nl.livePeerFqdn,
              value: peer.fqdn,
              monospace: true,
              copyable: true,
            ),
          if (peer.ip.isNotEmpty)
            _PeerDetailRow(
              label: nl.livePeerIpv4,
              value: peer.ip,
              monospace: true,
              copyable: true,
            ),
          if (peer.ipv6.isNotEmpty)
            _PeerDetailRow(
              label: nl.livePeerIpv6,
              value: peer.ipv6,
              monospace: true,
              copyable: true,
            ),
          if (peer.pubKey.isNotEmpty)
            _PeerDetailRow(
              label: nl.livePeerPubKey,
              value: peer.pubKey,
              monospace: true,
              copyable: true,
            ),
          if (peer.routes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              nl.livePeerRoutes,
              style: AppTypography.supporting.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final route in peer.routes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.secondary,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: SelectableText(
                      route,
                      style: AppTypography.code.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        ConnectDialogButton(
          label: nl.liveClose,
          secondary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _PeerDetailRow extends StatelessWidget {
  const _PeerDetailRow({
    required this.label,
    required this.value,
    this.leading,
    this.valueColor,
    this.monospace = false,
    this.copyable = false,
  });

  final String label;
  final String value;
  final Widget? leading;
  final Color? valueColor;
  final bool monospace;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final baseStyle = monospace ? AppTypography.code : AppTypography.supporting;
    final valueStyle = baseStyle.copyWith(
      color: valueColor ?? palette.foreground,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: AppTypography.supporting.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: SelectableText(
              value,
              textDirection: TextDirection.ltr,
              style: valueStyle,
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: nl.liveCopy,
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyValue(context, value),
              icon: Icon(
                LucideIcons.copy,
                size: 16,
                color: palette.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _copyValue(BuildContext context, String value) async {
  final copiedText = AppLocalizations.of(context)!.automationCopied;
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    ContextAlert.showToast(context, copiedText);
  }
}

String _peerStatusLabel(NetBirdL10n nl, String status) =>
    switch (status.toLowerCase()) {
      'connected' => nl.livePeerConnected,
      'connecting' => nl.livePeerConnecting,
      'disconnected' => nl.livePeerDisconnected,
      'idle' => nl.livePeerIdle,
      _ => status.isEmpty ? nl.livePeerIdle : status,
    };
