import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/components/common_widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).appearance,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_outlined),
                  title: Text(AppLocalizations.of(context).language),
                  subtitle: Text(
                    locale.languageCode == 'ar'
                        ? AppLocalizations.of(context).arabic
                        : AppLocalizations.of(context).english,
                  ),
                ),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'ar',
                      label: Text(AppLocalizations.of(context).arabic),
                      icon: const Icon(Icons.format_textdirection_r_to_l),
                    ),
                    ButtonSegment(
                      value: 'en',
                      label: Text(AppLocalizations.of(context).english),
                      icon: const Icon(Icons.format_textdirection_l_to_r),
                    ),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (value) => ref
                      .read(localeProvider.notifier)
                      .setLocale(Locale(value.first)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).database,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(AppLocalizations.of(context).seedData),
                  subtitle: Text(
                    AppLocalizations.of(context).backupDescription,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).about,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text(AppLocalizations.of(context).appTitle),
                  subtitle: Text(AppLocalizations.of(context).appVersion),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
