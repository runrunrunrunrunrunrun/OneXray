import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/servers/outbound/map.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';
import 'package:onexray/service/servers/server.dart';
import 'package:onexray/service/shared/xray/validation.dart';

enum NetBirdAuthMethod { oauth, setupKey, privateKey }

class NetBirdServerDraft {
  static const defaultManagementUrl = 'https://api.netbird.io';

  final int? id;
  final CoreConfigData? original;
  final String name;
  final String managementUrl;
  final String deviceName;
  final NetBirdAuthMethod authMethod;
  final String setupKey;
  final String privateKey;
  final String preSharedKey;
  final int? mtu;
  final bool lazyConnection;
  final List<String> natExternalIPs;
  final String logLevel;
  final String dnsRouterInterval;

  const NetBirdServerDraft({
    this.id,
    this.original,
    this.name = '',
    this.managementUrl = defaultManagementUrl,
    this.deviceName = '',
    this.authMethod = NetBirdAuthMethod.oauth,
    this.setupKey = '',
    this.privateKey = '',
    this.preSharedKey = '',
    this.mtu,
    this.lazyConnection = false,
    this.natExternalIPs = const [],
    this.logLevel = '',
    this.dnsRouterInterval = '',
  });

  factory NetBirdServerDraft.fromOutbound(
    Map<String, dynamic> outbound, {
    CoreConfigData? original,
  }) {
    final protocol = outboundString(outbound, 'protocol');
    if (protocol != 'netbird') {
      throw const FormatException('Outbound protocol is not netbird');
    }
    final rawSettings = outbound['settings'];
    final settings = rawSettings is Map<String, dynamic>
        ? rawSettings
        : const <String, dynamic>{};
    final privateKey = (settings['privateKey'] as String? ?? '').trim();
    final setupKey = (settings['setupKey'] as String? ?? '').trim();
    final authMethod = setupKey.isNotEmpty && privateKey.isEmpty
        ? NetBirdAuthMethod.setupKey
        : privateKey.isNotEmpty
        ? NetBirdAuthMethod.privateKey
        : NetBirdAuthMethod.oauth;
    final rawIps = settings['natExternalIPs'];
    final natExternalIPs = rawIps is List
        ? rawIps.whereType<String>().toList(growable: false)
        : const <String>[];
    final mgmt = (settings['managementUrl'] as String? ?? '').trim();
    final name = (outbound['tag'] as String? ?? original?.name ?? '').trim();
    return NetBirdServerDraft(
      id: original?.id,
      original: original,
      name: name,
      managementUrl: mgmt.isEmpty ? defaultManagementUrl : mgmt,
      deviceName: (settings['deviceName'] as String? ?? '').trim(),
      authMethod: authMethod,
      setupKey: setupKey,
      privateKey: privateKey,
      preSharedKey: (settings['preSharedKey'] as String? ?? '').trim(),
      mtu: (settings['mtu'] as num?)?.toInt(),
      lazyConnection: settings['lazyConnection'] as bool? ?? false,
      natExternalIPs: natExternalIPs,
      logLevel: (settings['logLevel'] as String? ?? '').trim(),
      dnsRouterInterval:
          (settings['dnsRouterInterval'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toOutbound() {
    final trimmedName = name.trim();
    final trimmedMgmt = managementUrl.trim();
    final trimmedDevice = deviceName.trim();
    final trimmedSetupKey = setupKey.trim();
    final trimmedPrivateKey = privateKey.trim();
    final trimmedPsk = preSharedKey.trim();
    final settings = <String, dynamic>{
      if (trimmedMgmt.isNotEmpty) 'managementUrl': trimmedMgmt,
      if (trimmedDevice.isNotEmpty) 'deviceName': trimmedDevice,
      if (authMethod == NetBirdAuthMethod.setupKey &&
          trimmedSetupKey.isNotEmpty)
        'setupKey': trimmedSetupKey,
      if (trimmedPrivateKey.isNotEmpty &&
          authMethod != NetBirdAuthMethod.setupKey)
        'privateKey': trimmedPrivateKey,
      if (trimmedPsk.isNotEmpty) 'preSharedKey': trimmedPsk,
      if (mtu != null && mtu! > 0) 'mtu': mtu,
      if (lazyConnection) 'lazyConnection': true,
      if (natExternalIPs.isNotEmpty) 'natExternalIPs': natExternalIPs,
      if (logLevel.isNotEmpty) 'logLevel': logLevel,
      if (dnsRouterInterval.isNotEmpty)
        'dnsRouterInterval': dnsRouterInterval,
    };
    return <String, dynamic>{
      'tag': trimmedName.isEmpty ? 'netbird' : trimmedName,
      'protocol': 'netbird',
      'settings': settings,
    };
  }
}

class NetBirdService {
  final AppDatabase _db;
  final ServerAssetService _servers;
  final Future<String> Function(String) _validate;

  NetBirdService({
    AppDatabase? database,
    ServerAssetService? servers,
    Future<String> Function(String)? validate,
  }) : _db = database ?? AppDatabase(),
       _servers = servers ?? ServerAssetService(),
       _validate = validate ?? AppHostApi().testXray;

  Future<NetBirdServerDraft> load(int id) async {
    final row = await _db.coreConfigDao.searchRow(id);
    if (row == null || row.type != CoreConfigType.outbound.name) {
      throw const FormatException('Server no longer exists');
    }
    final outbound = readOutboundFromDbData(row);
    return NetBirdServerDraft.fromOutbound(outbound, original: row);
  }

  Future<int?> save(
    NetBirdServerDraft draft, {
    required Future<bool> Function() confirmReconnect,
  }) async {
    final outbound = draft.toOutbound();
    final validation = await _validate(XrayValidation.nodes([outbound]));
    if (validation.isNotEmpty) {
      throw AppFailure(
        FailureCategory.configuration,
        'xrayValidation',
        cause: validation,
      );
    }
    final existing = draft.original;
    if (existing != null) {
      final saved = await _servers.save(
        ServerEditDraft(existing, jsonEncode(outbound)),
        confirmReconnect: confirmReconnect,
      );
      return saved ? existing.id : null;
    }
    return _db.coreConfigDao.insertAssetRow(outboundCompanion(outbound));
  }
}
