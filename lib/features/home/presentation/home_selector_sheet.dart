import '../state/homes_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/home.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

class HomeSelectorSheet extends ConsumerWidget {
  const HomeSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HomeSelectorSheet(),
    );
  }

  void _showAddHomeDialog(BuildContext context, WidgetRef ref) {
    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations.fromLanguageCode('en');
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final tariffCtrl = TextEditingController(text: '0.16');
    String selectedRole = 'Owner';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          title: Row(
            children: [
              Icon(Icons.add_home_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'Add New Home',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Home Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('add_home_name_input'),
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Vacation Villa',
                    hintStyle: const TextStyle(color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('add_home_address_input'),
                  controller: addressCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. 500 Sunset Blvd',
                    hintStyle: const TextStyle(color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tariff Rate (\$/kWh)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('add_home_tariff_input'),
                  controller: tariffCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '0.16',
                    hintStyle: const TextStyle(color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Role',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(l10n.owner),
                      selected: selectedRole == 'Owner',
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: selectedRole == 'Owner'
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedRole = 'Owner');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(l10n.member),
                      selected: selectedRole == 'Member',
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: selectedRole == 'Member'
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedRole = 'Member');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              key: const Key('confirm_add_home_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final address = addressCtrl.text.trim().isEmpty
                    ? '104 Lumivo Way'
                    : addressCtrl.text.trim();
                final tariff = double.tryParse(tariffCtrl.text.trim()) ?? 0.16;

                final newHome = Home(
                  id: 'home-${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  address: address,
                  role: selectedRole,
                  isCurrent: false,
                  tariffRate: tariff,
                );
                ref.read(homesProvider.notifier).addHome(newHome);
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.homeAdded(name)),
                    backgroundColor: AppColors.green,
                  ),
                );
              },
              child: Text(l10n.addNewHome),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHomeDialog(BuildContext context, WidgetRef ref, Home home) {
    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations.fromLanguageCode('en');
    final nameCtrl = TextEditingController(text: home.name);
    final addressCtrl = TextEditingController(text: home.address);
    final tariffCtrl = TextEditingController(text: home.tariffRate.toString());
    String selectedRole = home.role;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'Edit Home',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Home Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_home_name_input'),
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_home_address_input'),
                  controller: addressCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tariff Rate (\$/kWh)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_home_tariff_input'),
                  controller: tariffCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              key: const Key('confirm_edit_home_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final address = addressCtrl.text.trim().isEmpty
                    ? home.address
                    : addressCtrl.text.trim();
                final tariff =
                    double.tryParse(tariffCtrl.text.trim()) ?? home.tariffRate;

                final updated = home.copyWith(
                  name: name,
                  address: address,
                  tariffRate: tariff,
                  role: selectedRole,
                );
                ref.read(homesProvider.notifier).updateHome(updated);
                Navigator.of(dialogCtx).pop();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteHomeConfirmation(
      BuildContext context, WidgetRef ref, Home home) {
    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations.fromLanguageCode('en');
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text(
              l10n.deleteHome,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${home.name}"? This removes all associated configurations and cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: Key('confirm_delete_home_${home.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              ref.read(homesProvider.notifier).deleteHome(home.id);
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.homeDeleted(home.name)),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homesState = ref.watch(homesProvider);
    final homes = homesState.homes;
    final currentHome = ref.watch(currentHomeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Sheet Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Switch Home',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage active property & multi-home control',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.muted, size: 20),
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Active Home Indicator Card
                Container(
                  key: const Key('active_home_banner'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF201D38), Color(0xFF171D29)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    currentHome.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    currentHome.role,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              currentHome.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${currentHome.tariffRate.toStringAsFixed(3)}/kWh',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Available Homes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Available Homes List
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: homes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final home = homes[index];
                      final isCurrent = home.id == currentHome.id;

                      return Container(
                        key: Key('home_item_${home.id}'),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.surfaceElevated
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.primary.withValues(alpha: 0.6)
                                : AppColors.surfaceBorder,
                            width: isCurrent ? 1.2 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            leading: Icon(
                              isCurrent
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isCurrent
                                  ? AppColors.primary
                                  : AppColors.muted,
                              size: 20,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    home.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isCurrent
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: home.role == 'Owner'
                                        ? AppColors.primary
                                            .withValues(alpha: 0.15)
                                        : AppColors.surfaceBorder,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    home.role,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: home.role == 'Owner'
                                          ? AppColors.primary
                                          : AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${home.address} • \$${home.tariffRate.toStringAsFixed(2)}/kWh',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: Key('edit_home_${home.id}'),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18, color: AppColors.muted),
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _showEditHomeDialog(context, ref, home),
                                ),
                                if (homes.length > 1)
                                  IconButton(
                                    key: Key('delete_home_${home.id}'),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.danger),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _showDeleteHomeConfirmation(
                                            context, ref, home),
                                  ),
                              ],
                            ),
                            onTap: () {
                              ref
                                  .read(homesProvider.notifier)
                                  .switchHome(home.id);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // Add New Home Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('add_new_home_button'),
                    icon: const Icon(Icons.add_rounded,
                        color: AppColors.primary, size: 20),
                    label: const Text(
                      '+ Add New Home',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _showAddHomeDialog(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
