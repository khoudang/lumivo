import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';

import '../../../core/models/room.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({
    super.key,
    this.onRoomSelected,
  });

  final ValueChanged<String>? onRoomSelected;

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  static const Map<String, (IconData, String)> roomIconMap = {
    'living_room': (Icons.weekend_rounded, 'Living Room'),
    'bedroom': (Icons.bed_rounded, 'Bedroom'),
    'kitchen': (Icons.kitchen_rounded, 'Kitchen'),
    'office': (Icons.desk_rounded, 'Office'),
    'bathroom': (Icons.bathtub_rounded, 'Bathroom'),
    'balcony': (Icons.balcony_rounded, 'Balcony'),
  };

  void _showAddRoomDialog([AppLocalizations? l10n]) {
    final nameController = TextEditingController();
    String selectedIcon = 'living_room';
    final titleText = l10n?.addNewRoom ?? 'Add New Room';
    final nameLabel = l10n?.roomName ?? 'Room Name';
    final cancelLabel = l10n?.cancel ?? 'Cancel';
    final addLabel =
        l10n?.locale.languageCode == 'vi' ? 'Thêm phòng' : 'Add Room';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.add_home_rounded,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Master Bedroom, Gym',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n?.selectRoomIcon ?? 'Select Room Icon',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: roomIconMap.entries.map((entry) {
                      final isSelected = selectedIcon == entry.key;
                      return InkWell(
                        onTap: () =>
                            setDialogState(() => selectedIcon = entry.key),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.18)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                entry.value.$1,
                                size: 18,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entry.value.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(cancelLabel),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final currentHome = ref.read(currentHomeProvider);
                    ref.read(roomsProvider.notifier).addRoom(
                          Room(
                            id: 'room-${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            iconName: selectedIcon,
                            homeId: currentHome.id,
                          ),
                        );
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Room "$name" added'),
                        backgroundColor: AppColors.green,
                      ),
                    );
                  }
                },
                child: Text(addLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteRoom(
      BuildContext context, WidgetRef ref, Room room) async {
    final l10n = ref.read(appLocalizationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.deleteRoom),
        content: Text(l10n.confirmDeleteRoomBody(room.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_room_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(roomsProvider.notifier).deleteRoom(room.id);
      if (context.mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${room.name} deleted'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _openRoomDevices(Room room, List<SmartDevice> devices) {
    final roomName = room.name;
    if (widget.onRoomSelected != null) {
      widget.onRoomSelected!(roomName);
      return;
    }

    final roomDevices = devices.where((d) => d.roomId == roomName).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          roomName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${roomDevices.length} devices',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const Key('delete_room_button'),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger, size: 20),
                        tooltip: 'Delete Room',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: () => _confirmDeleteRoom(context, ref, room),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (roomDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'No devices assigned to this room yet.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: roomDevices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final dev = roomDevices[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.surfaceBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  dev.isOn
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: dev.isOn
                                      ? AppColors.green
                                      : AppColors.mutedDark,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dev.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        dev.isOn ? 'Active' : 'Off',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHome = ref.watch(currentHomeProvider);
    final allRooms = ref.watch(roomsProvider);
    final rooms = allRooms.where((r) => r.homeId == currentHome.id).toList();
    final devicesAsync = ref.watch(devicesProvider);
    final allDevices = devicesAsync.valueOrNull ?? const [];
    final devices =
        allDevices.where((d) => d.homeId == currentHome.id).toList();
    final l10n = ref.watch(appLocalizationsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final int crossAxisCount = screenWidth >= 800
            ? 3
            : screenWidth >= 520
                ? 2
                : 1;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth > 600 ? 32 : 20,
                  20,
                  screenWidth > 600 ? 32 : 20,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.rooms.toUpperCase(),
                              style: const TextStyle(
                                letterSpacing: 1.5,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.spacesAndZones,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: l10n.addNewRoom,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ElevatedButton.icon(
                            key: const Key('add_room_button'),
                            onPressed: () => _showAddRoomDialog(l10n),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: Text(l10n.locale.languageCode == 'vi'
                                ? 'Thêm phòng'
                                : 'Add Room'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth > 600 ? 32 : 20,
                  8,
                  screenWidth > 600 ? 32 : 20,
                  28,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: crossAxisCount == 1 ? 2.2 : 1.35,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final room = rooms[index];
                      final roomDevices =
                          devices.where((d) => d.roomId == room.name).toList();
                      final totalCount = roomDevices.length;
                      final activeCount =
                          roomDevices.where((d) => d.isOn).length;
                      final iconData = roomIconMap[room.iconName]?.$1 ??
                          Icons.weekend_rounded;

                      return _RoomCard(
                        room: room,
                        iconData: iconData,
                        totalDevices: totalCount,
                        activeDevices: activeCount,
                        onTap: () => _openRoomDevices(room, devices),
                      );
                    },
                    childCount: rooms.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.iconData,
    required this.totalDevices,
    required this.activeDevices,
    required this.onTap,
  });

  final Room room;
  final IconData iconData;
  final int totalDevices;
  final int activeDevices;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeDevices > 0;

    return Semantics(
      button: true,
      label: '${room.name}, $totalDevices devices',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hasActive
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.surfaceBorder,
            width: hasActive ? 1.2 : 1.0,
          ),
          boxShadow: hasActive ? AppShadows.cardGlow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasActive
                              ? AppColors.primary.withValues(alpha: 0.16)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasActive
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          iconData,
                          size: 22,
                          color:
                              hasActive ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: hasActive
                              ? AppColors.green.withValues(alpha: 0.14)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasActive
                                ? AppColors.green.withValues(alpha: 0.3)
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasActive) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              hasActive ? '$activeDevices On' : 'All Off',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: hasActive
                                    ? AppColors.green
                                    : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          room.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$totalDevices ${totalDevices == 1 ? 'device' : 'devices'} · $activeDevices active',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
