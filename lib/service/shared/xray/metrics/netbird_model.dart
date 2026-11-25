class XrayMetricsNetBirdRelay {
  final String uri;
  final bool available;
  final String transport;
  final String error;

  const XrayMetricsNetBirdRelay({
    this.uri = '',
    this.available = false,
    this.transport = '',
    this.error = '',
  });

  factory XrayMetricsNetBirdRelay.fromJson(Map<String, dynamic> json) {
    return XrayMetricsNetBirdRelay(
      uri: json['uri'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      transport: json['transport'] as String? ?? '',
      error: json['error'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uri': uri,
    'available': available,
    if (transport.isNotEmpty) 'transport': transport,
    if (error.isNotEmpty) 'error': error,
  };
}

class XrayMetricsNetBirdPeer {
  final String ip;
  final String ipv6;
  final String fqdn;
  final String pubKey;
  final String status;
  final bool relayed;
  final String relayServerAddress;
  final int latencyMs;
  final int bytesTx;
  final int bytesRx;
  final List<String> routes;

  const XrayMetricsNetBirdPeer({
    this.ip = '',
    this.ipv6 = '',
    this.fqdn = '',
    this.pubKey = '',
    this.status = '',
    this.relayed = false,
    this.relayServerAddress = '',
    this.latencyMs = 0,
    this.bytesTx = 0,
    this.bytesRx = 0,
    this.routes = const [],
  });

  factory XrayMetricsNetBirdPeer.fromJson(Map<String, dynamic> json) {
    final rawRoutes = json['routes'];
    return XrayMetricsNetBirdPeer(
      ip: json['ip'] as String? ?? '',
      ipv6: json['ipv6'] as String? ?? '',
      fqdn: json['fqdn'] as String? ?? '',
      pubKey: json['pubKey'] as String? ?? '',
      status: json['status'] as String? ?? '',
      relayed: json['relayed'] as bool? ?? false,
      relayServerAddress: json['relayServerAddress'] as String? ?? '',
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      bytesTx: (json['bytesTx'] as num?)?.toInt() ?? 0,
      bytesRx: (json['bytesRx'] as num?)?.toInt() ?? 0,
      routes: rawRoutes is List
          ? rawRoutes.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (ip.isNotEmpty) 'ip': ip,
    if (ipv6.isNotEmpty) 'ipv6': ipv6,
    if (fqdn.isNotEmpty) 'fqdn': fqdn,
    if (pubKey.isNotEmpty) 'pubKey': pubKey,
    if (status.isNotEmpty) 'status': status,
    'relayed': relayed,
    if (relayServerAddress.isNotEmpty) 'relayServerAddress': relayServerAddress,
    'latencyMs': latencyMs,
    'bytesTx': bytesTx,
    'bytesRx': bytesRx,
    if (routes.isNotEmpty) 'routes': routes,
  };
}

class XrayMetricsNetBirdStatus {
  final String tag;
  final String state;
  final String deviceName;
  final String managementUrl;
  final bool managementConnected;
  final bool signalConnected;
  final String localIp;
  final String localIpv6;
  final String fqdn;
  final String pubKey;
  final bool lazyConnectionEnabled;
  final int peersTotal;
  final int peersConnected;
  final List<XrayMetricsNetBirdRelay> relays;
  final List<XrayMetricsNetBirdPeer> peers;
  final List<String> routes;
  final bool loginExpired;
  final String lastError;

  const XrayMetricsNetBirdStatus({
    this.tag = '',
    this.state = '',
    this.deviceName = '',
    this.managementUrl = '',
    this.managementConnected = false,
    this.signalConnected = false,
    this.localIp = '',
    this.localIpv6 = '',
    this.fqdn = '',
    this.pubKey = '',
    this.lazyConnectionEnabled = false,
    this.peersTotal = 0,
    this.peersConnected = 0,
    this.relays = const [],
    this.peers = const [],
    this.routes = const [],
    this.loginExpired = false,
    this.lastError = '',
  });

  factory XrayMetricsNetBirdStatus.fromJson(Map<String, dynamic> json) {
    final rawRelays = json['relays'];
    final rawPeers = json['peers'];
    final rawRoutes = json['routes'];
    return XrayMetricsNetBirdStatus(
      tag: json['tag'] as String? ?? '',
      state: json['state'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      managementUrl: json['managementUrl'] as String? ?? '',
      managementConnected: json['managementConnected'] as bool? ?? false,
      signalConnected: json['signalConnected'] as bool? ?? false,
      localIp: json['localIp'] as String? ?? '',
      localIpv6: json['localIpv6'] as String? ?? '',
      fqdn: json['fqdn'] as String? ?? '',
      pubKey: json['pubKey'] as String? ?? '',
      lazyConnectionEnabled: json['lazyConnectionEnabled'] as bool? ?? false,
      peersTotal: (json['peersTotal'] as num?)?.toInt() ?? 0,
      peersConnected: (json['peersConnected'] as num?)?.toInt() ?? 0,
      relays: rawRelays is List
          ? [
              for (final item in rawRelays)
                if (item is Map<String, dynamic>)
                  XrayMetricsNetBirdRelay.fromJson(item),
            ]
          : const [],
      peers: rawPeers is List
          ? [
              for (final item in rawPeers)
                if (item is Map<String, dynamic>)
                  XrayMetricsNetBirdPeer.fromJson(item),
            ]
          : const [],
      routes: rawRoutes is List
          ? rawRoutes.whereType<String>().toList(growable: false)
          : const [],
      loginExpired: json['loginExpired'] as bool? ?? false,
      lastError: json['lastError'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (tag.isNotEmpty) 'tag': tag,
    if (state.isNotEmpty) 'state': state,
    if (deviceName.isNotEmpty) 'deviceName': deviceName,
    if (managementUrl.isNotEmpty) 'managementUrl': managementUrl,
    'managementConnected': managementConnected,
    'signalConnected': signalConnected,
    if (localIp.isNotEmpty) 'localIp': localIp,
    if (localIpv6.isNotEmpty) 'localIpv6': localIpv6,
    if (fqdn.isNotEmpty) 'fqdn': fqdn,
    if (pubKey.isNotEmpty) 'pubKey': pubKey,
    'lazyConnectionEnabled': lazyConnectionEnabled,
    'peersTotal': peersTotal,
    'peersConnected': peersConnected,
    if (relays.isNotEmpty) 'relays': [for (final r in relays) r.toJson()],
    if (peers.isNotEmpty) 'peers': [for (final p in peers) p.toJson()],
    if (routes.isNotEmpty) 'routes': routes,
    'loginExpired': loginExpired,
    if (lastError.isNotEmpty) 'lastError': lastError,
  };
}
