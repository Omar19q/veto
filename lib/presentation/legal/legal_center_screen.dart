import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import 'veto_legal_content.dart';

/// Accessible without signing in; does not mutate trips, accounts or payments.
class VetoLegalCenterScreen extends StatelessWidget {
  final String? pageKey;
  const VetoLegalCenterScreen({super.key, this.pageKey});

  static const _sections = <({String key, String route, IconData icon})>[
    (key: 'privacy', route: '/privacy-policy', icon: Icons.shield_outlined),
    (
      key: 'terms',
      route: '/terms-of-service',
      icon: Icons.description_outlined,
    ),
    (
      key: 'deletion',
      route: '/delete-account',
      icon: Icons.person_remove_outlined,
    ),
    (
      key: 'safety',
      route: '/safety-support',
      icon: Icons.support_agent_rounded,
    ),
  ];

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.legal23d4bbf5)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.legalbb7d2e6a)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = VetoLegalContent.forLanguage(
      context.strings.localeName,
    )[pageKey];
    final title = (page?['title'] as String?) ?? context.strings.legal930c8cba;
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          leading: IconButton(
            tooltip: context.strings.legalcb822418,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/sign-up-login-screen'),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: page == null ? _index(context) : _article(context, page),
          ),
        ),
      ),
    );
  }

  List<Widget> _index(BuildContext context) => [
    Text(
      context.strings.legal5d933de9,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        
        fontWeight: FontWeight.w800,
        fontSize: 22,
      ),
    ),
    SizedBox(height: 8),
    Text(
      context.strings.legal18f333af,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        
      ),
    ),
    SizedBox(height: 18),
    ..._sections.map(
      (section) => Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Icon(section.icon, color: AppTheme.gold, size: 30),
            title: Text(
              VetoLegalContent.forLanguage(
                    context.strings.localeName,
                  )[section.key]!['title']
                  as String,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.gold,
              size: 16,
            ),
            onTap: () => context.push(section.route),
          ),
        ),
      ),
    ),
    _contact(context),
  ];

  List<Widget> _article(BuildContext context, Map<String, dynamic> page) {
    final rawSections = page['sections'] as List<dynamic>;
    return [
      Text(
        page['intro'] as String,
        style: TextStyle(
          
          height: 1.7,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      SizedBox(height: 10),
      Text(
        context.strings.legalbcaecd4c,
        style: TextStyle(
          
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
      SizedBox(height: 16),
      ...rawSections.map((entry) {
        final section = entry as Map<String, String>;
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section['heading']!,
                style: TextStyle(
                  
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),
              Text(
                section['body']!,
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.7,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }),
      if (pageKey == 'deletion') ...[
        ElevatedButton.icon(
          onPressed: () => _open(
            context,
            Uri.https('wa.me', '/201031517830', {
              'text': context.strings.legalf0942ede,
            }),
          ),
          icon: Icon(Icons.chat_rounded),
          label: Text(
            context.strings.legal04f1727b,
            style: TextStyle( fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: () => _open(
            context,
            Uri(scheme: 'tel', path: VetoLegalContent.contactPhone),
          ),
          icon: Icon(Icons.phone_rounded),
          label: Text(
            context.strings.legal0efc8201,
            style: TextStyle(),
          ),
        ),
        SizedBox(height: 7),
        Text(
          context.strings.legal94fb90ab,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 15),
      ],
      _contact(context),
      SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => context.push('/legal'),
        icon: Icon(Icons.article_outlined),
        label: Text(
          context.strings.legal3852d180,
          style: TextStyle(),
        ),
      ),
    ];
  }

  Widget _contact(BuildContext context) => Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.gold.withAlpha(135)),
      color: Theme.of(context).colorScheme.surfaceContainer,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.legal01b2add5,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _open(
            context,
            Uri(scheme: 'tel', path: VetoLegalContent.contactPhone),
          ),
          icon: Icon(Icons.call_outlined),
          label: Text(
            context.strings.legalb70c8e6c,
            style: TextStyle(),
          ),
        ),
      ],
    ),
  );
}
