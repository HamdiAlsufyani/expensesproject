import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../shared/components/common_widgets.dart';
import '../../../shared/localization_extensions.dart';
import '../../transactions/data/transaction_repository.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateRange _range = const DateRange();

  @override
  Widget build(BuildContext context) {
    ref.watch(dataChangeProvider);
    final reports = ref.read(reportRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reports),
        actions: [
          IconButton(
            onPressed: _chooseRange,
            tooltip: context.l10n.filter,
            icon: const Icon(Icons.date_range_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([
          reports.financialSummary(range: _range),
          reports.partyReport(PartyType.customer, range: _range),
          reports.partyReport(PartyType.supplier, range: _range),
          reports.expenseReport(range: _range),
          reports.transactionReport(filter: TransactionFilter(range: _range)),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              message: context.l10n.operationFailed,
              icon: Icons.error_outline,
            );
          }
          final dashboard = snapshot.data![0] as DashboardSummary;
          final customers = snapshot.data![1] as List<PartyBalance>;
          final suppliers = snapshot.data![2] as List<PartyBalance>;
          final expenses = snapshot.data![3] as List<ExpenseReportRow>;
          final transactions = snapshot.data![4] as List<TransactionReportRow>;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _FinancialSummary(summary: dashboard),
              const SizedBox(height: 20),
              _PartyReport(
                title: context.l10n.customerReport,
                items: customers,
              ),
              const SizedBox(height: 20),
              _PartyReport(
                title: context.l10n.supplierReport,
                items: suppliers,
              ),
              const SizedBox(height: 20),
              _ExpenseReport(items: expenses),
              const SizedBox(height: 20),
              _TransactionReport(items: transactions),
            ],
          );
        },
      ),
    );
  }

  Future<void> _chooseRange() async {
    final now = DateTime.now();
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<DateRange>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            runSpacing: 8,
            children: [
              Text(
                l10n.filter,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              ListTile(
                title: Text(l10n.allTime),
                leading: const Icon(Icons.all_inclusive),
                onTap: () => Navigator.pop(context, const DateRange()),
              ),
              ListTile(
                title: Text(l10n.today),
                leading: const Icon(Icons.today_outlined),
                onTap: () => Navigator.pop(context, DateRange.today(now)),
              ),
              ListTile(
                title: Text(l10n.thisWeek),
                leading: const Icon(Icons.date_range_outlined),
                onTap: () => Navigator.pop(context, DateRange.thisWeek(now)),
              ),
              ListTile(
                title: Text(l10n.thisMonth),
                leading: const Icon(Icons.calendar_month_outlined),
                onTap: () => Navigator.pop(context, DateRange.thisMonth(now)),
              ),
              ListTile(
                title: Text(l10n.thisYear),
                leading: const Icon(Icons.calendar_today_outlined),
                onTap: () => Navigator.pop(context, DateRange.thisYear(now)),
              ),
              ListTile(
                title: Text(l10n.customRange),
                leading: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (!mounted || range == null) return;
                  Navigator.pop(
                    context,
                    DateRange(start: range.start, end: range.end),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _range = selected);
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.financialSummary,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ReportMetric(
              label: context.l10n.totalIncome,
              value: context.money(summary.income),
              color: const Color(0xFF15803D),
            ),
            _ReportMetric(
              label: context.l10n.totalExpenses,
              value: context.money(summary.expenses),
              color: const Color(0xFFB42318),
            ),
            _ReportMetric(
              label: context.l10n.netProfitLoss,
              value: context.money(summary.netBalance),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ],
    ),
  );
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
      ],
    ),
  );
}

class _PartyReport extends ConsumerWidget {
  const _PartyReport({required this.title, required this.items});
  final String title;
  final List<PartyBalance> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      SectionCard(
        padding: EdgeInsets.zero,
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(context.l10n.noData)),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.l10n.name)),
                    DataColumn(label: Text(context.l10n.debit), numeric: true),
                    DataColumn(label: Text(context.l10n.credit), numeric: true),
                    DataColumn(
                      label: Text(context.l10n.balance),
                      numeric: true,
                    ),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        cells: [
                          DataCell(Text(item.party.name)),
                          DataCell(Text(context.money(item.debit))),
                          DataCell(Text(context.money(item.credit))),
                          DataCell(Text(context.money(item.balance))),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
}

class _ExpenseReport extends StatelessWidget {
  const _ExpenseReport({required this.items});
  final List<ExpenseReportRow> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.expenseReport,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      SectionCard(
        padding: EdgeInsets.zero,
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(context.l10n.noData)),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.l10n.category)),
                    DataColumn(
                      label: Text(context.l10n.transactionCount),
                      numeric: true,
                    ),
                    DataColumn(label: Text(context.l10n.amount), numeric: true),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        cells: [
                          DataCell(Text(item.category)),
                          DataCell(Text('${item.count}')),
                          DataCell(Text(context.money(item.total))),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
}

class _TransactionReport extends ConsumerWidget {
  const _TransactionReport({required this.items});
  final List<TransactionReportRow> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.transactionReport,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      SectionCard(
        padding: EdgeInsets.zero,
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(context.l10n.noData)),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.l10n.date)),
                    DataColumn(label: Text(context.l10n.transactionType)),
                    DataColumn(label: Text(context.l10n.party)),
                    DataColumn(label: Text(context.l10n.description)),
                    DataColumn(label: Text(context.l10n.debit), numeric: true),
                    DataColumn(label: Text(context.l10n.credit), numeric: true),
                  ],
                  rows: [
                    for (final row in items)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(context.date(row.transaction.transactionDate)),
                          ),
                          DataCell(
                            Text(row.transaction.type.label(context.l10n)),
                          ),
                          DataCell(
                            Text(
                              row.partyName.isEmpty
                                  ? row.transaction.partyType.label(
                                      context.l10n,
                                    )
                                  : row.partyName,
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 190,
                              child: Text(
                                row.transaction.description,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              row.transaction.type == TransactionType.debit
                                  ? context.money(row.transaction.amount)
                                  : '—',
                            ),
                          ),
                          DataCell(
                            Text(
                              row.transaction.type == TransactionType.credit
                                  ? context.money(row.transaction.amount)
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
}
