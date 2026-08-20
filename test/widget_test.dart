import 'package:flutter_test/flutter_test.dart';

import 'package:expensesproject/l10n/app_localizations.dart';

void main() {
  test('Ledgerly supports Arabic and English', () {
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      containsAll(<String>['ar', 'en']),
    );
  });
}
