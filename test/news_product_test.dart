import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/karizma_backend.dart';
import 'package:vetosanya/presentation/karizma/karizma_screen.dart';

class NewsStub extends KarizmaBackend {
  String? uid = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  final opens = ValueNotifier<int>(0);
  Completer<List<Map<String, dynamic>>>? delayed;
  final savedNames = <String>[];
  bool empty = false;
  @override
  String? get accountId => uid;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  ValueListenable<int> get customerOpen => opens;
  List<Map<String, dynamic>> value() => [
    {
      'id': 'synthetic-post',
      'title': 'عنوان الخبر الأصلي',
      'body': 'Original post content',
      'image_url': '',
      'created_at': '2026-10-14T00:00:00Z',
      'likes': 1,
      'dislikes': 0,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> posts(String audience) async =>
      delayed?.future ?? (empty ? [] : value());
  @override
  Future<void> markSeen(String audience, DateTime latest) async {}
  @override
  Future<String?> nickname() async => 'Original nickname';
  @override
  Future<void> saveNickname(String text) async {
    savedNames.add(text);
  }

  @override
  Future<List<Map<String, dynamic>>> comments(
    String post,
    String audience,
  ) async => [];
}

Widget app(NewsStub backend, String language, bool dark) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: KarizmaScreen(audience: 'customer', backend: backend),
);
void main() {
  for (final language in ['ar', 'en'])
    for (final dark in [true, false]) {
      testWidgets(
        'News $language dark=$dark at320 keeps original authored content',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final b = NewsStub();
          addTearDown(b.changes.close);
          addTearDown(b.opens.dispose);
          await tester.pumpWidget(app(b, language, dark));
          await tester.pumpAndSettle();
          final l = lookupAppLocalizations(Locale(language));
          expect(find.text(l.newsTitle), findsOneWidget);
          expect(find.text('عنوان الخبر الأصلي'), findsOneWidget);
          expect(find.text('Original post content'), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.text(l.newsTitle))),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  testWidgets(
    'Late old-account posts cannot reappear after switching accounts',
    (tester) async {
      final old = Completer<List<Map<String, dynamic>>>();
      final b = NewsStub()..delayed = old;
      addTearDown(b.changes.close);
      addTearDown(b.opens.dispose);
      await tester.pumpWidget(app(b, 'en', false));
      await tester.pump();
      b.delayed = null;
      b.empty = true;
      b.uid = 'synthetic-b';
      b.changes.add(b.uid);
      await tester.pumpAndSettle();
      old.complete(b.value());
      await tester.pumpAndSettle();
      expect(find.text('Original post content'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Nickname cancellation survives reverse animation; same-account Auth refresh does not close it',
    (tester) async {
      final b = NewsStub()..empty = true;
      addTearDown(b.changes.close);
      addTearDown(b.opens.dispose);
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(app(b, 'en', true));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.newsDisplayName));
      await tester.pumpAndSettle();
      b.changes.add(b.uid);
      await tester.pump();
      expect(find.byType(NewsNicknameEditor), findsOneWidget);
      await tester.tap(find.text(l.newsCancel));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(b.savedNames, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Repeated account changes dismiss comments once without popping the parent screen',
    (tester) async {
      final b = NewsStub();
      addTearDown(b.changes.close);
      addTearDown(b.opens.dispose);
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(app(b, 'en', true));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.newsComments));
      await tester.pumpAndSettle();
      b.empty = true;
      b.uid = 'synthetic-b';
      b.changes.add(b.uid);
      b.uid = 'synthetic-c';
      b.changes.add(b.uid);
      await tester.pumpAndSettle();
      expect(find.byType(KarizmaScreen), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
