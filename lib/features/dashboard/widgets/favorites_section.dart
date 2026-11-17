import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/smart_device.dart';

class FavoritesSection extends StatelessWidget {
  const FavoritesSection({
    super.key,
    required this.favoriteDevices,
    this.onReorder,
    this.onDeviceTap,
    this.onDeviceToggle,
  });

  final List<SmartDevice> favoriteDevices;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(SmartDevice device)? onDeviceTap;
  final void Function(SmartDevice device)? onDeviceToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.favorites ?? 'Favorites';
    final dragText = l10n?.dragToReorder ?? 'Drag to reorder';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.star_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(width: 8),
            Container(
              key: Key('favorites_count_badge'),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                '${favoriteDevices.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (favoriteDevices.isNotEmpty)
              Text(
                dragText,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),

        SizedBox(height: 12),

        // Empty state vs Reorderable list
        if (favoriteDevices.isEmpty)
          _buildEmptyState(context, l10n)
        else
          _buildFavoritesList(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations? l10n) {
    final emptyDesc = l10n?.noFavoritesPinned ??
        'No favorite devices pinned yet. Long press or tap settings on any device to add to favorites.';
    return Container(
      key: Key('favorites_empty_state'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Icon(
              Icons.star_border_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ),
          SizedBox(height: 12),
          Text(
            emptyDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(BuildContext context) {
    return SizedBox(
      height: 144 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 2,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: favoriteDevices.length,
        buildDefaultDragHandles: false,
        // ignore: deprecated_member_use
        onReorder: (oldIndex, newIndex) {
          onReorder?.call(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final device = favoriteDevices[index];
          return ReorderableDragStartListener(
            key: Key('favorite_card_${device.id}'),
            index: index,
            child: Container(
              margin: EdgeInsets.only(right: 12, bottom: 4),
              child: _buildFavoriteCard(context, device),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, SmartDevice device) {
    final isOffline = device.connection == DeviceConnection.offline;
    final isOn = device.isOn && !isOffline;

    return Semantics(
      button: true,
      label: device.name,
      child: InkWell(
        onTap: () => onDeviceTap?.call(device),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 160,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isOn
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOn
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.outlineVariant,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Device Icon + Favorite Star Badge + Toggle
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOn
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _deviceIcon(device),
                      color: isOn
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 6),
                  // Star favorite indicator badge
                  Semantics(
                    label: 'Favorite star',
                    child: Container(
                      key: Key('favorite_badge_${device.id}'),
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 14,
                      ),
                    ),
                  ),
                  Spacer(),
                  Semantics(
                    button: true,
                    label: '${isOn ? 'Turn off' : 'Turn on'} ${device.name}',
                    toggled: isOn,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: 48, minHeight: 48),
                      child: Center(
                        child: GestureDetector(
                          key: Key('favorite_toggle_btn_${device.id}'),
                          onTap: isOffline
                              ? null
                              : () => onDeviceToggle?.call(device),
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            isOn
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_rounded,
                            size: 30,
                            color: isOn
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom info: Name & Room
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      device.roomId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _deviceIcon(SmartDevice device) {
    switch (device.type) {
      case DeviceType.light:
        return Icons.lightbulb_rounded;
      case DeviceType.fan:
        return Icons.mode_fan_off_outlined;
      case DeviceType.security:
        return Icons.shield_rounded;
      case DeviceType.ac:
        return Icons.ac_unit_rounded;
      case DeviceType.socket:
        return Icons.power_rounded;
      case DeviceType.curtain:
        return Icons.curtains_rounded;
      case DeviceType.lock:
        return Icons.lock_rounded;
      case DeviceType.sensor:
        return Icons.sensors_rounded;
    }
  }
}
