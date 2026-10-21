import 'package:shared_preferences/shared_preferences.dart';

/// A convenience choice only. Balances, holds and totals are never persisted.
class CustomerPaymentPreference {
  static const methods = {'cash', 'wallet', 'combined'};
  Future<String?> load(String account) async {
    final value = (await SharedPreferences.getInstance()).getString(
      'customer.payment.$account',
    );
    return methods.contains(value) ? value : null;
  }

  Future<void> save(String account, String method) async {
    if (!methods.contains(method)) throw ArgumentError.value(method);
    await (await SharedPreferences.getInstance()).setString(
      'customer.payment.$account',
      method,
    );
  }
}
