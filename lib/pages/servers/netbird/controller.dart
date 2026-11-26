import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/netbird/l10n.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/servers/netbird.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class NetBirdEditorState {
  final bool loading;
  final bool saving;
  final bool oauthRunning;
  final bool advancedExpanded;
  final NetBirdAuthMethod authMethod;
  final bool lazyConnection;
  final NetBirdServerDraft? loadedDraft;
  final String? activeSessionId;
  final String? authUrl;
  final String? userCode;
  final String? oauthFlowType;
  final String? authorizedPeerIp;
  final String? authorizedFqdn;
  final String? error;

  const NetBirdEditorState({
    this.loading = false,
    this.saving = false,
    this.oauthRunning = false,
    this.advancedExpanded = false,
    this.authMethod = NetBirdAuthMethod.oauth,
    this.lazyConnection = false,
    this.loadedDraft,
    this.activeSessionId,
    this.authUrl,
    this.userCode,
    this.oauthFlowType,
    this.authorizedPeerIp,
    this.authorizedFqdn,
    this.error,
  });

  bool get busy => loading || saving;

  NetBirdEditorState copyWith({
    bool? loading,
    bool? saving,
    bool? oauthRunning,
    bool? advancedExpanded,
    NetBirdAuthMethod? authMethod,
    bool? lazyConnection,
    NetBirdServerDraft? loadedDraft,
    String? activeSessionId,
    String? authUrl,
    String? userCode,
    String? oauthFlowType,
    String? authorizedPeerIp,
    String? authorizedFqdn,
    String? error,
    bool clearOAuthSession = false,
    bool clearError = false,
  }) => NetBirdEditorState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    oauthRunning: oauthRunning ?? this.oauthRunning,
    advancedExpanded: advancedExpanded ?? this.advancedExpanded,
    authMethod: authMethod ?? this.authMethod,
    lazyConnection: lazyConnection ?? this.lazyConnection,
    loadedDraft: loadedDraft ?? this.loadedDraft,
    activeSessionId: clearOAuthSession
        ? null
        : activeSessionId ?? this.activeSessionId,
    authUrl: clearOAuthSession ? null : authUrl ?? this.authUrl,
    userCode: clearOAuthSession ? null : userCode ?? this.userCode,
    oauthFlowType: clearOAuthSession
        ? null
        : oauthFlowType ?? this.oauthFlowType,
    authorizedPeerIp: authorizedPeerIp ?? this.authorizedPeerIp,
    authorizedFqdn: authorizedFqdn ?? this.authorizedFqdn,
    error: clearError ? null : error ?? this.error,
  );
}

class NetBirdEditorController extends PageCubit<NetBirdEditorState> {
  final int? serverId;
  final NetBirdService _service;
  final AppHostApi _hostApi;

  final nameController = TextEditingController();
  final managementUrlController = TextEditingController(
    text: NetBirdServerDraft.defaultManagementUrl,
  );
  final deviceNameController = TextEditingController();
  final setupKeyController = TextEditingController();
  final privateKeyController = TextEditingController();
  final preSharedKeyController = TextEditingController();
  final mtuController = TextEditingController();

  NetBirdEditorController({
    this.serverId,
    NetBirdService? service,
    AppHostApi? hostApi,
  }) : _service = service ?? NetBirdService(),
       _hostApi = hostApi ?? AppHostApi(),
       super(NetBirdEditorState(loading: serverId != null));

