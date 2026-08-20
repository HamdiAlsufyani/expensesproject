import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../shared/components/common_widgets.dart';
import '../../../shared/localization_extensions.dart';
import '../data/expense_repository.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  String _search = '';
  ExpenseFilter _filter = const ExpenseFilter();

  @override
  Widget build(BuildContext context) {
    ref.watch(dataChangeProvider);
    final filter = ExpenseFilter(
      range: _filter.range,
      categoryId: _filter.categoryId,
      paymentMethod: _filter.paymentMethod,
      query: _search,
    );
    final repository = ref.read(expenseRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.expenses),
        actions: [
          IconButton(
            onPressed: _openFilter,
            tooltip: context.l10n.filter,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            onPressed: _openCategories,
            tooltip: context.l10n.category,
            icon: const Icon(Icons.category_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addExpense),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SearchBar(
              leading: const Icon(Icons.search),
              hintText: context.l10n.search,
              onChanged: (value) => setState(() => _search = value),
              trailing: _search.isEmpty
                  ? null
                  : [
                      IconButton(
                        onPressed: () => setState(() => _search = ''),
                        icon: const Icon(Icons.close),
                      ),
                    ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Object>>(
                future: Future.wait<Object>([
                  repository.list(filter: filter, limit: 100),
                  repository.categories(),
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
                  final items = snapshot.data![0] as List<GeneralExpense>;
                  final categories = snapshot.data![1] as List<ExpenseCategory>;
                  final categoryNames = {
                    for (final item in categories) item.id!: item.name,
                  };
                  if (items.isEmpty) {
                    return EmptyState(
                      message: _search.isEmpty
                          ? context.l10n.noData
                          : context.l10n.noResults,
                      icon: Icons.receipt_long_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ExpenseCard(
                      item: items[index],
                      categoryName:
                          categoryNames[items[index].categoryId] ?? '',
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

  Future<void> _openForm([GeneralExpense? item]) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ExpenseFormSheet(existing: item),
      );

  Future<void> _openCategories() async => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CategoryManagementSheet(),
  );

  Future<void> _delete(GeneralExpense item) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: context.l10n.deleteTitle,
      message: context.l10n.deleteMessage,
      cancel: context.l10n.cancel,
      confirm: context.l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(expenseRepositoryProvider).delete(item.id!);
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
    final result = await showModalBottomSheet<ExpenseFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExpenseFilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.item,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });
  final GeneralExpense item;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFB42318).withValues(alpha: .12),
        child: const Icon(
          Icons.remove_circle_outline,
          color: Color(0xFFB42318),
        ),
      ),
      title: Text(
        item.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '$categoryName • ${context.date(item.expenseDate)} • ${item.paymentMethod.label(context.l10n)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.money(item.amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFB42318),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
              PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
            ],
          ),
        ],
      ),
    ),
  );
}

class ExpenseFormSheet extends ConsumerStatefulWidget {
  const ExpenseFormSheet({super.key, this.existing});
  final GeneralExpense? existing;

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  int? _categoryId;
  late DateTime _date;
  late PaymentMethod _method;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _amount = TextEditingController(text: item?.amount.toString() ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _categoryId = item?.categoryId;
    _date = item?.expenseDate ?? DateTime.now();
    _method = item?.paymentMethod ?? PaymentMethod.cash;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
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
                  widget.existing == null ? l10n.addExpense : l10n.editExpense,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<ExpenseCategory>>(
                  future: ref.read(expenseRepositoryProvider).categories(),
                  builder: (context, snapshot) => DropdownButtonFormField<int>(
                    initialValue: _categoryId,
                    decoration: InputDecoration(labelText: l10n.category),
                    items: (snapshot.data ?? [])
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: snapshot.connectionState == ConnectionState.done
                        ? (value) => setState(() => _categoryId = value)
                        : null,
                    validator: (value) =>
                        value == null ? l10n.requiredField : null,
                  ),
                ),
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
    setState(() => _saving = true);
    try {
      await ref
          .read(expenseRepositoryProvider)
          .save(
            GeneralExpense(
              id: widget.existing?.id,
              categoryId: _categoryId!,
              amount: double.parse(_amount.text),
              description: _description.text,
              expenseDate: _date,
              paymentMethod: _method,
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

class CategoryManagementSheet extends ConsumerWidget {
  const CategoryManagementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: 500,
          child: Column(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.category,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _addCategory(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addCategory),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: categories.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      EmptyState(message: context.l10n.operationFailed),
                  data: (items) => ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(items[index].name),
                      subtitle: items[index].description == null
                          ? null
                          : Text(items[index].description!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.addCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.categoryName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    try {
      await ref
          .read(expenseRepositoryProvider)
          .saveCategory(ExpenseCategory(name: value));
      if (context.mounted) {
        showFeedback(context, message: context.l10n.recordSaved);
      }
    } catch (error) {
      if (context.mounted) {
        showFeedback(
          context,
          message: safeErrorMessage(error, context.l10n),
          error: true,
        );
      }
    }
  }
}

class ExpenseFilterSheet extends ConsumerStatefulWidget {
  const ExpenseFilterSheet({super.key, required this.initial});
  final ExpenseFilter initial;

  @override
  ConsumerState<ExpenseFilterSheet> createState() => _ExpenseFilterSheetState();
}

class _ExpenseFilterSheetState extends ConsumerState<ExpenseFilterSheet> {
  int? _categoryId;
  PaymentMethod? _method;
  late DateRange _range;
  @override
  void initState() {
    super.initState();
    _categoryId = widget.initial.categoryId;
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
            FutureBuilder<List<ExpenseCategory>>(
              future: ref.read(expenseRepositoryProvider).categories(),
              builder: (context, snapshot) => DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                decoration: InputDecoration(labelText: l10n.category),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.allCategories),
                  ),
                  ...(snapshot.data ?? []).map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
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
                      _categoryId = null;
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
                      ExpenseFilter(
                        range: _range,
                        categoryId: _categoryId,
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
