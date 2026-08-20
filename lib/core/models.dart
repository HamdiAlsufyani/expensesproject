import 'dart:convert';

typedef DbRow = Map<String, Object?>;

enum PartyType { customer, supplier, general }

enum TransactionType { debit, credit, expense, income }

enum PaymentMethod { cash, bankTransfer, card, other }

extension PartyTypeValue on PartyType {
  String get value => name;
  static PartyType fromDb(String value) => PartyType.values.byName(value);
}

extension TransactionTypeValue on TransactionType {
  String get value => name;
  static TransactionType fromDb(String value) =>
      TransactionType.values.byName(value);
}

extension PaymentMethodValue on PaymentMethod {
  String get value => name;
  static PaymentMethod fromDb(String value) =>
      PaymentMethod.values.byName(value);
}

String isoDate(DateTime value) =>
    DateTime(value.year, value.month, value.day).toIso8601String();
String isoTimestamp(DateTime value) => value.toUtc().toIso8601String();
DateTime dbDate(Object? value) => DateTime.parse(value! as String);
String nowDb() => isoTimestamp(DateTime.now());

class Party {
  const Party({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Party copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Party(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  DbRow toMap({bool withId = false}) => {
    if (withId && id != null) 'id': id,
    'name': name.trim(),
    'phone': _nullableText(phone),
    'email': _nullableText(email),
    'address': _nullableText(address),
    'notes': _nullableText(notes),
    'created_at': createdAt == null ? nowDb() : isoTimestamp(createdAt!),
    'updated_at': updatedAt == null ? nowDb() : isoTimestamp(updatedAt!),
  };

  static Party fromMap(DbRow row) => Party(
    id: row['id'] as int?,
    name: row['name']! as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    address: row['address'] as String?,
    notes: row['notes'] as String?,
    createdAt: row['created_at'] == null ? null : dbDate(row['created_at']),
    updatedAt: row['updated_at'] == null ? null : dbDate(row['updated_at']),
  );
}

class FinancialTransaction {
  const FinancialTransaction({
    this.id,
    required this.type,
    required this.partyType,
    this.partyId,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final TransactionType type;
  final PartyType partyType;
  final int? partyId;
  final double amount;
  final String description;
  final DateTime transactionDate;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FinancialTransaction copyWith({
    int? id,
    TransactionType? type,
    PartyType? partyType,
    int? partyId,
    double? amount,
    String? description,
    DateTime? transactionDate,
    PaymentMethod? paymentMethod,
    String? referenceNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FinancialTransaction(
    id: id ?? this.id,
    type: type ?? this.type,
    partyType: partyType ?? this.partyType,
    partyId: partyId ?? this.partyId,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    transactionDate: transactionDate ?? this.transactionDate,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    referenceNumber: referenceNumber ?? this.referenceNumber,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  DbRow toMap({bool withId = false}) => {
    if (withId && id != null) 'id': id,
    'type': type.value,
    'party_type': partyType.value,
    'party_id': partyId,
    'amount': amount,
    'description': description.trim(),
    'transaction_date': isoDate(transactionDate),
    'payment_method': paymentMethod.value,
    'reference_number': _nullableText(referenceNumber),
    'notes': _nullableText(notes),
    'created_at': createdAt == null ? nowDb() : isoTimestamp(createdAt!),
    'updated_at': updatedAt == null ? nowDb() : isoTimestamp(updatedAt!),
  };

  static FinancialTransaction fromMap(DbRow row) => FinancialTransaction(
    id: row['id'] as int?,
    type: TransactionTypeValue.fromDb(row['type']! as String),
    partyType: PartyTypeValue.fromDb(row['party_type']! as String),
    partyId: row['party_id'] as int?,
    amount: (row['amount']! as num).toDouble(),
    description: row['description']! as String,
    transactionDate: dbDate(row['transaction_date']),
    paymentMethod: PaymentMethodValue.fromDb(row['payment_method']! as String),
    referenceNumber: row['reference_number'] as String?,
    notes: row['notes'] as String?,
    createdAt: row['created_at'] == null ? null : dbDate(row['created_at']),
    updatedAt: row['updated_at'] == null ? null : dbDate(row['updated_at']),
  );
}

class ExpenseCategory {
  const ExpenseCategory({
    this.id,
    required this.name,
    this.description,
    this.createdAt,
  });
  final int? id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  DbRow toMap({bool withId = false}) => {
    if (withId && id != null) 'id': id,
    'name': name.trim(),
    'description': _nullableText(description),
    'created_at': createdAt == null ? nowDb() : isoTimestamp(createdAt!),
  };

  static ExpenseCategory fromMap(DbRow row) => ExpenseCategory(
    id: row['id'] as int?,
    name: row['name']! as String,
    description: row['description'] as String?,
    createdAt: row['created_at'] == null ? null : dbDate(row['created_at']),
  );
}

class GeneralExpense {
  const GeneralExpense({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.description,
    required this.expenseDate,
    required this.paymentMethod,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int categoryId;
  final double amount;
  final String description;
  final DateTime expenseDate;
  final PaymentMethod paymentMethod;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GeneralExpense copyWith({
    int? id,
    int? categoryId,
    double? amount,
    String? description,
    DateTime? expenseDate,
    PaymentMethod? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GeneralExpense(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    expenseDate: expenseDate ?? this.expenseDate,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  DbRow toMap({bool withId = false}) => {
    if (withId && id != null) 'id': id,
    'category_id': categoryId,
    'amount': amount,
    'description': description.trim(),
    'expense_date': isoDate(expenseDate),
    'payment_method': paymentMethod.value,
    'notes': _nullableText(notes),
    'created_at': createdAt == null ? nowDb() : isoTimestamp(createdAt!),
    'updated_at': updatedAt == null ? nowDb() : isoTimestamp(updatedAt!),
  };

  static GeneralExpense fromMap(DbRow row) => GeneralExpense(
    id: row['id'] as int?,
    categoryId: row['category_id']! as int,
    amount: (row['amount']! as num).toDouble(),
    description: row['description']! as String,
    expenseDate: dbDate(row['expense_date']),
    paymentMethod: PaymentMethodValue.fromDb(row['payment_method']! as String),
    notes: row['notes'] as String?,
    createdAt: row['created_at'] == null ? null : dbDate(row['created_at']),
    updatedAt: row['updated_at'] == null ? null : dbDate(row['updated_at']),
  );
}

class PartyBalance {
  const PartyBalance({
    required this.party,
    required this.debit,
    required this.credit,
  });
  final Party party;
  final double debit;
  final double credit;
  double get balance => debit - credit;
}

class StatementLine {
  const StatementLine({
    required this.transaction,
    required this.debit,
    required this.credit,
    required this.balance,
  });
  final FinancialTransaction transaction;
  final double debit;
  final double credit;
  final double balance;
}

class DateRange {
  const DateRange({this.start, this.end});
  final DateTime? start;
  final DateTime? end;
  bool get isBounded => start != null || end != null;

  static DateRange today(DateTime now) => DateRange(
    start: DateTime(now.year, now.month, now.day),
    end: DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
  static DateRange thisWeek(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final start = day.subtract(Duration(days: day.weekday - 1));
    return DateRange(
      start: start,
      end: start.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      ),
    );
  }

  static DateRange thisMonth(DateTime now) => DateRange(
    start: DateTime(now.year, now.month),
    end: DateTime(now.year, now.month + 1).subtract(const Duration(seconds: 1)),
  );
  static DateRange thisYear(DateTime now) => DateRange(
    start: DateTime(now.year),
    end: DateTime(now.year + 1).subtract(const Duration(seconds: 1)),
  );
}

class DashboardSummary {
  const DashboardSummary({
    required this.income,
    required this.expenses,
    required this.customerDebit,
    required this.customerCredit,
    required this.supplierDebit,
    required this.supplierCredit,
    required this.customerCount,
    required this.supplierCount,
    required this.expenseCategories,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });
  final double income;
  final double expenses;
  final double customerDebit;
  final double customerCredit;
  final double supplierDebit;
  final double supplierCredit;
  final int customerCount;
  final int supplierCount;
  final Map<String, double> expenseCategories;
  final Map<String, double> monthlyIncome;
  final Map<String, double> monthlyExpense;
  double get netBalance => income - expenses;
}

class ExpenseReportRow {
  const ExpenseReportRow({
    required this.category,
    required this.count,
    required this.total,
  });
  final String category;
  final int count;
  final double total;
}

class TransactionReportRow {
  const TransactionReportRow({
    required this.transaction,
    required this.partyName,
  });
  final FinancialTransaction transaction;
  final String partyName;
}

String? _nullableText(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String encodeRows(List<DbRow> rows) => jsonEncode(rows);
