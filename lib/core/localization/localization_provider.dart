import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/state/user_profile_notifier.dart';
import 'app_localizations.dart';

/// Active AppLocalizations provider that automatically reacts to language changes
/// in [userProfileProvider] ('en' | 'vi').
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final profile = ref.watch(userProfileProvider);
  final langCode = (profile.language == 'vi') ? 'vi' : 'en';
  return AppLocalizations(Locale(langCode));
});
