import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/device_card.dart';
import '../../device_detail/presentation/device_detail_screen.dart';

class DeviceSearchScreen extends ConsumerStatefulWidget {
  const DeviceSearchScreen({super.key});

  @override
  ConsumerState<DeviceSearchScreen> createState() => _DeviceSearchScreenState();
}

class _DeviceSearchScreenState extends ConsumerState<DeviceSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  DeviceType? _selectedType;
  String _selectedStatus = 'all'; // 'all', 'online', 'offline'
  String _sortCriteria = 'name'; // 'name', 'room', 'recent'
  final Set<String> _pending = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedType = null;
      _selectedStatus = 'all';
      _sortCriteria = 'name';
    });
  }

  Future<void> _toggleDevice(SmartDevice device) async {
    if (_pending.contains(device.id)) return;
    setState(() => _pending.add(device.id));

    await ref.read(deviceRepositoryProvider).sendCommand(
          DeviceCommand(
            requestId: 'search-cmd-${DateTime.now().millisecondsSinceEpoch}',
            deviceId: device.id,
            type: DeviceCommandType.setPower,
            value: !device.isOn,
          ),
        );

    if (mounted) {
      setState(() => _pending.remove(device.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final allDevices = devicesAsync.valueOrNull ?? [];

    final query = _searchController.text.trim().toLowerCase();

    // 1. Filter
    var filtered = allDevices.where((device) {
      if (query.isNotEmpty) {
        final matchesName = device.name.toLowerCase().contains(query);
        final matchesRoom = device.roomId.toLowerCase().contains(query);
        if (!matchesName && !matchesRoom) return false;
      }
      if (_selectedType != null && device.type != _selectedType) {
        return false;
      }
      if (_selectedStatus == 'online' &&
          device.connection != DeviceConnection.online) {
        return false;
      }
      if (_selectedStatus == 'offline' &&
          device.connection == DeviceConnection.online) {
        return false;
      }
      return true;
    }).toList();

    // 2. Sort
    switch (_sortCriteria) {
      case 'room':
        filtered.sort((a, b) {
          final cmp = a.roomId.toLowerCase().compareTo(b.roomId.toLowerCase());
          return cmp != 0
              ? cmp
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case 'recent':
        filtered.sort((a, b) => b.id.compareTo(a.id));
        break;
      case 'name':
      default:
        filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    final hasActiveFilters = query.isNotEmpty ||
        _selectedType != null ||
        _selectedStatus != 'all' ||
        _sortCriteria != 'name';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          l10n.searchDevices,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (hasActiveFilters)
            TextButton(
              key: const Key('clear_search_filters_button'),
              onPressed: _clearFilters,
              child: Text(
                l10n.clearFilters,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isNarrow = screenWidth < 360;

            return Column(
              children: [
                // Global Search Input
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 12 : 20,
                    8,
                    isNarrow ? 12 : 20,
                    12,
                  ),
                  child: TextField(
                    key: const Key('global_device_search_bar'),
                    controller: _searchController,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchDevices,
                      hintStyle: const TextStyle(
                          color: AppColors.textDisabled, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: AppColors.muted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Controls row: Sort dropdown + Status Chips
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 20),
                  child: Row(
                    children: [
                      // Sort Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('search_sort_dropdown'),
                            value: _sortCriteria,
                            dropdownColor: AppColors.surfaceElevated,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primary, size: 18),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'name', child: Text(l10n.sortName)),
                              DropdownMenuItem(
                                  value: 'room', child: Text(l10n.sortRoom)),
                              DropdownMenuItem(
                                  value: 'recent',
                                  child: Text(l10n.sortRecent)),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _sortCriteria = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status filter chips
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildStatusChip('all', l10n.allStatuses,
                                  const Key('filter_status_all')),
                              const SizedBox(width: 6),
                              _buildStatusChip('online', l10n.devicesOnline,
                                  const Key('filter_status_online')),
                              const SizedBox(width: 6),
                              _buildStatusChip('offline', l10n.devicesOffline,
                                  const Key('filter_status_offline')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Device Type Filter Chips
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 20),
                    children: [
                      _buildTypeChip(
                          null, l10n.allTypes, const Key('filter_type_all')),
                      const SizedBox(width: 6),
                      _buildTypeChip(DeviceType.light, l10n.light,
                          const Key('filter_type_light')),
                      const SizedBox(width: 6),
                      _buildTypeChip(DeviceType.fan, l10n.fan,
                          const Key('filter_type_fan')),
                      const SizedBox(width: 6),
                      _buildTypeChip(DeviceType.ac, l10n.climateAc,
                          const Key('filter_type_ac')),
                      const SizedBox(width: 6),
                      _buildTypeChip(DeviceType.socket, l10n.socket,
                          const Key('filter_type_socket')),
                      const SizedBox(width: 6),
                      _buildTypeChip(DeviceType.curtain, l10n.curtain,
                          const Key('filter_type_curtain')),
                      const SizedBox(width: 6),
                      _buildTypeChip(DeviceType.lock, l10n.smartLock,
                          const Key('filter_type_lock')),
                      const SizedBox(width: 6),
                      _buildTypeChip(DeviceType.sensor, l10n.sensor,
                          const Key('filter_type_sensor')),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Device Results List / Grid or Empty State
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(l10n)
                      : _buildDeviceResults(filtered, screenWidth),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String label, Key key) {
    final isSelected = _selectedStatus == status;
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedStatus = status),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(DeviceType? type, String label, Key key) {
    final isSelected = _selectedType == type;
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedType = type),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      key: const Key('search_empty_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noDevicesFound,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search query, type, or online status filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const Key('clear_search_filters_button_empty'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.clearFilters),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceResults(List<SmartDevice> devices, double availableWidth) {
    final int crossAxisCount;
    if (availableWidth >= 880) {
      crossAxisCount = 4;
    } else if (availableWidth >= 580) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = availableWidth < 340 ? 1 : 2;
    }

    const double spacing = 12;
    final double itemWidth =
        (availableWidth - ((crossAxisCount - 1) * spacing) - 40) /
            crossAxisCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final device in devices)
            SizedBox(
              width: itemWidth > 0 ? itemWidth : availableWidth - 40,
              child: DeviceCard(
                key: Key('device_card_${device.id}'),
                device: device,
                isBusy: _pending.contains(device.id),
                onToggle: () => _toggleDevice(device),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DeviceDetailScreen(device: device),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
