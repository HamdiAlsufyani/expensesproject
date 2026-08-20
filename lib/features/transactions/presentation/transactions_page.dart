import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../shared/components/common_widgets.dart';
import '../../../shared/localization_extensions.dart';
import '../data/transaction_repository.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String _query = '';
  TransactionFilter _filter = const TransactionFilter();

  @override
  Widget build(BuildContext context) {
    ref.watch(dataChangeProvider);
    final filter = TransactionFilter(
      range: _filter.range,
      partyType: _filter.partyType,
      partyId: _filter.partyId,
      type: _filter.type,
      paymentMethod: _filter.paymentMethod,
      query: _query,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.transactions),
        actions: [
          IconButton(
            onPressed: _openFilter,
            tooltip: context.l10n.filter,
            icon: Badge(
              isLabelVisible: _filter != const TransactionFilter(),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addTransaction),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SearchBar(
              leading: const Icon(Icons.search),
              hintText: context.l10n.search,
              onChanged: (value) => setState(() => _query = value),
              trailing: _query.isEmpty
                  ? null
                  : [
                      IconButton(
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(Icons.close),
                      ),
                    ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<FinancialTransaction>>(
                future: ref
                    .read(transactionRepositoryProvider)
                    .list(filter: filter, limit: 100),
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
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return EmptyState(
                      message: _query.isEmpty
                          ? context.l10n.noData
                          : context.l10n.noResults,
                      icon: Icons.receipt_long_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _TransactionCard(
                      item: items[index],
                      onEdit: () => _openForm(items[index]),
                      onDelete: () => _delete(items[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm([FinancialTransaction? item]) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TransactionFormSheet(existing: item),
      );

  Future<void> _delete(FinancialTransaction item) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: context.l10n.deleteTitle,
      message: context.l10n.deleteMessage,
      cancel: context.l10n.cancel,
      confirm: context.l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(transactionRepositoryProvider).delete(item.id!);
      if (mounted) showFeedback(context, message: context.l10n.recordDeleted);
    } catch (error) {
      if (mounted) {
        showFeedback(
          context,
          message: safeErrorMessage(error, context.l10n),
          error: true,
        );
      }
    }
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }
}

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final FinancialTransaction item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPositive =
        item.type == TransactionType.income ||
        item.type == TransactionType.credit;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              (isPositive ? const Color(0xFF15803D) : const Color(0xFFB42318))
                  .withValues(alpha: .12),
          child: Icon(
            isPositive
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: isPositive
                ? const Color(0xFF15803D)
                : const Color(0xFFB42318),
          ),
        ),
        title: Text(
          item.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${item.type.label(context.l10n)} • ${context.date(item.transactionDate)}${item.referenceNumber == null ? '' : ' • ${item.referenceNumber}'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.money(item.amount),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isPositive
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB42318),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.l10n.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.existing});
  final FinancialTransaction? existing;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _reference;
  late final TextEditingController _notes;
  late TransactionType _type;
  late PartyType _partyType;
  int? _partyId;
  late PaymentMethod _method;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _amount = TextEditingController(text: item?.amount.toString() ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _reference = TextEditingController(text: item?.referenceNumber ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _type = item?.type ?? TransactionType.income;
    _partyType = item?.partyType ?? PartyType.general;
    _partyId = item?.partyId;
    _method = item?.paymentMethod ?? PaymentMethod.cash;
    _date = item?.transactionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.existing == null
                      ? l10n.addTransaction
                      : l10n.editTransaction,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<PartyType>(
                  initialValue: _partyType,
                  decoration: InputDecoration(labelText: l10n.partyType),
                  items: PartyType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label(l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _partyType = value!;
                    _partyId = null;
                    _type = value == PartyType.general
                        ? TransactionType.income
                        : TransactionType.debit;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TransactionType>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l10n.transactionType),
                  items: _typesForParty
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label(l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _type = value!),
                ),
                if (_partyType != PartyType.general) ...[
                  const SizedBox(height: 12),
                  _PartySelector(
                    type: _partyType,
                    value: _partyId,
                    onChanged: (value) => setState(() => _partyId = value),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.amount),
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) > 0
                      ? null
                      : l10n.invalidAmount,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: InputDecoration(labelText: l10n.description),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _method,
                  decoration: InputDecoration(labelText: l10n.paymentMethod),
                  items: PaymentMethod.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label(l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _method = value!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  title: Text(l10n.date),
                  subtitle: Text(context.date(_date)),
                  leading: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reference,
                  decoration: InputDecoration(labelText: l10n.referenceNumber),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l10n.notes),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<TransactionType> get _typesForParty => _partyType == PartyType.general
      ? [TransactionType.income, TransactionType.expense]
      : [TransactionType.debit, TransactionType.credit];

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_partyType != PartyType.general && _partyId == null) {
      showFeedback(context, message: context.l10n.requiredField, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .save(
            FinancialTransaction(
              id: widget.existing?.id,
              type: _type,
              partyType: _partyType,
              partyId: _partyId,
              amount: double.parse(_amount.text),
              description: _description.text,
              transactionDate: _date,
              paymentMethod: _method,
              referenceNumber: _reference.text,
              notes: _notes.text,
              createdAt: widget.existing?.createdAt,
            ),
          );
      if (mounted) {
        Navigator.pop(context);
        showFeedback(context, message: context.l10n.recordSaved);
      }
    } catch (error) {
      if (mounted) {
        showFeedback(
          context,
          message: safeErrorMessage(error, context.l10n),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PartySelector extends ConsumerWidget {
  const _PartySelector({
    required this.type,
    required this.value,
    required this.onChanged,
  });
  final PartyType type;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = type == PartyType.customer
        ? ref.read(customerRepositoryProvider)
        : ref.read(supplierRepositoryProvider);
    return FutureBuilder<List<Party>>(
      future: repository.list(limit: 500),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        return DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(labelText: context.l10n.party),
          items: items
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: snapshot.connectionState == ConnectionState.done
              ? onChanged
              : null,
          validator: (value) =>
              value == null ? context.l10n.requiredField : null,
        );
      },
    );
  }
}

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({super.key, required this.initial});
  final TransactionFilter initial;

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late PartyType? _partyType;
  late TransactionType? _type;
  late PaymentMethod? _method;
  late DateRange _range;

  @override
  void initState() {
    super.initState();
    _partyType = widget.initial.partyType;
    _type = widget.initial.type;
    _method = widget.initial.paymentMethod;
    _range = widget.initial.range;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.filter,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<PartyType?>(
              initialValue: _partyType,
              decoration: InputDecoration(labelText: l10n.partyType),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.allTime)),
                ...PartyType.values.map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label(l10n)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _partyType = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TransactionType?>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.transactionType),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.allTypes)),
                ...TransactionType.values.map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label(l10n)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod?>(
              initialValue: _method,
              decoration: InputDecoration(labelText: l10n.paymentMethod),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.allMethods)),
                ...PaymentMethod.values.map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label(l10n)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _method = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in [
                  (l10n.today, DateRange.today(DateTime.now())),
                  (l10n.thisWeek, DateRange.thisWeek(DateTime.now())),
                  (l10n.thisMonth, DateRange.thisMonth(DateTime.now())),
                  (l10n.thisYear, DateRange.thisYear(DateTime.now())),
                ])
                  ChoiceChip(
                    label: Text(option.$1),
                    selected:
                        _range.start == option.$2.start &&
                        _range.end == option.$2.end,
                    onSelected: (_) => setState(() => _range = option.$2),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _partyType = null;
                      _type = null;
                      _method = null;
                      _range = const DateRange();
                    }),
                    child: Text(l10n.clearFilters),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TransactionFilter(
                        range: _range,
                        partyType: _partyType,
                        type: _type,
                        paymentMethod: _method,
                      ),
                    ),
                    child: Text(l10n.apply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
