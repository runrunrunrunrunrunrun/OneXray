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
    final statuses =
        view.traffic?.netbird.values.toList(growable: false) ??
        const <XrayMetricsNetBirdStatus>[];
    if (statuses.isEmpty) return const SizedBox.shrink();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.tag.isNotEmpty ? status.tag : 'netbird',
                style: AppTypography.rowTitle.copyWith(
                  color: palette.foreground,
                ),
              ),
            ),
            Text(
              stateLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: stateColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (status.localIp.isNotEmpty || status.fqdn.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (status.localIp.isNotEmpty)
                '${nl.liveLocalIp}: ${status.localIp}',
              if (status.fqdn.isNotEmpty) status.fqdn,
            ].join(' · '),
            style: AppTypography.supporting.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _StatusChip(
              label: status.managementConnected
                  ? nl.liveMgmtConnected
                  : nl.liveMgmtDisconnected,
              color: status.managementConnected
                  ? palette.runningText
                  : palette.restartingText,
            ),
            _StatusChip(
              label: status.signalConnected
                  ? nl.liveSignalConnected
                  : nl.liveSignalDisconnected,
              color: status.signalConnected
                  ? palette.runningText
                  : palette.restartingText,
            ),
            _StatusChip(label: peersLabel, color: palette.mutedStrong),
            if (status.relays.isNotEmpty)
              _StatusChip(label: relaysLabel, color: palette.mutedStrong),
          ],
        ),
        if (status.loginExpired || status.lastError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status.loginExpired
                  ? palette.warningSurface
                  : palette.destructiveSurface,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: status.loginExpired
                    ? palette.restartingText
                    : palette.destructive,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  size: 16,
                  color: status.loginExpired
                      ? palette.restartingText
                      : palette.destructive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.loginExpired
                        ? nl.liveLoginExpiredWarning
                        : status.lastError,
                    style: AppTypography.supporting.copyWith(
                      color: status.loginExpired
                          ? palette.restartingText
                          : palette.destructive,
                    ),
                  ),
                ),
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
    final isConnected = peer.status.toLowerCase() == 'connected';
    final pathKind = peer.relayed ? nl.liveRelayed : nl.liveP2p;
    final latency = peer.latencyMs > 0 ? '${peer.latencyMs} ms' : null;
    final traffic = (peer.bytesTx > 0 || peer.bytesRx > 0)
        ? '↑${_formatBytes(peer.bytesTx)} ↓${_formatBytes(peer.bytesRx)}'
        : null;
    final parts = [isConnected ? pathKind : peer.status, ?latency, ?traffic];
    final summary = parts.join(' · ');
    return Row(
      children: [
        Expanded(
          child: Text(
            peer.ip.isNotEmpty && peer.fqdn.isNotEmpty
                ? '$name (${peer.ip})'
                : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.supporting.copyWith(color: palette.foreground),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          summary,
          style: AppTypography.code.copyWith(
            color: isConnected ? palette.runningText : palette.mutedForeground,
          ),
        ),
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
