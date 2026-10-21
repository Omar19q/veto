import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'growth_service.dart';

/// Generates a print-ready *landscape* A4 master.
///
/// Car: a wide seat-back display. Motorcycle: an 80 x 110 mm cut-out on an A4
/// landscape sheet with safe-placement guidance; never attach an A4 sheet to a
/// motorcycle or obscure the plate, lights or the rider's field of view.
class GrowthBadgePdf {
  static final PdfPageFormat a4Landscape = PdfPageFormat.a4.landscape;
  static const _gold = PdfColor.fromInt(0xFFD6AC45);
  static const _navy = PdfColor.fromInt(0xFF101722);

  static bool validCode(String code) =>
      RegExp(r'^[0-9]{4,19}$').hasMatch(code) &&
      BigInt.parse(code) >= BigInt.from(1001);

  static Future<Uint8List> buildA4(
    String code, {
    bool motorcycle = false,
    String title = 'VETO SANYA',
    bool sample = false,
  }) async {
    if (!validCode(code)) throw ArgumentError('invalid_captain_referral_code');
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo.ttf'));
    final logo = await rootBundle.loadString(
      'assets/images/veto_sanya_logo_mark.svg',
    );
    final document = pw.Document(
      title: 'VETO SANYA – A4 landscape captain referral badge',
      author: 'VETO SANYA',
    );

    pw.Widget label(
      String value,
      double size, {
      bool arabic = false,
      PdfColor color = PdfColors.white,
    }) => pw.Directionality(
      textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Text(
        value,
        maxLines: 3,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: size, color: color),
      ),
    );

