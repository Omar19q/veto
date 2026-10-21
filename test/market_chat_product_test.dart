import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/market_chat_backend.dart';
import 'package:vetosanya/presentation/vito_market/widgets/market_order_chat_sheet.dart';

class ChatStub extends MarketChatBackend {
  String uid = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  Completer<List<Map<String, dynamic>>>? delayed;
  Completer<void>? sendReceipt;
  bool failLoad = false, failSend = false;
  final sent = <String>[];
  @override
  String? get accountId => uid;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  RealtimeChannel? subscribe(String id, Future<void> Function() changed) =>
      null;
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<List<Map<String, dynamic>>> getMessages(String id) async {
    if (failLoad) throw StateError('synthetic');
    if (delayed != null) return delayed!.future;
    return [
      {
        'sender_user_id': 'synthetic-a',
        'sender_role': 'customer',
        'message_text': 'رسالة المستخدم الأصلية',
      },
      {
        'sender_user_id': 'synthetic-captain',
        'sender_role': 'captain',
        'message_text': 'Original captain message',
      },
    ];
  }

  @override
  Future<void> send(String id, String message) async {
    sent.add(message);
    if (sendReceipt != null) await sendReceipt!.future;
    if (failSend) throw StateError('synthetic-unconfirmed');
  }

  void switchTo(String id) {
    uid = id;
    changes.add(id);
  }
}

Widget app(ChatStub backend, String language, bool dark) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(
    body: MarketOrderChatSheet(
      orderId: 'synthetic-order',
      actorLabel: 'عميل',
      backend: backend,
    ),
  ),
);
void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets('Market chat $language dark=$dark literal messages at320', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final backend = ChatStub();
        addTearDown(backend.changes.close);
        await tester.pumpWidget(app(backend, language, dark));
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(language));
        expect(find.text(l.marketChatTitle), findsOneWidget);
        expect(find.text(l.marketChatYou), findsOneWidget);
        expect(find.text('رسالة المستخدم الأصلية'), findsOneWidget);
        expect(find.text('Original captain message'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Account change clears chat/draft and rejects pending old messages',
    (tester) async {
      final backend = ChatStub()
        ..delayed = Completer<List<Map<String, dynamic>>>();
      addTearDown(backend.changes.close);
      await tester.pumpWidget(app(backend, 'en', false));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        'Private previous-account draft',
      );
      backend.switchTo('synthetic-b');
      backend.delayed!.complete([
        {
          'sender_user_id': 'synthetic-a',
          'message_text': 'Old private message',
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Old private message'), findsNothing);
      expect(find.text('Private previous-account draft'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Closing chat before send acknowledgement cannot use disposed input',
    (tester) async {
      final backend = ChatStub()..sendReceipt = Completer<void>();
      addTearDown(backend.changes.close);
      await tester.pumpWidget(app(backend, 'en', true));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Synthetic message');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(backend.sent, ['Synthetic message']);
      await tester.pumpWidget(const SizedBox());
      backend.sendReceipt!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Unconfirmed send retains draft and does not auto resend', (
    tester,
  ) async {
    final backend = ChatStub()..failSend = true;
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend, 'en', true));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Synthetic draft');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.marketChatSendFailed), findsOneWidget);
    expect(backend.sent.length, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Synthetic draft',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Chat load error is not presented as empty conversation', (
    tester,
  ) async {
    final backend = ChatStub()..failLoad = true;
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend, 'en', true));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.marketChatLoadFailed), findsOneWidget);
    expect(find.text(l.marketChatEmpty), findsNothing);
    backend.failLoad = false;
    await tester.tap(find.text(l.retry));
    await tester.pumpAndSettle();
    expect(find.text('رسالة المستخدم الأصلية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Late send acknowledgement preserves the next message draft', (
    tester,
  ) async {
    final backend = ChatStub()..sendReceipt = Completer<void>();
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend, 'en', true));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First synthetic message');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Next synthetic draft');
    backend.sendReceipt!.complete();
    await tester.pumpAndSettle();
    expect(backend.sent, ['First synthetic message']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Next synthetic draft',
    );
    expect(tester.takeException(), isNull);
  });
}
