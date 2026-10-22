import 'dart:async';
import '../../services/secure_draft_store.dart';
import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

class VitoMarketProductsScreen extends StatefulWidget {
  final Map<String, dynamic> supermarket;

  final Future<List<Map<String, dynamic>>> Function(String)? loadCategories;
  final Future<List<Map<String, dynamic>>> Function(String, String?)?
  loadProducts;
  const VitoMarketProductsScreen({
    super.key,
    required this.supermarket,
    this.loadCategories,
    this.loadProducts,
  });

  @override
  State<VitoMarketProductsScreen> createState() =>
      _VitoMarketProductsScreenState();
}

class _VitoMarketProductsScreenState extends State<VitoMarketProductsScreen> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  String? _selectedCategoryId;
  bool _isLoading = true;
  bool _failed = false;
  int _productReadRevision = 0;

  // Cart: productId -> {product, quantity}
  final Map<String, Map<String, dynamic>> _cart = {};
  SecureDraftStore? _draftStore;
  String? _draftOwner;

  int get _cartCount =>
      _cart.values.fold(0, (sum, item) => sum + (item['quantity'] as int));
  double get _cartTotal => _cart.values.fold(0.0, (sum, item) {
    final price = _productPrice(
      Map<String, dynamic>.from(item['product'] as Map),
    );
    final qty = item['quantity'] as int;
    return sum + price * qty;
  });

  double _productPrice(Map<String, dynamic> product) =>
      ((product['effective_price'] ?? product['price']) as num?)?.toDouble() ??
      0;

  @override
  void initState() {
    super.initState();
    if (widget.loadProducts == null) {
      _draftOwner = SupabaseService.instance.currentUser?.id;
      if (_draftOwner != null) _draftStore = SecureDraftStore(_draftOwner!);
    }
    _loadCategories().then((_) => _restoreCart());
  }

  String get _cartDraftKey => 'cart:${widget.supermarket['id']}';
  Future<void> _saveCart() async {
    if (_draftStore == null ||
        _draftOwner != SupabaseService.instance.currentUser?.id)
      return;
    try {
      await _draftStore!.save(_cartDraftKey, {
        'items': {
          for (final entry in _cart.entries) entry.key: entry.value['quantity'],
        },
      }, lifetime: const Duration(hours: 12));
    } catch (_) {}
  }

  Future<void> _restoreCart() async {
    if (_draftStore == null) return;
    try {
      final draft = await _draftStore!.load(_cartDraftKey);
      if (draft?['items'] is! Map) return;
      final fresh = await SupabaseService.instance.getProducts(
        widget.supermarket['id'].toString(),
      );
      if (!mounted ||
          _draftOwner != SupabaseService.instance.currentUser?.id ||
          _cart.isNotEmpty)
        return;
      final items = draft!['items'] as Map;
      setState(() {
        for (final product in fresh) {
          final id = product['id']?.toString(), qty = items[product['id']];
          if (id != null &&
              qty is int &&
              qty > 0 &&
              qty <= 99 &&
              product['is_active'] != false)
            _cart[id] = {'product': product, 'quantity': qty};
        }
      });
    } catch (_) {
      /* Fresh products and trusted checkout stay usable without local storage. */
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final cats =
          await (widget.loadCategories ??
              SupabaseService.instance.getProductCategories)(
            widget.supermarket['id'] as String,
          );
      if (mounted) {
        setState(() {
          _categories = cats;
          _selectedCategoryId = cats.isNotEmpty
              ? cats.first['id'] as String
              : null;
        });
        await _loadProducts();
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _failed = true;
        });
    }
  }

  Future<void> _loadProducts() async {
    final revision = ++_productReadRevision;
    final category = _selectedCategoryId;
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final id = widget.supermarket['id'] as String;
      final products = await (widget.loadProducts != null
          ? widget.loadProducts!(id, category)
          : SupabaseService.instance.getProducts(id, categoryId: category));
      if (!mounted || revision != _productReadRevision) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || revision != _productReadRevision) return;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    final id = product['id'] as String;
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['quantity'] = (_cart[id]!['quantity'] as int) + 1;
      } else {
        _cart[id] = {'product': product, 'quantity': 1};
      }
    });
    unawaited(_saveCart());
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        final qty = _cart[productId]!['quantity'] as int;
        if (qty <= 1) {
          _cart.remove(productId);
        } else {
          _cart[productId]!['quantity'] = qty - 1;
        }
      }
    });
    unawaited(_saveCart());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF0D1220)
              : Theme.of(context).colorScheme.surface,
          title: Text(
            widget.supermarket['name'] as String? ??
                context.strings.marketProductsTitle,
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
          actions: [
            if (_cartCount > 0)
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shopping_cart_rounded,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.gold
                          : Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _showCart(context),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Color(0xFFEF5350),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_cartCount',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.gold))
            : _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.strings.marketProductsFailed,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _categories.isEmpty
                          ? _loadCategories
                          : _loadProducts,
                      child: Text(context.strings.retry),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Categories
                  if (_categories.isNotEmpty)
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cat = _categories[i];
                          final isSelected = cat['id'] == _selectedCategoryId;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategoryId = cat['id'] as String;
                                _isLoading = true;
                              });
                              _loadProducts();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.gold
                                        : Theme.of(context).colorScheme.primary)
                                    : Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF13182A)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.gold
                                          : Theme.of(context).colorScheme.primary)
                                      : Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF2A3355)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                cat['name'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF0B0F1A)
                                          : Colors.white)
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Products
                  Expanded(
                    child: _products.isEmpty
                        ? Center(
                            child: Text(
                              context.strings.marketProductsEmpty,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: _products.length,
                            itemBuilder: (context, i) {
                              final p = _products[i];
                              final pid = p['id'] as String;
                              final qty = _cart[pid]?['quantity'] as int? ?? 0;
                              return Container(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color(0xFF13182A)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Color(0xFF2A3355)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Color(0xFF1A2035)
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(14),
                                          ),
                                          image: p['image_url'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    p['image_url'] as String,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: p['image_url'] == null
                                            ? Center(
                                                child: Icon(
                                                  Icons.inventory_2_rounded,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  size: 40,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name'] as String? ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            children: [
                                              Text(
                                                context.strings.moneyValue(
                                                  _productPrice(
                                                    p,
                                                  ).toStringAsFixed(2),
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.gold,
                                                ),
                                              ),
                                              if (p['has_active_discount'] ==
                                                  true) ...[
                                                SizedBox(width: 5),
                                                Text(
                                                  context.strings.moneyValue(
                                                    (p['price'] as num)
                                                        .toStringAsFixed(2),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          qty == 0
                                              ? SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    onPressed: () =>
                                                        _addToCart(p),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Theme.of(context).brightness == Brightness.dark
                                                              ? AppTheme.gold
                                                              : Theme.of(context).colorScheme.primary,
                                                      foregroundColor:
                                                          Theme.of(context).brightness == Brightness.dark
                                                              ? const Color(0xFF0B0F1A)
                                                              : Colors.white,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 6,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      context
                                                          .strings
                                                          .marketProductsAdd,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _removeFromCart(pid),
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? const Color(0xFF2A3355)
                                                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? Colors.transparent
                                                                : Theme.of(context).colorScheme.outlineVariant,
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.remove_rounded,
                                                          size: 16,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '$qty',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _addToCart(p),
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? AppTheme.gold
                                                              : Theme.of(context).colorScheme.primary,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons.add_rounded,
                                                          size: 16,
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? const Color(0xFF0B0F1A)
                                                              : Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        bottomNavigationBar: _cartCount > 0
            ? SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => _showCart(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Color(0xFF0B0F1A),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_rounded, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.strings.marketProductsViewCart(
                              '$_cartCount',
                              _cartTotal.toStringAsFixed(2),
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF13182A)
          : Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF2A3355)
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  context.strings.marketProductsCart,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: _cart.entries.map((entry) {
                    final item = entry.value;
                    final product = item['product'] as Map<String, dynamic>;
                    final qty = item['quantity'] as int;
                    final price = _productPrice(product);
                    return Container(
                      margin: EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF1A2035)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  context.strings.marketProductsLine(
                                    price.toStringAsFixed(2),
                                    '$qty',
                                    (price * qty).toStringAsFixed(2),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppTheme.gold
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  _removeFromCart(entry.key);
                                  Navigator.pop(ctx);
                                  _showCart(context);
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF2A3355)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '$qty',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _addToCart(product);
                                  Navigator.pop(ctx);
                                  _showCart(context);
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppTheme.gold
                                        : Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF0B0F1A)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.strings.marketProductsTotal,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          context.strings.moneyValue(
                            _cartTotal.toStringAsFixed(2),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.gold
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push(
                            AppRoutes.vitoMarketCheckout,
                            extra: {
                              'supermarket': widget.supermarket,
                              'cart': Map<String, Map<String, dynamic>>.from(
                                _cart,
                              ),
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.gold
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0B0F1A)
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.strings.marketProductsContinue,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
