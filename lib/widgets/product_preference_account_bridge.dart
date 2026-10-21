import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/product_preferences.dart';
import '../services/supabase_service.dart';

/// Self-owned presentation metadata only. Not an authorization source.
class ProductPreferenceAccountBridge extends StatefulWidget {
  const ProductPreferenceAccountBridge({super.key, required this.child});
  final Widget child;
  @override
  State<ProductPreferenceAccountBridge> createState() => _BridgeState();
}

class _BridgeState extends State<ProductPreferenceAccountBridge> {
  StreamSubscription<AuthState>? _subscription;
  bool _loadFailed = false;
  @override
  void initState() {
    super.initState();
    final client = SupabaseService.instance.client;
    ProductPreferences.instance.accountWriter = (owner, values) async {
      if (!mounted || client.auth.currentUser?.id != owner) return;
      await client.auth.updateUser(UserAttributes(data: values));
    };
    _subscription = client.auth.onAuthStateChange.listen((state) {
      unawaited(_load(state.session?.user));
    });
    unawaited(_load(client.auth.currentUser));
  }

  Future<void> _load(User? user) async {
    try {
      await ProductPreferences.instance.useAccount(
        user?.id,
        user?.userMetadata,
      );
      if (mounted && _loadFailed) setState(() => _loadFailed = false);
    } catch (_) {
      if (mounted) {
        ProductPreferences.instance.loadFailed = true;
        setState(() => _loadFailed = true);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    ProductPreferences.instance.accountWriter = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
