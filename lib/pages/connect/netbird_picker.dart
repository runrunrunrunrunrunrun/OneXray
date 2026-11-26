import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/netbird/l10n.dart';
import 'package:onexray/pages/shared/widgets/page_help.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/servers/catalog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NetBirdOverlayChoice {
  const NetBirdOverlayChoice({this.id, this.clear = false});

  final int? id;
  final bool clear;
}

class NetBirdOverlayPicker extends StatelessWidget {
  const NetBirdOverlayPicker({
    super.key,
    required this.nodes,
    required this.catalog,
    required this.selectedId,
  });

  final List<CoreConfigData> nodes;
  final ServerCatalog catalog;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final nl = NetBirdL10n.of(context);
    final palette = ColorManager.palette(context);
    void choose(NetBirdOverlayChoice choice) =>
        Navigator.of(context).pop(choice);

    Widget option({
      required String title,
      String? detail,
      required bool active,
      required IconData icon,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? palette.selectedSurface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          side: active
              ? BorderSide(color: palette.primary.withValues(alpha: .2))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          selected: active,
          button: true,
          child: ListTile(
            minTileHeight: 56,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: Icon(
              icon,
              size: 20,
              color: active ? palette.primaryText : palette.mutedForeground,
            ),
            title: Text(
              title,
              style:
                  (active
                          ? AppTypography.control
                          : AppTypography.serverNodeTitle)
                      .copyWith(
                        color: active
                            ? palette.primaryText
                            : palette.foreground,
                      ),
            ),
            subtitle: detail == null
                ? null
                : Text(
                    detail,
                    style: AppTypography.supporting.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
            trailing: active
                ? Icon(
                    LucideIcons.circleCheck,
                    color: palette.foreground,
                    size: 18,
                  )
                : const SizedBox(width: 18),
            onTap: onTap,
          ),
        ),
      ),
    );

    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(
        MediaQuery.sizeOf(context).width < 640 ? 0 : 8,
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      nl.parallelTitle,
                      style: AppTypography.dialogTitle,
                    ),
                  ),
                  PageHelpButton(
                    title: nl.parallelTitle,
                    messages: [nl.parallelHelp],
                  ),
                  IconButton(
                    tooltip: l.prototypeClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                nl.parallelSubtitle,
                style: AppTypography.supporting.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  option(
                    title: nl.parallelOff,
                    active: selectedId == null,
                    icon: LucideIcons.circleX,
                    onTap: () => choose(
                      const NetBirdOverlayChoice(clear: true),
                    ),
                  ),
                  if (nodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        nl.parallelEmpty,
                        style: AppTypography.supporting.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    )
                  else
                    for (final row in nodes)
                      option(
                        title: catalog.display(row).name,
                        detail: catalog.display(row).protocol,
                        active: selectedId == row.id,
                        icon: LucideIcons.network,
                        onTap: () => choose(NetBirdOverlayChoice(id: row.id)),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ShadButton.outline(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.prototypeCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
