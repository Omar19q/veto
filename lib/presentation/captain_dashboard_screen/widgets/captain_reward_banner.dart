import '../../../l10n/strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';

/// Display-only: backend records progress and issues a claim exactly once.
/// This widget NEVER pays a reward or changes captain balances.
class CaptainRewardBanner extends StatefulWidget {
  const CaptainRewardBanner({super.key, required this.campaign});
  final Map<String, dynamic> campaign;

  @override
  State<CaptainRewardBanner> createState() => _CaptainRewardBannerState();
}

class _CaptainRewardBannerState extends State<CaptainRewardBanner> {
  Timer? _clock;
  Map<String, dynamic> get campaign => widget.campaign;

  @override
  void initState() {
    super.initState();
    // Display-only timer. The database timestamps remain authoritative.
    _clock = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _timeLeft() {
    final end = DateTime.tryParse(campaign['ends_at']?.toString() ?? '');
    if (end == null) return '';
    final duration = end.difference(DateTime.now());
    if (duration.isNegative) return '00:00:00';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _openBanner(BuildContext context) async {
    final raw = campaign['action_url']?.toString().trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.legacyCaptainRewardb754feca)),
        );
      }
      return;
    }
    await _details(context);
  }

  Future<void> _details(BuildContext context) async {
    final raw = campaign['action_url']?.toString().trim() ?? '';
    final uri = Uri.tryParse(raw);
    final title =
        campaign['title']?.toString() ??
        context.strings.legacyCaptainRewardbbe4ec79;
    final description = campaign['description']?.toString().trim() ?? '';
    final canOpen =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => Directionality(
        textDirection: Directionality.of(context),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 34,
                  color: AppTheme.gold,
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  description.isEmpty
                      ? context.strings.legacyCaptainRewardea201b37
                      : description,
                  style: TextStyle(
                    
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFFD5DEEF)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  context.strings.legacyCaptainReward06d1b76f,
                  style: TextStyle(
                    
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFFD5DEEF)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                if (canOpen) ...[
                  SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!ok && sheet.mounted) {
                          ScaffoldMessenger.of(sheet).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.strings.legacyCaptainRewardb754feca,
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.open_in_new_rounded),
                      label: Text(
                        context.strings.legacyCaptainRewarda73a4757,
                        style: TextStyle(
                          
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        campaign['title']?.toString() ??
        context.strings.legacyCaptainRewardbbe4ec79;
    final description = campaign['description']?.toString().trim() ?? '';
    final target = (campaign['target_trips'] as num?)?.toInt() ?? 0;
    final progress = (campaign['progress'] as num?)?.toInt() ?? 0;
    final rawAmount = campaign['reward_amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('$rawAmount');
    final max = (campaign['max_recipients'] as num?)?.toInt();
    final recipients = (campaign['recipients'] as num?)?.toInt() ?? 0;
    final status = campaign['status']?.toString() ?? 'active';
    final isFilled = status == 'active' && max != null && recipients >= max;
    final label = status == 'paid'
        ? context.strings.legacyCaptainReward9e6d9f56
        : status == 'pending'
        ? context.strings.legacyCaptainReward9868ebaa
        : isFilled
        ? context.strings.legacyCaptainReward6d269d00
        : status == 'ended'
        ? context.strings.legacyCaptainRewardecaefa5c
        : status == 'upcoming'
        ? context.strings.legacyCaptainReward7a13f6b6
        : context.strings.legacyCaptainReward141a2c34;
    final imageUrl = campaign['image_url']?.toString().trim() ?? '';
    final imageUri = Uri.tryParse(imageUrl);
    final validImage =
        imageUri != null &&
        (imageUri.scheme == 'https' || imageUri.scheme == 'http') &&
        imageUri.host.isNotEmpty;
    final fraction = target > 0
        ? (progress / target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openBanner(context),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [Color(0xFF172741), Color(0xFF292006)]
                    : [
                        Theme.of(context).colorScheme.surfaceContainer,
                        Theme.of(context).colorScheme.surface,
                      ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              border: Border.all(color: AppTheme.gold.withAlpha(90)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (validImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.card_giftcard_rounded,
                              color: AppTheme.gold,
                              size: 44,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.card_giftcard_rounded,
                          color: AppTheme.gold,
                          size: 40,
                        ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              label,
                              maxLines: 2,
                              style: TextStyle(
                                
                                color: Color(0xFFFFD769),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded, color: AppTheme.gold),
                    ],
                  ),
                  if (status == 'active' && _timeLeft().isNotEmpty) ...[
                    SizedBox(height: 7),
                    Text(
                      context.strings.legacyCaptainRewardTime(_timeLeft()),
                      style: TextStyle(
                        
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFFFFD769),
                      ),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFFD5DEEF)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 9,
                      backgroundColor: Color(0xFF374257),
                      color: AppTheme.gold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.strings.legacyCaptainRewardProgress(
                            '$progress',
                            '$target',
                          ),
                          style: TextStyle(
                            
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        amount == null || !amount.isFinite
                            ? context.strings.historyAmountUnavailable
                            : context.strings.moneyValue(
                                amount.toStringAsFixed(2),
                              ),
                        style: TextStyle(
                          
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    context.strings.legacyCaptainReward683deff3,
                    style: TextStyle(
                      
                      fontSize: 10,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFFD5DEEF)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
