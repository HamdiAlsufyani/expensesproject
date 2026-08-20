import '../models.dart';

class AccountingService {
  const AccountingService();

  double balance({required double debit, required double credit}) =>
      debit - credit;

  BalanceStatus status(double value) {
    if (value > 0.000001) return BalanceStatus.debtor;
    if (value < -0.000001) return BalanceStatus.creditor;
    return BalanceStatus.settled;
  }

  List<StatementLine> runningStatement(
    List<FinancialTransaction> transactions,
  ) {
    var balance = 0.0;
    return transactions
        .map((transaction) {
          final debit = transaction.type == TransactionType.debit
              ? transaction.amount
              : 0.0;
          final credit = transaction.type == TransactionType.credit
              ? transaction.amount
              : 0.0;
          balance += debit - credit;
          return StatementLine(
            transaction: transaction,
            debit: debit,
            credit: credit,
            balance: balance,
          );
        })
        .toList(growable: false);
  }
}

enum BalanceStatus { debtor, creditor, settled }
