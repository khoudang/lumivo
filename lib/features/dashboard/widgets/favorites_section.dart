import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD572).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFD572),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              key: const Key('favorites_count_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD572).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFD572).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                '${favoriteDevices.length}',
                style: const TextStyle(
                  color: Color(0xFFFFD572),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            if (favoriteDevices.isNotEmpty)
              Flexible(
                child: Text(
                  dragText,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Empty state vs Reorderable list
        if (favoriteDevices.isEmpty)
          _buildEmptyState(l10n)
        else
          _buildFavoritesList(context),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations? l10n) {
    final emptyDesc = l10n?.noFavoritesPinned ??
        'No favorite devices pinned yet. Long press or tap settings on any device to add to favorites.';
    return Container(
      key: const Key('favorites_empty_state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Icon(
              Icons.star_border_rounded,
              color: AppColors.muted,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            emptyDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(BuildContext context) {
    return SizedBox(
      height: 144,
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
              margin: const EdgeInsets.only(right: 12, bottom: 4),
              child: _buildFavoriteCard(device),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(SmartDevice device) {
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isOn
                ? const LinearGradient(
                    colors: [Color(0xFF282444), Color(0xFF171D29)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [AppColors.surfaceElevated, AppColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOn
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.surfaceBorder,
              width: 1.2,
            ),
            boxShadow: AppShadows.cardGlow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Device Icon + Favorite Star Badge + Toggle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOn
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _deviceIcon(device),
                      color: isOn ? AppColors.primary : AppColors.muted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Star favorite indicator badge
                  Semantics(
                    label: 'Favorite star',
                    child: Container(
                      key: Key('favorite_badge_${device.id}'),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD572).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFD572),
                        size: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: '${isOn ? 'Turn off' : 'Turn on'} ${device.name}',
                    toggled: isOn,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
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
                            color: isOn ? AppColors.green : AppColors.mutedDark,
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      device.roomId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
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
