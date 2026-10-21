import 'dart:convert';
import '../../services/secure_draft_store.dart';
import '../../l10n/strings.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../services/market_checkout_backend.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

bool isValidMarketDeliveryCoordinates(dynamic latitude, dynamic longitude) =>
    latitude is num &&
    longitude is num &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

class VitoMarketCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> supermarket;
  final Map<String, Map<String, dynamic>> cart;
  final MarketCheckoutBackend? backend;

  const VitoMarketCheckoutScreen({
    super.key,
    required this.supermarket,
    required this.cart,
    this.backend,
  });

  @override
  State<VitoMarketCheckoutScreen> createState() =>
      _VitoMarketCheckoutScreenState();
}

class _VitoMarketCheckoutScreenState extends State<VitoMarketCheckoutScreen> {
  // Same 16 official letters already used by the trip pickup selector.
  static const List<String> _hadayekAreas = <String>[
    'أ',
    'ب',
    'ج',
    'د',
    'هـ',
    'و',
    'ز',
    'ح',
    'ط',
    'ك',
    'ل',
    'م',
    'ن',
    'ع',
    'س',
    'ص',
  ];

  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddresses = true;
  bool _isPlacingOrder = false;
  String _paymentMethod = 'cash';
  double _walletBalance = 0;
  String? _customerId;
  late final MarketCheckoutBackend _backend =
      widget.backend ?? MarketCheckoutBackend();
  int _ownerEpoch = 0, _loadRevision = 0, _deliveryFeeRevision = 0;
  String? _accountId;
  StreamSubscription? _authSubscription;
  BuildContext? _addressDialogContext, _addressPickerContext;
  bool _owns(String? uid, int epoch) =>
      mounted &&
      uid != null &&
      epoch == _ownerEpoch &&
      _accountId == uid &&
      _backend.accountId == uid;
  String Function()? _errorMessage;
  double _deliveryFee = 0;
  bool _isLoadingDeliveryFee = true;
  final _promoController = TextEditingController();
  String? _appliedPromoCode;
  double _promoDiscount = 0;
  bool _applyingPromo = false;
  bool _deliveryFeeReady = false;
  bool _locating = false;
  late String _checkoutKey = _newCheckoutKey();
  SecureDraftStore? _draftStore;

  String get _checkoutFeature => 'checkout:${widget.supermarket['id']}';
  String get _cartFingerprint {
    final keys = widget.cart.keys.toList()..sort();
    return jsonEncode({
      for (final key in keys) key: widget.cart[key]!['quantity'],
    });
  }

  Future<void> _saveCheckoutDraft() async {
    if (_draftStore == null || _accountId != _backend.accountId) return;
    try {
      await _draftStore!.save(_checkoutFeature, {
        'fingerprint': _cartFingerprint,
        'request': _checkoutKey,
        'address': _selectedAddress?['id'],
        'payment': _paymentMethod,
      }, lifetime: const Duration(hours: 12));
    } catch (_) {}
  }

  Future<void> _restoreCheckoutDraft() async {
    try {
      final data = await _draftStore?.load(_checkoutFeature);
      if (data == null ||
          !mounted ||
          _accountId != _backend.accountId ||
          data['fingerprint'] != _cartFingerprint)
        return;
      final key = data['request'];
      if (key is! String || !RegExp(r'^[a-f0-9-]{36}$').hasMatch(key)) return;
      _checkoutKey = key;
      final address = _savedAddresses
          .where((a) => a['id'] == data['address'])
          .firstOrNull;
      if (address != null) _selectedAddress = address;
      if (const ['cash', 'wallet'].contains(data['payment']))
        _paymentMethod = data['payment'] as String;
    } catch (_) {}
  }

  static String _newCheckoutKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  double _price(Map<String, dynamic> product) =>
      ((product['effective_price'] ?? product['price']) as num?)?.toDouble() ??
      0;

  double get _subtotal => widget.cart.values.fold(0.0, (sum, item) {
    final price = _price(Map<String, dynamic>.from(item['product'] as Map));
    final qty = item['quantity'] as int;
    return sum + price * qty;
  });

