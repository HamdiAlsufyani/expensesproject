import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../shared/components/common_widgets.dart';
import '../../../shared/localization_extensions.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    return summary.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(context.l10n.loading),
          ],
        ),
      ),
      error: (_, _) => EmptyState(
        message: context.l10n.operationFailed,
        icon: Icons.error_outline,
        action: OutlinedButton(
          onPressed: () => ref.invalidate(dashboardProvider),
          child: Text(context.l10n.retry),
        ),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.l10n.overview,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _MetricGrid(summary: data),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final charts = [
                  Expanded(child: _IncomeExpenseChart(summary: data)),
                  const SizedBox(width: 18, height: 18),
                  Expanded(child: _CategoryChart(summary: data)),
                ];
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: charts,
                      )
                    : Column(children: charts);
              },
            ),
            const SizedBox(height: 18),
            _MonthlyChart(summary: data),
            const SizedBox(height: 18),
            _RecentTransactions(),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        context.l10n.totalIncome,
        context.money(summary.income),
        Icons.trending_up_rounded,
        const Color(0xFF15803D),
      ),
      (
        context.l10n.totalExpenses,
        context.money(summary.expenses),
        Icons.trending_down_rounded,
        const Color(0xFFB42318),
      ),
      (
        context.l10n.netBalance,
        context.money(summary.netBalance),
        Icons.account_balance_wallet_outlined,
        Theme.of(context).colorScheme.primary,
      ),
      (
        context.l10n.customerDebit,
        context.money(summary.customerDebit),
        Icons.person_outline,
        const Color(0xFFB45309),
      ),
      (
        context.l10n.customerCredit,
        context.money(summary.customerCredit),
        Icons.person_add_alt_1_outlined,
        const Color(0xFF0F766E),
      ),
      (
        context.l10n.supplierDebit,
        context.money(summary.supplierDebit),
        Icons.local_shipping_outlined,
        const Color(0xFFB45309),
      ),
      (
        context.l10n.supplierCredit,
        context.money(summary.supplierCredit),
        Icons.inventory_2_outlined,
        const Color(0xFF0F766E),
      ),
      (
        context.l10n.customerCount,
        '${summary.customerCount}',
        Icons.groups_2_outlined,
        Theme.of(context).colorScheme.primary,
      ),
      (
        context.l10n.supplierCount,
        '${summary.supplierCount}',
        Icons.factory_outlined,
        Theme.of(context).colorScheme.primary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 3
            : width >= 620
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 88,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return MetricCard(
              label: item.$1,
              value: item.$2,
              icon: item.$3,
              color: item.$4,
            );
          },
        );
      },
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: SizedBox(
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.incomeVsExpenses,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY:
                    [
                      summary.income,
                      summary.expenses,
                      1,
                    ].reduce((a, b) => a > b ? a : b) *
                    1.25,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          value == 0
                              ? context.l10n.income
                              : context.l10n.expense,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: summary.income,
                        color: const Color(0xFF15803D),
                        width: 36,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: summary.expenses,
                        color: const Color(0xFFB42318),
                        width: 36,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.expenseCategories.entries.take(5).toList();
    final palette = [
      const Color(0xFF14532D),
      const Color(0xFF0F766E),
      const Color(0xFFB45309),
      const Color(0xFF7C3AED),
      const Color(0xFFB42318),
    ];
    return SectionCard(
      child: SizedBox(
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.expensesByCategory,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: entries.isEmpty
                  ? EmptyState(
                      message: context.l10n.noData,
                      icon: Icons.pie_chart_outline,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 28,
                              sections: [
                                for (var i = 0; i < entries.length; i++)
                                  PieChartSectionData(
                                    value: entries[i].value,
                                    color: palette[i],
                                    radius: 42,
                                    title: '',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 112,
                          child: ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: palette[index],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      entries[index].key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final months = {
      ...summary.monthlyIncome.keys,
      ...summary.monthlyExpense.keys,
    }.toList()..sort();
    final maxValue = [
      ...summary.monthlyIncome.values,
      ...summary.monthlyExpense.values,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    return SectionCard(
      child: SizedBox(
        height: 270,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.monthlyActivity,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: months.isEmpty
                  ? EmptyState(
                      message: context.l10n.noData,
                      icon: Icons.show_chart,
                    )
                  : BarChart(
                      BarChartData(
                        maxY: maxValue * 1.25,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: maxValue / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Theme.of(context).dividerColor
                                .withValues(alpha: .45),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              getTitlesWidget: (value, _) {
                                final index = value.toInt();
                                return index >= 0 && index < months.length
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          context.month(months[index]),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      )
                                    : const SizedBox();
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < months.length; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 4,
                              barRods: [
                                BarChartRodData(
                                  toY: summary.monthlyIncome[months[i]] ?? 0,
                                  color: const Color(0xFF15803D),
                                  width: 10,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                BarChartRodData(
                                  toY: summary.monthlyExpense[months[i]] ?? 0,
                                  color: const Color(0xFFB42318),
                                  width: 10,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(recentTransactionsProvider);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.recentActivity,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          transactions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(context.l10n.operationFailed),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.l10n.noData),
                  )
                : Column(
                    children: [
                      for (final item in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                (item.type == TransactionType.income
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB42318))
                                    .withValues(alpha: .12),
                            child: Icon(
                              item.type == TransactionType.income
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: item.type == TransactionType.income
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB42318),
                            ),
                          ),
                          title: Text(item.description),
                          subtitle: Text(context.date(item.transactionDate)),
                          trailing: Text(
                            context.money(item.amount),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
