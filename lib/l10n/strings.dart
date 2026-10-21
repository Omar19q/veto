import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

extension ProductStrings on BuildContext {
  AppLocalizations get strings => Localizations.of<AppLocalizations>(this,AppLocalizations) ?? lookupAppLocalizations(const Locale('ar'));
}