  double get _total =>
      (_subtotal + _deliveryFee - _promoDiscount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _accountId = _backend.accountId;
    if (widget.backend == null && _accountId != null)
      _draftStore = SecureDraftStore(_accountId!);
    _authSubscription = _backend.accountChanges.listen((_) {
      final next = _backend.accountId;
      if (!mounted || next == _accountId) return;
      for (final dialog in [_addressDialogContext, _addressPickerContext]) {
        if (dialog != null &&
            dialog.mounted &&
            ModalRoute.of(dialog)?.isCurrent == true) {
          FocusScope.of(dialog).unfocus();
          Navigator.of(dialog).pop();
        }
      }
      _addressDialogContext = null;
      _addressPickerContext = null;
      _ownerEpoch++;
      _loadRevision++;
      _deliveryFeeRevision++;
      setState(() {
        _accountId = next;
        _draftStore = widget.backend == null && next != null
            ? SecureDraftStore(next)
            : null;
        _customerId = null;
        _walletBalance = 0;
        _savedAddresses = [];
        _selectedAddress = null;
        _appliedPromoCode = null;
        _promoDiscount = 0;
        _paymentMethod = 'cash';
        _promoController.clear();
        _checkoutKey = _newCheckoutKey();
        _deliveryFeeReady = false;
        _deliveryFee = 0;
        _isLoadingAddresses = true;
        _isLoadingDeliveryFee = true;
        _isPlacingOrder = false;
        _applyingPromo = false;
        _locating = false;
        _errorMessage = null;
      });
      unawaited(_loadData());
    });
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _ownerEpoch++;
    _authSubscription?.cancel();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final uid = _backend.accountId, epoch = _ownerEpoch;
    bool ownsRequest() => _owns(uid, epoch);
    if (!ownsRequest()) return;
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty || _applyingPromo) return;
    setState(() {
      _applyingPromo = true;
      _errorMessage = null;
    });
    try {
      final result = await _backend.validateMarketPromo(
        supermarketId: widget.supermarket['id'].toString(),
        code: code,
        subtotal: _subtotal,
      );
      if (!ownsRequest()) return;
      setState(() {
        _appliedPromoCode = result['code']?.toString() ?? code;
        _promoDiscount = (result['discount'] as num?)?.toDouble() ?? 0;
        _promoController.text = _appliedPromoCode!;
        _applyingPromo = false;
        if (_paymentMethod == 'wallet' && _walletBalance < _total) {
          _paymentMethod = 'cash';
        }
      });
    } catch (error) {
      if (ownsRequest()) {
        setState(() {
          _appliedPromoCode = null;
          _promoDiscount = 0;
          _applyingPromo = false;
          _errorMessage = () => error.toString().endsWith('promo_invalid')
              ? context.strings.marketCheckout583fb62f
              : context.strings.marketPromoUnconfirmed;
        });
      }
    }
  }

  Future<void> _loadDeliveryFee({String? areaLetter}) async {
    final uid = _backend.accountId, epoch = _ownerEpoch;
    final revision = ++_deliveryFeeRevision;
    bool ownsRequest() => _owns(uid, epoch) && revision == _deliveryFeeRevision;
    if (ownsRequest())
      setState(() {
        _isLoadingDeliveryFee = true;
        _deliveryFeeReady = false;
      });
    try {
      final fee = await _backend.getVitoMarketDeliveryFee(areaLetter);
      if (ownsRequest()) {
        setState(() {
          _deliveryFee = fee;
          _deliveryFeeReady = true;
          _isLoadingDeliveryFee = false;
        });
      }
    } catch (e) {
      if (ownsRequest()) {
        setState(() {
          _isLoadingDeliveryFee = false;
          _errorMessage = () => context.strings.marketCheckout5c851b29;
        });
      }
    }
  }

  Future<void> _loadData() async {
    final uid = _backend.accountId, epoch = _ownerEpoch;
    final revision = ++_loadRevision;
    bool ownsRequest() =>
        mounted &&
        epoch == _ownerEpoch &&
        revision == _loadRevision &&
        _accountId == uid &&
        _backend.accountId == uid;
    try {
      final user = _backend.accountId;
      if (user == null) throw StateError('signed_out');
      final customer = await _backend.getCustomerByUserId(user);
      if (!ownsRequest()) return;
      if (customer == null) throw StateError('customer_not_found');
      final cid = customer['id'] as String;
      _customerId = cid;
      _walletBalance = (customer['wallet_balance'] as num?)?.toDouble() ?? 0;

      final addresses = await _backend.getCustomerAddresses(cid);
      if (ownsRequest()) {
        _savedAddresses = addresses;
        _selectedAddress = addresses.firstWhere(
          (a) => a['is_default'] == true,
          orElse: () => addresses.isNotEmpty ? addresses.first : {},
        );
        if (_selectedAddress?.isEmpty == true) _selectedAddress = null;
        await _restoreCheckoutDraft();
        if (ownsRequest()) setState(() => _isLoadingAddresses = false);
      }
      await _loadDeliveryFee(
        areaLetter: _selectedAddress?['area_letter']?.toString(),
      );
    } catch (_) {
      if (ownsRequest())
        setState(() {
          _isLoadingAddresses = false;
          _isLoadingDeliveryFee = false;
          _errorMessage = () => context.strings.marketCheckout85907225;
        });
    }
  }

  Future<void> _placeOrder() async {
    final uid = _backend.accountId, epoch = _ownerEpoch;
    bool ownsRequest() => _owns(uid, epoch);
    if (!ownsRequest()) return;
    if (_isPlacingOrder || _isLoadingDeliveryFee || !_deliveryFeeReady) return;
    if (_selectedAddress == null) {
      setState(
        () => _errorMessage = () => context.strings.marketCheckout7e25319d,
      );
      return;
    }
    if (_customerId == null) return;
    if (!isValidMarketDeliveryCoordinates(
      _selectedAddress!['latitude'],
      _selectedAddress!['longitude'],
    )) {
      await _useCurrentLocation();
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _errorMessage = null;
    });

    try {
      final items = <Map<String, dynamic>>[];
      for (final entry in widget.cart.entries) {
        final item = entry.value;
        final product = item['product'] as Map<String, dynamic>;
        items.add({'product_id': product['id'], 'quantity': item['quantity']});
      }

      await _saveCheckoutDraft();
      if (!ownsRequest()) return;
      final result = await _backend.createMarketOrderAtomic(
        customerId: _customerId!,
        supermarketId: widget.supermarket['id'] as String,
        deliveryAddress: _selectedAddress!['display_address'] as String,
        areaLetter: _selectedAddress!['area_letter']?.toString(),
        latitude: (_selectedAddress!['latitude'] as num?)?.toDouble(),
        longitude: (_selectedAddress!['longitude'] as num?)?.toDouble(),
        paymentMethod: _paymentMethod,
        items: items,
        promoCode: _appliedPromoCode,
        idempotencyKey: _checkoutKey,
      );
      final orderId = result['order_id'].toString();

      if (ownsRequest()) {
        try {
          await _draftStore?.clear(_checkoutFeature);
          await _draftStore?.clear('cart:${widget.supermarket['id']}');
        } catch (_) {
          /* A confirmed server order must never be hidden by local storage. */
        }
        if (!ownsRequest()) return;
        setState(() => _isPlacingOrder = false);
        context.pushReplacement(
          AppRoutes.vitoMarketOrderTracking,
          extra: {'orderId': orderId},
        );
      }
    } catch (e) {
      assert(() {
        debugPrint('Vito Market checkout error: $e');
        return true;
      }());
      if (ownsRequest()) {
        setState(() {
          _isPlacingOrder = false;
          // Do not expose SQL signatures or internal database errors to users.
          final reason = e.toString();
          _errorMessage = () => reason.contains('invalid_address')
              ? context.strings.marketCheckout6bd931d4
              : reason.contains('stale') || reason.contains('session_expired')
              ? context.strings.marketCheckout022a299f
              : reason.contains('active_market_order_exists')
              ? context.strings.marketCheckoute6356df7
              : reason.contains('product_unavailable')
              ? context.strings.marketCheckout22bbfe23
              : reason.contains('store_unavailable')
              ? context.strings.marketCheckout9b041b34
              : reason.contains('insufficient_wallet')
              ? context.strings.marketCheckoute957f73e
              : context.strings.marketOrderUnconfirmed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1220),
          title: Text(
            context.strings.marketCheckoutfb4a312e,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => context.pop(),
          ),
          elevation: 0,
        ),
        body: _isLoadingAddresses || _isLoadingDeliveryFee
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order summary
                    _sectionTitle(context.strings.marketCheckout4cb08bb2),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF13182A)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A3355)),
                      ),
                      child: Column(
                        children: [
                          ...widget.cart.values.map((item) {
                            final product =
                                item['product'] as Map<String, dynamic>;
                            final qty = item['quantity'] as int;
                            final price = _price(product);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${product['name']} × $qty',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    context.strings.moneyValue(
                                      (price * qty).toStringAsFixed(2),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.gold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(color: Color(0xFF2A3355)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.strings.marketCheckout4793cceb,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                context.strings.moneyValue(
                                  _subtotal.toStringAsFixed(2),
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_promoDiscount > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    context.strings.marketPromoApplied(
                                      _appliedPromoCode ?? '',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ),
                                Text(
                                  context.strings.moneyValue(
                                    '-${_promoDiscount.toStringAsFixed(2)}',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.strings.marketCheckoutaa63ea8f,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                context.strings.moneyValue(
                                  _deliveryFee.toStringAsFixed(2),
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF2A3355)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.strings.marketCheckoutbaed6e99,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                context.strings.moneyValue(
                                  _total.toStringAsFixed(2),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.gold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(context.strings.marketCheckout65397569),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: context.strings.marketCheckout40cf4d30,
                              hintStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF13182A)
                                  : Theme.of(context).colorScheme.surface,
                              suffixIcon: _appliedPromoCode == null
                                  ? null
                                  : const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onChanged: (_) {
                              if (_appliedPromoCode != null) {
                                setState(() {
                                  _appliedPromoCode = null;
                                  _promoDiscount = 0;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _applyingPromo ? null : _applyPromo,
                          child: _applyingPromo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.strings.marketCheckout268974da),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Delivery address
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _sectionTitle(
                            context.strings.marketCheckout0d08b83a,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showAddressSelector(context),
                          child: Text(
                            context.strings.marketCheckout3efc34e3,
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _locating || _isPlacingOrder
                            ? null
                            : _useCurrentLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: Text(
                          _locating
                              ? context.strings.marketCheckout7b7b0404
                              : context.strings.marketCheckoutaae85882,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showAddressSelector(context),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF13182A)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedAddress != null
                                ? AppTheme.gold.withAlpha(100)
                                : const Color(0xFFEF5350).withAlpha(100),
                          ),
                        ),
                        child: _selectedAddress != null
                            ? Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: AppTheme.gold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedAddress!['label']
                                                  as String? ??
                                              context
                                                  .strings
                                                  .marketCheckout74190f4b,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          _selectedAddress!['display_address']
                                                  as String? ??
                                              '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Icon(
                                    Icons.add_location_rounded,
                                    color: Color(0xFFEF5350),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    context.strings.marketCheckoutb03c96ad,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFEF5350),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payment method
                    _sectionTitle(context.strings.marketCheckoutae2d6005),
                    const SizedBox(height: 10),
                    _PaymentOption(
                      label: context.strings.marketCheckout1881ccb3,
                      icon: Icons.payments_rounded,
                      value: 'cash',
                      selected: _paymentMethod,
                      onTap: () => setState(() => _paymentMethod = 'cash'),
                    ),
                    const SizedBox(height: 8),
                    _PaymentOption(
                      label: context.strings.marketWalletChoice(
                        _walletBalance.toStringAsFixed(2),
                      ),
                      icon: Icons.account_balance_wallet_rounded,
                      value: 'wallet',
                      selected: _paymentMethod,
                      onTap: _walletBalance >= _total
                          ? () => setState(() => _paymentMethod = 'wallet')
                          : null,
                    ),
                    if (_walletBalance > 0 && _walletBalance < _total) ...[
                      const SizedBox(height: 8),
                      _PaymentOption(
                        label: context.strings.marketWalletCashChoice(
                          _walletBalance.toStringAsFixed(2),
                        ),
                        icon: Icons.account_balance_wallet_outlined,
                        value: 'combined',
                        selected: _paymentMethod,
                        onTap: () =>
                            setState(() => _paymentMethod = 'combined'),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!(),
                        style: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isPlacingOrder ||
                                _isLoadingDeliveryFee ||
                                !_deliveryFeeReady ||
                                _customerId == null
                            ? null
                            : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: const Color(0xFF0B0F1A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isPlacingOrder
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0B0F1A),
                                ),
                              )
                            : Text(
                                context.strings.marketCheckoutfb4a312e,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  void _showAddressSelector(BuildContext context) {
    final uid = _backend.accountId, epoch = _ownerEpoch;
    if (!_owns(uid, epoch)) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF13182A)
          : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        _addressPickerContext = ctx;
        return Directionality(
          textDirection: Directionality.of(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3355),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  context.strings.marketCheckoutb03c96ad,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (_savedAddresses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        context.strings.marketCheckout91f328d3,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddAddressDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: const Color(0xFF0B0F1A),
                        ),
                        child: Text(
                          context.strings.marketCheckout8d30f720,
                          style: TextStyle(),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                ..._savedAddresses.map(
                  (addr) => ListTile(
                    leading: const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.gold,
                    ),
                    title: Text(
                      addr['label'] as String? ??
                          context.strings.marketCheckout74190f4b,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      addr['display_address'] as String? ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    trailing: _selectedAddress?['id'] == addr['id']
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.gold,
                          )
                        : null,
                    onTap: () {
                      if (!_owns(uid, epoch)) return;
                      setState(() {
                        _selectedAddress = addr;
                        _isLoadingDeliveryFee = true;
                        _errorMessage = null;
                      });
                      Navigator.pop(ctx);
                      _loadDeliveryFee(
                        areaLetter: addr['area_letter']?.toString(),
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.add_location_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    context.strings.marketCheckout8d30f720,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    if (!_owns(uid, epoch)) return;
                    Navigator.pop(ctx);
                    _showAddAddressDialog(context);
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<Position> _captureCustomerPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw PermissionDeniedException('location_permission_required');
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    final uid = _backend.accountId, epoch = _ownerEpoch;
    bool ownsRequest() => _owns(uid, epoch);
    if (_locating || _customerId == null) return;
    setState(() {
      _locating = true;
      _errorMessage = null;
    });
    try {
      final position = await _captureCustomerPosition();
      if (!ownsRequest()) return;
      _showAddAddressDialog(context, location: position);
    } catch (error) {
      if (!ownsRequest()) return;
      setState(
        () => _errorMessage = () => error is PermissionDeniedException
            ? context.strings.marketCheckout5dc8b4dc
            : error is LocationServiceDisabledException
            ? context.strings.marketCheckout1c4408e5
            : context.strings.marketCheckoutb4e4ffee,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!()),
          action: SnackBarAction(
            label: context.strings.marketCheckout75c427ae,
            onPressed: () {
              if (error is PermissionDeniedException) {
                Geolocator.openAppSettings();
              } else {
                Geolocator.openLocationSettings();
              }
            },
          ),
        ),
      );
    } finally {
      if (ownsRequest()) setState(() => _locating = false);
    }
  }

  void _showAddAddressDialog(BuildContext context, {Position? location}) {
    final uid = _backend.accountId, epoch = _ownerEpoch;
    final customerId = _customerId;
    bool ownsRequest() => _owns(uid, epoch) && customerId != null;
    if (!ownsRequest()) return;
    final labelCtrl = TextEditingController(
      text: context.strings.marketCheckoutd49bcb58,
    );
    String? selectedArea;
    final buildingCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final aptCtrl = TextEditingController();
    bool isSaving = false;
    String? msg;

    showDialog(
      context: context,
      builder: (ctx) {
        _addressDialogContext = ctx;
        return _AddressDialogControllerOwner(
          controllers: [labelCtrl, buildingCtrl, floorCtrl, aptCtrl],
          child: StatefulBuilder(
            builder: (ctx, setS) => Directionality(
              textDirection: Directionality.of(context),
              child: AlertDialog(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF13182A)
                    : Theme.of(context).colorScheme.surface,
                title: Text(
                  context.strings.marketCheckout8d30f720,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (location != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            context.strings.marketCheckout20fa724b,
                            style: TextStyle(color: AppTheme.gold),
                          ),
                        ),
                      _dialogField(
                        labelCtrl,
                        context.strings.marketCheckout784ff5e6,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          context.strings.marketCheckoutbc20c882,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _hadayekAreas.map((letter) {
                          final isSelected = selectedArea == letter;
                          return ChoiceChip(
                            label: SizedBox(
                              width: 29,
                              child: Center(child: Text(letter)),
                            ),
                            selected: isSelected,
                            onSelected: (_) => setS(() {
                              selectedArea = letter;
                              msg = null;
                            }),
                            backgroundColor: const Color(0xFF1A2035),
                            selectedColor: AppTheme.gold,
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.gold
                                  : const Color(0xFF2A3355),
                            ),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppTheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 10),
                      _dialogField(
                        buildingCtrl,
                        context.strings.marketCheckouteca4806f,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      _dialogField(
                        floorCtrl,
                        context.strings.marketCheckoutde69d94f,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      _dialogField(
                        aptCtrl,
                        context.strings.marketCheckoutbf021870,
                        keyboardType: TextInputType.number,
                      ),
                      if (msg != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          msg!,
                          style: const TextStyle(
                            color: Color(0xFFEF5350),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(ctx),
                    child: Text(
                      context.strings.marketCheckout9a30dc2a,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: const Color(0xFF0B0F1A),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!_hadayekAreas.contains(selectedArea) ||
                                buildingCtrl.text.trim().isEmpty) {
                              setS(
                                () => msg =
                                    context.strings.marketCheckout8a0c87e3,
                              );
                              return;
                            }
                            setS(() => isSaving = true);
                            try {
                              final coordinates =
                                  location ?? await _captureCustomerPosition();
                              if (!ownsRequest() || !ctx.mounted) return;
                              final displayAddr =
                                  'حدائق الأهرام - منطقة $selectedArea - عمارة ${buildingCtrl.text.trim()}'
                                  '${floorCtrl.text.trim().isNotEmpty ? ' - دور ${floorCtrl.text.trim()}' : ''}'
                                  '${aptCtrl.text.trim().isNotEmpty ? ' - شقة ${aptCtrl.text.trim()}' : ''}';
                              final addr = await _backend.addCustomerAddress(
                                customerId: customerId!,
                                label: labelCtrl.text.trim().isNotEmpty
                                    ? labelCtrl.text.trim()
                                    : context.strings.marketCheckout74190f4b,
                                areaLetter: selectedArea!,
                                buildingNumber: buildingCtrl.text.trim(),
                                floor: floorCtrl.text.trim().isNotEmpty
                                    ? floorCtrl.text.trim()
                                    : null,
                                apartment: aptCtrl.text.trim().isNotEmpty
                                    ? aptCtrl.text.trim()
                                    : null,
                                displayAddress: displayAddr,
                                latitude: coordinates.latitude,
                                longitude: coordinates.longitude,
                              );
                              if (ownsRequest()) {
                                setState(() {
                                  _savedAddresses.add(addr);
                                  _selectedAddress = addr;
                                  _isLoadingDeliveryFee = true;
                                  _errorMessage = null;
                                });
                                _loadDeliveryFee(
                                  areaLetter: addr['area_letter']?.toString(),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (error) {
                              if (ctx.mounted)
                                setS(() {
                                  isSaving = false;
                                  msg = error is PermissionDeniedException
                                      ? context.strings.marketCheckout0a19bc85
                                      : error
                                            is LocationServiceDisabledException
                                      ? context.strings.marketCheckout70d4e1aa
                                      : error is TimeoutException
                                      ? context.strings.marketCheckoute908ffef
                                      : context.strings.marketCheckout9b62db02;
                                });
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0B0F1A),
                            ),
                          )
                        : Text(
                            context.strings.marketCheckoutddfcaf9d,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
        filled: true,
        fillColor: const Color(0xFF1A2035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3355)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3355)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.gold),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final VoidCallback? onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.gold.withAlpha(20)
              : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF13182A)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.gold : const Color(0xFF2A3355),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDisabled
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : (isSelected
                        ? AppTheme.gold
                        : Theme.of(context).colorScheme.onSurface),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.gold,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// Controllers must outlive the dialog reverse transition and be disposed only
// when its route subtree is removed, including account-change dismissal.
class _AddressDialogControllerOwner extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget child;
  const _AddressDialogControllerOwner({
    required this.controllers,
    required this.child,
  });
  @override
  State<_AddressDialogControllerOwner> createState() =>
      _AddressDialogControllerOwnerState();
}

class _AddressDialogControllerOwnerState
    extends State<_AddressDialogControllerOwner> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
