import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';

class _ServiceData {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  const _ServiceData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });
}

class HomeServicesWidget extends StatefulWidget {
  final bool isTablet;
  final void Function(String serviceId) onServiceTap;

  const HomeServicesWidget({
    super.key,
    required this.isTablet,
    required this.onServiceTap,
  });

  @override
  State<HomeServicesWidget> createState() => _HomeServicesWidgetState();
}

class _HomeServicesWidgetState extends State<HomeServicesWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  final List<_ServiceData> _services = const [
    _ServiceData(
      id: 'car',
      title: 'فيتوّ سيارة',
      subtitle: 'مريح وسريع',
      icon: Icons.directions_car_rounded,
      accentColor: AppTheme.gold,
      bgColor: Color(0xFF1A1400),
    ),
    _ServiceData(
      id: 'motorcycle',
      title: 'فيتو موتوسيكل',
      subtitle: 'أسرع و ارخص وسيلة وسط زحمه',
      icon: Icons.two_wheeler_rounded,
      accentColor: Color(0xFF64B5F6),
      bgColor: Color(0xFF001A2A),
    ),
    _ServiceData(
      id: 'package',
      title: 'فيتو شحن',
      subtitle: 'توصيل امن و سريع لطردك',
      icon: Icons.inventory_2_rounded,
      accentColor: Color(0xFFAB47BC),
      bgColor: Color(0xFF1A001A),
    ),
    _ServiceData(
      id: 'market',
      title: 'فيتو ماركت',
      subtitle: 'من  المتجر الي باب بيتك بنفس سعر السوق',
      icon: Icons.shopping_cart_rounded,
      accentColor: AppTheme.successLight,
      bgColor: Color(0xFF001A0A),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _services.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _fadeAnims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();
    _slideAnims = _controllers
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
        )
        .toList();

    // Staggered entrance
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: 100 + i * 80), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleServiceTap(BuildContext context, String serviceId) {
    if (serviceId == 'market') {
      // Vito Market has its own completely separate flow
      context.push(AppRoutes.vitoMarket);
    } else {
      // Rides and package go through trip booking
      widget.onServiceTap(serviceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'خدماتنا',
            style: TextStyle(
              
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.isTablet ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: widget.isTablet ? 0.9 : 1.1,
          ),
          itemCount: _services.length,
          itemBuilder: (context, index) {
            final service = _services[index];
            return FadeTransition(
              opacity: _fadeAnims[index],
              child: SlideTransition(
                position: _slideAnims[index],
                child: _ServiceCard(
                  service: service,
                  onTap: () => _handleServiceTap(context, service.id),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final _ServiceData service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: widget.service.bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.service.accentColor.withAlpha(51),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.service.accentColor.withAlpha(20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Left border accent
              Positioned(
                right: 0,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: widget.service.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.service.accentColor.withAlpha(31),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.service.icon,
                        color: widget.service.accentColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.service.title,
                      style: const TextStyle(
                        
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.service.subtitle,
                      style: const TextStyle(
                        
                        fontSize: 11,
                        color: AppTheme.textSecondary,
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
