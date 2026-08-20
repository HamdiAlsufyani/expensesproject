import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models.dart';
import '../core/services/accounting_service.dart';
import '../l10n/app_localizations.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String money(double value) {
    final locale = Localizations.localeOf(this).toString();
    final symbol = locale.startsWith('ar') ? 'ر.س' : 'SAR';
    return NumberFormat.currency(
      locale: locale,
      name: 'SAR',
      symbol: symbol,
      decimalDigits: 2,
    ).format(value);
  }

  String date(DateTime value) =>
      DateFormat.yMMMd(Localizations.localeOf(this).toString()).format(value);
  String month(String value) =>
      DateFormat.yMMM(Localizations.localeOf(this).toString())
          .format(DateTime.parse('$value-01'));
}

extension LocalizedTransactionType on TransactionType {
  String label(AppLocalizations l10n) => switch (this) {
    TransactionType.debit => l10n.debit,
    TransactionType.credit => l10n.credit,
    TransactionType.expense => l10n.expense,
    TransactionType.income => l10n.income,
  };
}

extension LocalizedPartyType on PartyType {
  String label(AppLocalizations l10n) => switch (this) {
    PartyType.customer => l10n.customer,
    PartyType.supplier => l10n.supplier,
    PartyType.general => l10n.general,
  };
}

extension LocalizedPaymentMethod on PaymentMethod {
  String label(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cash => l10n.cash,
    PaymentMethod.bankTransfer => l10n.bankTransfer,
    PaymentMethod.card => l10n.card,
    PaymentMethod.other => l10n.other,
  };
}

extension LocalizedBalanceStatus on BalanceStatus {
  String label(AppLocalizations l10n) => switch (this) {
    BalanceStatus.debtor => l10n.debtor,
    BalanceStatus.creditor => l10n.creditor,
    BalanceStatus.settled => l10n.settled,
  };

  Color color(ColorScheme scheme) => switch (this) {
    BalanceStatus.debtor => scheme.error,
    BalanceStatus.creditor => const Color(0xFF0F766E),
    BalanceStatus.settled => scheme.primary,
  };
}