    pw.Widget qr(double dimension) => pw.Container(
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(8),
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: GrowthService.referralLink(code).toString(),
        drawText: false,
        width: dimension,
        height: dimension,
      ),
    );

    pw.Widget marketingCard({required bool compact}) {
      if (compact) {
        return pw.Container(
          width: 80 * PdfPageFormat.mm,
          height: 110 * PdfPageFormat.mm,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _navy,
            border: pw.Border.all(color: _gold, width: 2),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SvgImage(svg: logo, width: 28, height: 28),
              label(title, 13, color: _gold),
              label('أول مشوار بخصم 50%', 16, arabic: true, color: _gold),
              label('50% OFF FIRST RIDE', 9, color: _gold),
              qr(31 * PdfPageFormat.mm),
              label('امسح الكود وحمّل التطبيق', 9, arabic: true),
              label('SCAN TO DOWNLOAD', 8),
              label(code, 20, color: _gold),
              label('للعميل الجديد المؤهل حسب شروط العرض', 6, arabic: true),
              if (sample) label('SAMPLE — DO NOT DISTRIBUTE', 6, color: _gold),
            ],
          ),
        );
      }
      return pw.Container(
        width: double.infinity,
        height: 190 * PdfPageFormat.mm,
        padding: const pw.EdgeInsets.all(22),
        decoration: pw.BoxDecoration(
          color: _navy,
          border: pw.Border.all(color: _gold, width: 2.5),
          borderRadius: pw.BorderRadius.circular(18),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SvgImage(svg: logo, width: 72, height: 72),
                  label(title, 26, color: _gold),
                  label('أول مشوار بخصم 50%', 31, arabic: true, color: _gold),
                  label('50% OFF YOUR FIRST RIDE', 18, color: _gold),
                  label('مشوارك بسهولة… في ثانية', 17, arabic: true),
                  label('Your ride, just one tap away.', 13),
                  label('خصم أول رحلة للعملاء الجدد المؤهلين وفق شروط العرض',
                      10, arabic: true),
                  label('Eligible new customers. Offer terms apply.', 9),
                  if (sample)
                    label('نموذج تجريبي — SAMPLE — DO NOT DISTRIBUTE',
                        10, arabic: true, color: _gold),
                ],
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Container(width: 1, height: 135 * PdfPageFormat.mm, color: _gold),
            pw.SizedBox(width: 14),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  label('امسح وحمّل', 20, arabic: true, color: _gold),
                  label('SCAN & DOWNLOAD', 12, color: _gold),
                  qr(61 * PdfPageFormat.mm),
                  label('كود الكابتن / CAPTAIN CODE', 12, arabic: true),
                  label(code, 39, color: _gold),
                  label('استخدم الكود عند التسجيل', 12, arabic: true),
                  label('Enter this code when signing up', 9),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Approved A4 horizontal marketing master. The rendered design is purely
    // visual; the sample code/QR embedded in the artwork are fully covered by
    // a fresh, functional code card for the authenticated captain.
    final badgeBackground = motorcycle ? null : pw.MemoryImage(
      (await rootBundle.load('assets/images/veto_badge_premium_master.png'))
          .buffer.asUint8List(),
    );
    document.addPage(
      pw.Page(
        pageFormat: a4Landscape,
        margin: pw.EdgeInsets.zero,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => !motorcycle
            ? pw.Stack(children: [
                pw.Image(badgeBackground!, width: a4Landscape.width,
                  height: a4Landscape.height, fit: pw.BoxFit.fill),
                pw.Positioned(
                  // Cover the sample artwork's QR and code completely.
                  // Never ship a shared/sample referral identifier as a printed badge.
                  left: a4Landscape.width * 0.706,
                  top: a4Landscape.height * 0.495,
                  child: pw.Container(
                    width: a4Landscape.width * 0.276,
                    height: a4Landscape.height * 0.485,
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: _navy,
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: _gold, width: 2.5),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        label('امسح وحمّل التطبيق', 11,
                          arabic: true, color: _gold),
                        qr(57 * PdfPageFormat.mm),
                        label('كود الكابتن', 10, arabic: true),
                        label(code, 25, color: _gold),
                        if (sample) label('SAMPLE', 7, color: _gold),
                      ],
                    ),
                  ),
                ),
              ])
            : pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  marketingCard(compact: true),
                  pw.SizedBox(width: 12 * PdfPageFormat.mm),
                  pw.Expanded(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        label('بطاقة الموتوسيكل', 20, arabic: true, color: _navy),
                        pw.SizedBox(height: 14),
                        label('قص البطاقة وثبّتها على حقيبة آمنة، بعيدًا عن اللوحة والمصابيح ومجال رؤية السائق.',
                            13, arabic: true, color: _navy),
                        pw.SizedBox(height: 10),
                        label('Cut out the card and attach it to a secure bag. Do not obstruct lights, plate or vision.',
                            10, color: _navy),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
    return document.save();
  }

  /// Legacy small-format badge is kept for compatibility with older screens.
  static Future<Uint8List> build(
    String code, {
    bool motorcycle = false,
    String title = 'فيتو ثانية',
    String message = 'امسح الكود وحمّل التطبيق',
  }) async {
    if (!validCode(code)) throw ArgumentError('invalid_captain_referral_code');
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo.ttf'));
    final logo = await rootBundle.loadString(
      'assets/images/veto_sanya_logo_mark.svg',
    );
    final document = pw.Document(
      title: 'VETO SANYA referral badge',
      author: 'VETO SANYA',
    );
    final size = motorcycle
        ? const PdfPageFormat(80 * PdfPageFormat.mm, 110 * PdfPageFormat.mm)
        : const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm);
    document.addPage(
      pw.Page(
        pageFormat: size,
        margin: const pw.EdgeInsets.all(12),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => pw.Center(
          child: pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SvgImage(
                  svg: logo,
                  width: motorcycle ? 36 : 65,
                  height: motorcycle ? 36 : 65,
                ),
                pw.Text(title,
                    style: pw.TextStyle(font: font, fontSize: motorcycle ? 16 : 20)),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.BarcodeWidget(
                    drawText: false,
                    barcode: pw.Barcode.qrCode(),
                    data: GrowthService.referralLink(code).toString(),
                    width: (motorcycle ? 42 : 50) * PdfPageFormat.mm,
                    height: (motorcycle ? 42 : 50) * PdfPageFormat.mm,
                  ),
                ),
                pw.Text('كود الدعوة: $code',
                    style: pw.TextStyle(font: font, fontSize: motorcycle ? 13 : 16)),
                pw.Text(message,
                    style: pw.TextStyle(font: font, fontSize: motorcycle ? 9 : 12)),
                pw.Text('العروض حسب شروط الحملة',
                    style: pw.TextStyle(font: font, fontSize: motorcycle ? 7 : 9)),
              ],
            ),
          ),
        ),
      ),
    );
    return document.save();
  }
}