  Future<void> initialize() async {
    final id = serverId;
    if (id == null) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final draft = await _service.load(id);
      if (!isPageActive) return;
      nameController.text = draft.name;
      managementUrlController.text = draft.managementUrl;
      deviceNameController.text = draft.deviceName;
      setupKeyController.text = draft.setupKey;
      privateKeyController.text = draft.privateKey;
      preSharedKeyController.text = draft.preSharedKey;
      mtuController.text = draft.mtu?.toString() ?? '';
      emit(
        state.copyWith(
          loading: false,
          loadedDraft: draft,
          authMethod: draft.authMethod == NetBirdAuthMethod.privateKey
              ? NetBirdAuthMethod.oauth
              : draft.authMethod,
          lazyConnection: draft.lazyConnection,
          advancedExpanded:
              draft.preSharedKey.isNotEmpty ||
              draft.mtu != null ||
              draft.lazyConnection,
        ),
      );
    } catch (error) {
      if (!isPageActive) return;
      emit(state.copyWith(loading: false, error: failureDetails(error)));
    }
  }

  void setAuthMethod(NetBirdAuthMethod method) {
    emit(state.copyWith(authMethod: method, clearError: true));
  }

  void setLazyConnection(bool value) {
    emit(state.copyWith(lazyConnection: value));
  }

  void toggleAdvanced() {
    emit(state.copyWith(advancedExpanded: !state.advancedExpanded));
  }

  Future<void> copyUserCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ContextAlert.showToast(context, NetBirdL10n.of(context).oauthCopied);
    }
  }

  Future<bool> _launchExternalBrowser(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}
    if (Platform.isWindows) {
      try {
        await Process.start('rundll32', [
          'url.dll,FileProtocolHandler',
          rawUrl,
        ], mode: ProcessStartMode.detached);
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> openAuthUrl(BuildContext context, String rawUrl) async {
    final launched = await _launchExternalBrowser(rawUrl);
    if (!launched && context.mounted) {
      ContextAlert.showToast(
        context,
        NetBirdL10n.of(context).oauthBrowserFailed,
      );
    }
  }

  Future<void> startOAuth(BuildContext context) async {
    if (state.oauthRunning || state.busy) return;
    final nl = NetBirdL10n.of(context);
    final mgmt = managementUrlController.text.trim();
    if (!_isValidHttpUrl(mgmt)) {
      emit(state.copyWith(error: nl.invalidUrlError));
      return;
    }
    emit(
      state.copyWith(
        oauthRunning: true,
        clearOAuthSession: true,
        clearError: true,
      ),
    );
    String? sessionId;
    try {
      final startResp = await _hostApi.netbirdStartOAuth(
        NetBirdStartOAuthRequest(
          managementUrl: mgmt,
          existingPrivateKey: privateKeyController.text.trim().isEmpty
              ? null
              : privateKeyController.text.trim(),
          timeoutSeconds: 20,
        ),
      );
      if (!isPageActive) {
        if (startResp.sessionId.isNotEmpty) {
          unawaited(
            _hostApi.netbirdCancelOAuth(startResp.sessionId).catchError((_) {}),
          );
        }
        return;
      }
      sessionId = startResp.sessionId;
      emit(
        state.copyWith(
          activeSessionId: startResp.sessionId,
          authUrl: startResp.authUrl,
          userCode: startResp.userCode,
          oauthFlowType: startResp.flowType,
        ),
      );
      if (startResp.authUrl.isNotEmpty) {
        final launched = await _launchExternalBrowser(startResp.authUrl);
        if (!launched && context.mounted) {
          ContextAlert.showToast(context, nl.oauthBrowserFailed);
        }
      }
      final completeResp = await _hostApi.netbirdCompleteOAuth(
        NetBirdCompleteOAuthRequest(
          sessionId: startResp.sessionId,
          deviceName: deviceNameController.text.trim().isEmpty
              ? null
              : deviceNameController.text.trim(),
          timeoutSeconds: 300,
        ),
      );
      if (!isPageActive) return;
      if (completeResp.privateKey.isNotEmpty) {
        privateKeyController.text = completeResp.privateKey;
      }
      if ((completeResp.managementUrl ?? '').isNotEmpty) {
        managementUrlController.text = completeResp.managementUrl!;
      }
      if (nameController.text.trim().isEmpty) {
        nameController.text = (completeResp.fqdn ?? '').isNotEmpty
            ? completeResp.fqdn!
            : 'NetBird';
      }
      emit(
        state.copyWith(
          oauthRunning: false,
          clearOAuthSession: true,
          authorizedPeerIp: completeResp.peerIp,
          authorizedFqdn: completeResp.fqdn,
        ),
      );
    } catch (error) {
      if (!isPageActive) return;
      emit(
        state.copyWith(
          oauthRunning: false,
          clearOAuthSession: true,
          error: failureDetails(error).isEmpty
              ? error.toString()
              : failureDetails(error),
        ),
      );
    } finally {
      if (sessionId != null && !isPageActive) {
        unawaited(_hostApi.netbirdCancelOAuth(sessionId).catchError((_) {}));
      }
    }
  }

  Future<void> cancelOAuth() async {
    final sessionId = state.activeSessionId;
    emit(state.copyWith(oauthRunning: false, clearOAuthSession: true));
    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        await _hostApi.netbirdCancelOAuth(sessionId);
      } catch (_) {}
    }
  }

  Future<void> save(BuildContext context) async {
    if (state.busy) return;
    final nl = NetBirdL10n.of(context);
    final l = AppLocalizations.of(context)!;
    final name = nameController.text.trim();
    final mgmt = managementUrlController.text.trim();
    if (name.isEmpty) {
      emit(state.copyWith(error: nl.nameRequiredError));
      return;
    }
    if (!_isValidHttpUrl(mgmt)) {
      emit(state.copyWith(error: nl.invalidUrlError));
      return;
    }
    int? mtu;
    final rawMtu = mtuController.text.trim();
    if (rawMtu.isNotEmpty) {
      mtu = int.tryParse(rawMtu);
      if (mtu == null || mtu < 576 || mtu > 65535) {
        emit(state.copyWith(error: nl.invalidMtuError));
        return;
      }
    }
    final hasSetupKey = setupKeyController.text.trim().isNotEmpty;
    final hasPrivateKey = privateKeyController.text.trim().isNotEmpty;
    if (state.authMethod == NetBirdAuthMethod.setupKey && !hasSetupKey) {
      emit(state.copyWith(error: nl.credentialsRequiredError));
      return;
    }
    if (state.authMethod != NetBirdAuthMethod.setupKey && !hasPrivateKey) {
      emit(state.copyWith(error: nl.credentialsRequiredError));
      return;
    }

    final base = state.loadedDraft ?? const NetBirdServerDraft();
    final draft = NetBirdServerDraft(
      id: serverId,
      original: base.original,
      name: name,
      managementUrl: mgmt,
      deviceName: deviceNameController.text.trim(),
      authMethod: state.authMethod,
      setupKey: setupKeyController.text.trim(),
      privateKey: privateKeyController.text.trim(),
      preSharedKey: preSharedKeyController.text.trim(),
      mtu: mtu,
      lazyConnection: state.lazyConnection,
      natExternalIPs: base.natExternalIPs,
      logLevel: base.logLevel,
      dnsRouterInterval: base.dnsRouterInterval,
    );

    emit(state.copyWith(saving: true, clearError: true));
    try {
      final savedId = await _service.save(
        draft,
        confirmReconnect: () => isPageActive && context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l.prototypeApplyChange,
                content: l.prototypeReconnectNotice,
                confirmLabel: l.prototypeApplyAndReconnect,
              )
            : Future.value(false),
      );
      if (!isPageActive) return;
      emit(state.copyWith(saving: false));
      if (savedId != null && context.mounted) {
        ContextAlert.showToast(context, l.prototypeSettingsSaved);
        Navigator.of(context).pop(savedId);
      }
    } catch (error) {
      if (!isPageActive) return;
      emit(
        state.copyWith(
          saving: false,
          error: appFailureMessage(l, error, operation: l.buttonSaveFailed),
        ),
      );
    }
  }

  static bool _isValidHttpUrl(String raw) {
    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  @override
  void disposePageResources() {
    final sessionId = state.activeSessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      unawaited(_hostApi.netbirdCancelOAuth(sessionId).catchError((_) {}));
    }
    nameController.dispose();
    managementUrlController.dispose();
    deviceNameController.dispose();
    setupKeyController.dispose();
    privateKeyController.dispose();
    preSharedKeyController.dispose();
    mtuController.dispose();
  }
}
