import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../shared/components/common_widgets.dart';
import '../../../shared/localization_extensions.dart';
import '../data/party_repository.dart';

class PartyPage extends ConsumerStatefulWidget {
  const PartyPage({super.key, required this.type});
  final PartyType type;

  @override
  ConsumerState<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends ConsumerState<PartyPage> {
  String _search = '';

  PartyRepository get _repository => widget.type == PartyType.customer
      ? ref.read(customerRepositoryProvider)
      : ref.read(supplierRepositoryProvider);
  String get _title => widget.type == PartyType.customer
      ? context.l10n.customers
      : context.l10n.suppliers;
  String get _addLabel => widget.type == PartyType.customer
      ? context.l10n.addCustomer
      : context.l10n.addSupplier;

  @override
  Widget build(BuildContext context) {
    ref.watch(dataChangeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(_addLabel),
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
              child: FutureBuilder<List<PartyBalance>>(
                future: _repository.balances(query: _search),
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
                      message: _search.isEmpty
                          ? context.l10n.noData
                          : context.l10n.noResults,
                      icon: Icons.groups_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _PartyCard(
                      item: items[index],
                      type: widget.type,
                      onTap: () => _openDetails(items[index].party),
                      onEdit: () => _openForm(items[index].party),
                      onDelete: () => _delete(items[index].party),
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

  Future<void> _openForm([Party? party]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PartyFormSheet(type: widget.type, existing: party),
    );
  }

  Future<void> _delete(Party party) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: context.l10n.deleteTitle,
      message: context.l10n.deleteMessage,
      cancel: context.l10n.cancel,
      confirm: context.l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repository.delete(party.id!);
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

  Future<void> _openDetails(Party party) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartyDetailsPage(type: widget.type, party: party),
      ),
    );
  }
}

class _PartyCard extends ConsumerWidget {
  const _PartyCard({
    required this.item,
    required this.type,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final PartyBalance item;
  final PartyType type;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounting = ref.watch(accountingServiceProvider);
    final status = accounting.status(item.balance);
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Icon(
            type == PartyType.customer
                ? Icons.person_outline
                : Icons.local_shipping_outlined,
          ),
        ),
        title: Text(
          item.party.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(item.party.phone ?? item.party.email ?? ''),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 165),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.money(item.balance.abs()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: status.color(Theme.of(context).colorScheme),
                ),
              ),
              Text(
                status.label(context.l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: status.color(Theme.of(context).colorScheme),
                ),
              ),
            ],
          ),
        ),
        onLongPress: onEdit,
      ),
    );
  }
}

class PartyFormSheet extends ConsumerStatefulWidget {
  const PartyFormSheet({super.key, required this.type, this.existing});
  final PartyType type;
  final Party? existing;

  @override
  ConsumerState<PartyFormSheet> createState() => _PartyFormSheetState();
}

class _PartyFormSheetState extends ConsumerState<PartyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _name = TextEditingController(text: item?.name);
    _phone = TextEditingController(text: item?.phone);
    _email = TextEditingController(text: item?.email);
    _address = TextEditingController(text: item?.address);
    _notes = TextEditingController(text: item?.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.existing == null
        ? (widget.type == PartyType.customer
              ? l10n.addCustomer
              : l10n.addSupplier)
        : (widget.type == PartyType.customer
              ? l10n.editCustomer
              : l10n.editSupplier);
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
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.name),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.phone),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.email),
                  validator: (value) =>
                      value != null &&
                          value.trim().isNotEmpty &&
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())
                      ? l10n.invalidEmail
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.address),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repository = widget.type == PartyType.customer
          ? ref.read(customerRepositoryProvider)
          : ref.read(supplierRepositoryProvider);
      await repository.save(
        Party(
          id: widget.existing?.id,
          name: _name.text,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
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

class PartyDetailsPage extends ConsumerWidget {
  const PartyDetailsPage({super.key, required this.type, required this.party});
  final PartyType type;
  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(transactionRepositoryProvider);
    final partyRepository = type == PartyType.customer
        ? ref.read(customerRepositoryProvider)
        : ref.read(supplierRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(party.name)),
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([
          partyRepository.balanceFor(party),
          repository.statement(type, party.id!),
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
          final balance = snapshot.data![0] as PartyBalance;
          final lines = snapshot.data![1] as List<StatementLine>;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _BalanceSummary(balance: balance),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.details,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    if (party.phone != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined),
                        title: Text(party.phone!),
                      ),
                    if (party.email != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined),
                        title: Text(party.email!),
                      ),
                    if (party.address != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(party.address!),
                      ),
                    if (party.notes != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notes_outlined),
                        title: Text(party.notes!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.statement,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SectionCard(
                padding: EdgeInsets.zero,
                child: lines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text(context.l10n.noData)),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(context.l10n.date)),
                            DataColumn(label: Text(context.l10n.description)),
                            DataColumn(
                              label: Text(context.l10n.debit),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(context.l10n.credit),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(context.l10n.balance),
                              numeric: true,
                            ),
                          ],
                          rows: [
                            for (final line in lines)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      context.date(
                                        line.transaction.transactionDate,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        line.transaction.description,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      line.debit == 0
                                          ? '—'
                                          : context.money(line.debit),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      line.credit == 0
                                          ? '—'
                                          : context.money(line.credit),
                                    ),
                                  ),
                                  DataCell(Text(context.money(line.balance))),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceSummary extends ConsumerWidget {
  const _BalanceSummary({required this.balance});
  final PartyBalance balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(accountingServiceProvider).status(balance.balance);
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: context.l10n.totalDebit,
            value: context.money(balance.debit),
            icon: Icons.south_west_rounded,
            color: const Color(0xFFB45309),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            label: context.l10n.totalCredit,
            value: context.money(balance.credit),
            icon: Icons.north_east_rounded,
            color: const Color(0xFF0F766E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            label: status.label(context.l10n),
            value: context.money(balance.balance.abs()),
            icon: Icons.account_balance_wallet_outlined,
            color: status.color(Theme.of(context).colorScheme),
          ),
        ),
      ],
    );
  }
}
