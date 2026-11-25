import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/servers/netbird/l10n.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/shared/xray/metrics/netbird_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NetBirdStatusReadout extends StatelessWidget {
  const NetBirdStatusReadout({
    super.key,
    required this.view,
    this.desktop = false,
  });

  final ConnectionView view;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final runtime = view.runtime;
    if (view.phase != ConnectionPhase.connected || runtime == null) {
      return const SizedBox.shrink();
    }
    final map = view.traffic?.netbird;
    if (map == null || map.isEmpty) return const SizedBox.shrink();
    final statuses = map.values.toList(growable: false);
    final palette = ColorManager.palette(context);
    final nl = NetBirdL10n.of(context);
    return Container(
      key: const ValueKey('runtime-netbird-status'),
      padding: EdgeInsets.symmetric(vertical: desktop ? 18 : 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shield, size: 17, color: palette.primaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nl.liveStatusTitle,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          for (final status in statuses)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _NetBirdOutboundCard(status: status),
            ),
        ],
      ),
    );
  }
}

class _NetBirdOutboundCard extends StatelessWidget {
  const _NetBirdOutboundCard({required this.status});

  final XrayMetricsNetBirdStatus status;

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final (stateLabel, stateColor) = switch (status.state) {
      'started' => (nl.liveStateStarted, palette.runningText),
      'starting' => (nl.liveStateStarting, palette.restartingText),
      'closed' => (nl.liveStateClosed, palette.destructive),
      _ => (nl.liveStateIdle, palette.mutedStrong),
    };
    final availableRelays = status.relays.where((r) => r.available).length;
    final peersLabel =
        '${nl.livePeers}: ${status.peersConnected}/${status.peersTotal}';
    final relaysLabel =
        '${nl.liveRelays}: $availableRelays/${status.relays.length}';
    final fg = palette.foreground;
    final titleStyle = AppTypography.rowTitle.copyWith(color: fg);
    final stateStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: stateColor, fontWeight: FontWeight.w600);
    final endpoint = [
      if (status.localIp.isNotEmpty) '${nl.liveLocalIp}: ${status.localIp}',
      if (status.fqdn.isNotEmpty) status.fqdn,
    ].join(' · ');
    final mutedFg = palette.mutedForeground;
    final endpointStyle = AppTypography.supporting.copyWith(color: mutedFg);
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
        ? nl.liveLoginExpiredWarning
        : status.lastError;
    final alertTextStyle = AppTypography.supporting.copyWith(color: alertColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.tag.isNotEmpty ? status.tag : 'netbird',
                style: titleStyle,
              ),
            ),
            Text(stateLabel, style: stateStyle),
          ],
        ),
        if (endpoint.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(endpoint, style: endpointStyle),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _StatusChip(label: mgmtLabel, color: mgmtColor),
            _StatusChip(label: signalLabel, color: signalColor),
            _StatusChip(label: peersLabel, color: palette.mutedStrong),
            if (status.relays.isNotEmpty)
              _StatusChip(label: relaysLabel, color: palette.mutedStrong),
          ],
        ),
        if (hasAlert) ...[
          const SizedBox(height: 8),
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
                Expanded(child: Text(alertText, style: alertTextStyle)),
              ],
            ),
          ),
        ],
        if (status.peers.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final peer in status.peers.take(6))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _PeerLine(peer: peer),
            ),
        ],
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

class _PeerLine extends StatelessWidget {
  const _PeerLine({required this.peer});

  final XrayMetricsNetBirdPeer peer;

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final name = peer.fqdn.isNotEmpty
        ? peer.fqdn
        : (peer.ip.isNotEmpty ? peer.ip : peer.pubKey);
    final displayName = peer.ip.isNotEmpty && peer.fqdn.isNotEmpty
        ? '$name (${peer.ip})'
        : name;
    final isConnected = peer.status.toLowerCase() == 'connected';
    final pathKind = peer.relayed ? nl.liveRelayed : nl.liveP2p;
    final latency = peer.latencyMs > 0 ? '${peer.latencyMs} ms' : null;
    final traffic = (peer.bytesTx > 0 || peer.bytesRx > 0)
        ? '↑${_formatBytes(peer.bytesTx)} ↓${_formatBytes(peer.bytesRx)}'
        : null;
    final parts = [isConnected ? pathKind : peer.status, ?latency, ?traffic];
    final summary = parts.join(' · ');
    final fg = palette.foreground;
    final nameStyle = AppTypography.supporting.copyWith(color: fg);
    final sColor = isConnected ? palette.runningText : palette.mutedForeground;
    final summaryStyle = AppTypography.code.copyWith(color: sColor);
    return Row(
      children: [
        Expanded(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        const SizedBox(width: 8),
        Text(summary, style: summaryStyle),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}K';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}M';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}G';
  }
}
