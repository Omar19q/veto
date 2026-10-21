import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class _ServiceOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String priceHint;

  const _ServiceOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.priceHint,
  });
}

class BookingServiceSheetWidget extends StatefulWidget {
  final void Function(String serviceId) onServiceSelected;

  const BookingServiceSheetWidget({super.key, required this.onServiceSelected});

  @override
  State<BookingServiceSheetWidget> createState() =>
      _BookingServiceSheetWidgetState();
}

class _BookingServiceSheetWidgetState extends State<BookingServiceSheetWidget> {
  String? _selectedId;
  final List<_ServiceOption> _services = const [
    _ServiceOption(
      id: 'car',
      title: 'فيتو سيارة',
      description: 'مشوار سريع ومريح بسيارة إلى وجهتك',
      icon: Icons.directions_car_rounded,
      accentColor: AppTheme.gold,
      priceHint: 'السعر يظهر قبل الطلب',
    ),
    _ServiceOption(
      id: 'motorcycle',
      title: 'فيتو موتوسيكل',
      description: 'أسرع طريق لمشاويرك اليومية',
      icon: Icons.two_wheeler_rounded,
      accentColor: Color(0xFF64B5F6),
      priceHint: 'السعر يظهر قبل الطلب',
    ),
    _ServiceOption(
      id: 'package',
      title: 'فيتو طرد',
      description: 'أرسل طردك بسرعة وأمان إلى وجهته',
      icon: Icons.inventory_2_rounded,
      accentColor: Color(0xFFAB47BC),
      priceHint: 'حتى 5 كيلو',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24)],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 38, height: 4,
                decoration: BoxDecoration(color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 12),
              const Text('اختار خدمتك', style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
              const Text('اضغط على الخدمة المناسبة، وهننقلك للخطوة التالية مباشرة.',
                style: TextStyle( fontSize: 11,
                  color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              ...List.generate(_services.length, (index) {
                final service = _services[index];
                final selected = _selectedId == service.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () {
                        if (_selectedId != null) return;
                        setState(() => _selectedId = service.id);
                        widget.onServiceSelected(service.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? service.accentColor.withAlpha(34)
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: selected
                            ? service.accentColor : AppTheme.cardBorder),
                        ),
                        child: Row(children: [
                          Container(width: 58, height: 58,
                            decoration: BoxDecoration(
                              color: service.accentColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(14)),
                            child: Icon(service.icon, color: service.accentColor, size: 31)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(service.title, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle( fontSize: 16,
                                  fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              Text(service.description, maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle( fontSize: 10.5,
                                  color: AppTheme.textSecondary)),
                            ],
                          )),
                          const SizedBox(width: 6),
                          Icon(selected ? Icons.check_circle_rounded
                              : Icons.chevron_left_rounded,
                              color: service.accentColor, size: 23),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
