import 'package:flutter/material.dart';

/// A horizontal scrolling chip bar for room selection featuring
/// smooth animated glows and device count badges.
class RoomSelector extends StatelessWidget {
  const RoomSelector({
    super.key,
    required this.rooms,
    required this.selectedRoom,
    required this.onRoomSelected,
    this.roomDeviceCounts,
  });

  final List<String> rooms;
  final String selectedRoom;
  final ValueChanged<String> onRoomSelected;
  final Map<String, int>? roomDeviceCounts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28 + MediaQuery.textScalerOf(context).scale(20),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rooms.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final room = rooms[index];
          final isSelected = room == selectedRoom;
          final count = roomDeviceCounts?[room];

          return _RoomChip(
            room: room,
            isSelected: isSelected,
            count: count,
            onTap: () => onRoomSelected(room),
          );
        },
      ),
    );
  }
}

class _RoomChip extends StatelessWidget {
  const _RoomChip({
    required this.room,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  final String room;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
              : Theme.of(context).colorScheme.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (count != null) ...[
                    SizedBox(width: 8),
                    AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.45)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
