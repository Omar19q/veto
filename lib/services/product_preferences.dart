import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Presentation settings only; account persistence never carries role or money.
class ProductPreferences extends ChangeNotifier {
  ProductPreferences();
  static final instance = ProductPreferences();
  Locale _locale = const Locale('ar');
  ThemeMode _theme = ThemeMode.system;
  Locale get locale => _locale;
  ThemeMode get themeMode => _theme;
  bool loadFailed = false;
  String? _accountId;
  int _accountRevision = 0;
  Future<void> Function(String owner, Map<String, dynamic> values)?
  accountWriter;

  Future<void> useAccount(String? owner, Map<String, dynamic>? metadata) async {
    final revision = ++_accountRevision;
    _accountId = owner;
    if (owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _accountRevision || _accountId != owner) return;
    final language =
        metadata?['veto_product_language'] ??
        prefs.getString('product.account.$owner.language');
    final theme =
        metadata?['veto_product_theme'] ??
        prefs.getString('product.account.$owner.theme');
    if (language == 'ar' || language == 'en')
      _locale = Locale(language as String);
    if (theme == 'light' || theme == 'dark' || theme == 'system') {
      _theme = ThemeMode.values.byName(theme as String);
    }
    notifyListeners();
  }

  Future<void> _saveAccount(String? owner, String key, String value) async {
    if (owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (_accountId != owner) return;
    if (!await prefs.setString('product.account.$owner.$key', value)) {
      throw StateError('account_preference_not_saved');
    }
    if (_accountId != owner) return;
    await accountWriter?.call(owner, {'veto_product_$key': value});
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locale = Locale(
        prefs.getString('product.language') == 'en' ? 'en' : 'ar',
      );
      _theme = switch (prefs.getString('product.theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.system,
      };
      loadFailed = false;
    } catch (_) {
      // Presentation storage must not prevent boot or change Auth/session state.
      loadFailed = true;
      _locale = const Locale('ar');
      _theme = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    if (!const ['ar', 'en'].contains(value)) throw ArgumentError.value(value);
    final owner = _accountId;
    final revision = _accountRevision;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('product.language', value))
      throw StateError('preference_not_saved');
    if (revision != _accountRevision) return;
    _locale = Locale(value);
    loadFailed = false;
    notifyListeners();
    await _saveAccount(owner, 'language', value);
  }

  Future<void> setTheme(ThemeMode value) async {
    final owner = _accountId;
    final revision = _accountRevision;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('product.theme', value.name))
      throw StateError('preference_not_saved');
    if (revision != _accountRevision) return;
    _theme = value;
    loadFailed = false;
    notifyListeners();
    await _saveAccount(owner, 'theme', value.name);
  }
}
