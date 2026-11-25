import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/servers/form_page.dart';
import 'package:onexray/pages/servers/netbird/controller.dart';
import 'package:onexray/pages/servers/netbird/l10n.dart';
import 'package:onexray/pages/shared/widgets/app_switch.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/pages/shared/widgets/setting_row.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/servers/netbird.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NetBirdEditorPage extends StatelessWidget {
  final int? serverId;
  final NetBirdEditorController Function()? createController;

  const NetBirdEditorPage({super.key, this.serverId, this.createController});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final controller =
          createController?.call() ??
          NetBirdEditorController(serverId: serverId);
      return controller..initialize();
    },
    child: BlocBuilder<NetBirdEditorController, NetBirdEditorState>(
      builder: (context, state) {
        final controller = context.read<NetBirdEditorController>();
        final nl = NetBirdL10n.of(context);
        final palette = ColorManager.palette(context);
        return ServerFormPage(
          title: serverId == null ? nl.addNetBirdNode : nl.editNetBirdNode,
          onClose: () => Navigator.of(context).pop(),
          actions: [
            FilledButton(
              key: const ValueKey('netbird-save-button'),
              onPressed: state.busy ? null : () => controller.save(context),
              child: ButtonProgress(
                busy: state.saving,
                child: Text(nl.saveButton),
              ),
            ),
          ],
          body: state.loading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.destructiveSurface,
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                            border: Border.all(color: palette.destructive),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                LucideIcons.circleAlert,
                                size: 18,
                                color: palette.destructive,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  state.error!,
                                  style: AppTypography.supporting.copyWith(
                                    color: palette.destructive,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ServerFormSection(
                      title: nl.basicSection,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LabeledField(
                              label: nl.nameLabel,
                              controller: controller.nameController,
                              hint: nl.nameHint,
                              enabled: !state.busy,
                            ),
                            const SizedBox(height: 12),
                            _LabeledField(
                              label: nl.managementUrlLabel,
                              controller: controller.managementUrlController,
                              hint: nl.managementUrlHint,
                              enabled: !state.busy && !state.oauthRunning,
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 12),
                            _LabeledField(
                              label: nl.deviceNameLabel,
                              controller: controller.deviceNameController,
                              hint: nl.deviceNameHint,
                              enabled: !state.busy && !state.oauthRunning,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ServerFormSection(
                      title: nl.authSection,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _AuthChoiceButton(
                                  label: nl.authOAuth,
                                  selected:
                                      state.authMethod ==
                                      NetBirdAuthMethod.oauth,
                                  onPressed: state.busy
                                      ? null
                                      : () => controller.setAuthMethod(
                                          NetBirdAuthMethod.oauth,
                                        ),
                                ),
                                _AuthChoiceButton(
                                  label: nl.authSetupKey,
                                  selected:
                                      state.authMethod ==
                                      NetBirdAuthMethod.setupKey,
                                  onPressed: state.busy
                                      ? null
                                      : () => controller.setAuthMethod(
                                          NetBirdAuthMethod.setupKey,
                                        ),
                                ),
                                _AuthChoiceButton(
                                  label: nl.authPrivateKey,
                                  selected:
                                      state.authMethod ==
                                      NetBirdAuthMethod.privateKey,
                                  onPressed: state.busy
                                      ? null
                                      : () => controller.setAuthMethod(
                                          NetBirdAuthMethod.privateKey,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (state.authMethod == NetBirdAuthMethod.setupKey)
                              _LabeledField(
                                label: nl.setupKeyLabel,
                                controller: controller.setupKeyController,
                                hint: nl.setupKeyHint,
                                enabled: !state.busy,
                                obscureText: true,
                              )
                            else if (state.authMethod ==
                                NetBirdAuthMethod.privateKey)
                              _LabeledField(
                                label: nl.privateKeyLabel,
                                controller: controller.privateKeyController,
                                hint: nl.privateKeyHint,
                                enabled: !state.busy,
                                obscureText: true,
                              )
                            else
                              _OAuthPanel(controller: controller, state: state),
                          ],
                        ),
                      ),
                    ),
                    ServerFormSection(
                      title: nl.advancedSection,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SettingRow(
                            title: nl.advancedSection,
                            leading: Icon(
                              state.advancedExpanded
                                  ? LucideIcons.chevronDown
                                  : LucideIcons.chevronRightDir,
                              size: 18,
                            ),
                            onTap: controller.toggleAdvanced,
                          ),
                          if (state.advancedExpanded) ...[
                            Divider(height: 1, color: palette.border),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _LabeledField(
                                    label: nl.preSharedKeyLabel,
                                    controller:
                                        controller.preSharedKeyController,
                                    hint: nl.preSharedKeyHint,
                                    enabled: !state.busy,
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _LabeledField(
                                    label: nl.mtuLabel,
                                    controller: controller.mtuController,
                                    hint: nl.mtuHint,
                                    enabled: !state.busy,
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: palette.border),
                            SettingRow(
                              title: nl.lazyConnectionTitle,
                              subtitle: nl.lazyConnectionSubtitle,
                              trailing: AppSwitch(
                                value: state.lazyConnection,
                                enabled: !state.busy,
                                onChanged: controller.setLazyConnection,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    ),
  );
}

class _OAuthPanel extends StatelessWidget {
  const _OAuthPanel({required this.controller, required this.state});

  final NetBirdEditorController controller;
  final NetBirdEditorState state;

  @override
  Widget build(BuildContext context) {
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    final hasKey = controller.privateKeyController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('netbird-oauth-start'),
              onPressed: state.busy || state.oauthRunning
                  ? null
                  : () => controller.startOAuth(context),
              icon: state.oauthRunning
                  ? const ButtonProgressIndicator(size: 16)
                  : const Icon(LucideIcons.keyRound, size: 17),
              label: Text(hasKey ? nl.oauthReauthorize : nl.oauthSignIn),
            ),
            if (state.oauthRunning)
              OutlinedButton(
                onPressed: controller.cancelOAuth,
                child: Text(nl.oauthCancel),
              ),
          ],
        ),
        if (state.oauthRunning) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.secondary,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.oauthFlowType == 'pkce'
                      ? nl.oauthWaitingPkce
                      : (state.userCode ?? '').isNotEmpty
                      ? nl.oauthWaitingDevice
                      : nl.oauthWaiting,
                  style: AppTypography.rowTitle.copyWith(
                    color: palette.foreground,
                  ),
                ),
                if ((state.userCode ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    nl.oauthUserCode,
                    style: AppTypography.supporting.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          state.userCode!,
                          style: AppTypography.metric.copyWith(
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            controller.copyUserCode(context, state.userCode!),
                        icon: const Icon(LucideIcons.copy, size: 16),
                        label: Text(nl.oauthCopyCode),
                      ),
                    ],
                  ),
                ],
                if ((state.authUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    state.authUrl!,
                    style: AppTypography.code.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          controller.openAuthUrl(context, state.authUrl!),
                      icon: const Icon(LucideIcons.globe, size: 16),
                      label: Text(nl.oauthOpenUrl),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if (hasKey) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.runningSurface,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: palette.running),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.circleCheck,
                  size: 18,
                  color: palette.runningText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        nl.oauthReadyTitle,
                        style: AppTypography.rowTitle.copyWith(
                          color: palette.runningText,
                        ),
                      ),
                      if ((state.authorizedPeerIp ?? '').isNotEmpty ||
                          (state.authorizedFqdn ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if ((state.authorizedPeerIp ?? '').isNotEmpty)
                              state.authorizedPeerIp!,
                            if ((state.authorizedFqdn ?? '').isNotEmpty)
                              state.authorizedFqdn!,
                          ].join(' · '),
                          style: AppTypography.supporting.copyWith(
                            color: palette.foreground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Text(
            nl.oauthMissingKeyHint,
            style: AppTypography.supporting.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

class _AuthChoiceButton extends StatelessWidget {
  const _AuthChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTypography.fieldLabel.copyWith(color: palette.foreground),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
