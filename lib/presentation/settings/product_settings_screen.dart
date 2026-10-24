import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/product_preferences.dart';

class ProductSettingsScreen extends StatefulWidget {
  const ProductSettingsScreen({super.key});
  @override
  State<ProductSettingsScreen> createState() => _ProductSettingsScreenState();
}

class _ProductSettingsScreenState extends State<ProductSettingsScreen> {
  bool _saving = false;
  Future<void> _save(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).preferenceSaveFailed),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), prefs = ProductPreferences.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (prefs.loadFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(l.preferencesLoadFailed),
            ),
          Text(l.language, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ar', label: Text(l.arabic)),
              ButtonSegment(value: 'en', label: Text(l.english)),
            ],
            selected: {prefs.locale.languageCode},
            onSelectionChanged: _saving
                ? null
                : (v) => _save(() => prefs.setLanguage(v.single)),
          ),
          const SizedBox(height: 28),
          Text(l.appearance, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final entry in [
            MapEntry(ThemeMode.system, l.system),
            MapEntry(ThemeMode.light, l.light),
            MapEntry(ThemeMode.dark, l.dark),
          ])
            ListTile(
              title: Text(entry.value),
              leading: Icon(
                entry.key == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : entry.key == ThemeMode.light
                    ? Icons.light_mode_outlined
                    : Icons.settings_brightness,
              ),
              trailing: prefs.themeMode == entry.key
                  ? const Icon(Icons.check)
                  : null,
              onTap: _saving
                  ? null
                  : () => _save(() => prefs.setTheme(entry.key)),
            ),
          if (_saving) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
