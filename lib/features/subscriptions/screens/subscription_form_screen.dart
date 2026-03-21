// lib/features/subscriptions/screens/subscription_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/features/categories/providers/categories_provider.dart';
import 'package:kiper/features/subscriptions/catalog/catalog_data.dart';
import 'package:kiper/features/subscriptions/catalog/catalog_picker.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';
import 'package:kiper/features/subscriptions/providers/subscriptions_provider.dart';

class SubscriptionFormScreen extends ConsumerStatefulWidget {
  const SubscriptionFormScreen({super.key});

  @override
  ConsumerState<SubscriptionFormScreen> createState() => _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends ConsumerState<SubscriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  Currency _currency = Currency.rub;
  BillingPeriod _billingPeriod = BillingPeriod.monthly;
  String? _categoryId;
  String? _icon;
  DateTime _startDate = DateTime.now();
  DateTime _nextBillingDate = DateTime.now().add(const Duration(days: 30));
  int _reminderDays = 1;
  bool _isSaving = false;

  final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _fillFromCatalog(CatalogEntry entry) {
    setState(() {
      _nameController.text = entry.name;
      _currency = entry.defaultCurrency;
      _billingPeriod = entry.defaultPeriod;
      _categoryId = entry.categoryId;
      _icon = entry.icon;
    });
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(subscriptionsNotifierProvider.notifier).add(
            name: _nameController.text.trim(),
            amount: double.parse(_amountController.text.trim()),
            currency: _currency.code,
            billingPeriod: _billingPeriod.name,
            nextBillingDate: _nextBillingDate,
            startDate: _startDate,
            icon: _icon,
            categoryId: _categoryId,
            reminderDaysBefore: _reminderDays,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая подписка'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Catalog picker button
            OutlinedButton.icon(
              icon: const Icon(Icons.grid_view),
              label: const Text('Выбрать из каталога'),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CatalogPicker(onSelect: _fillFromCatalog),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Сумма *',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Введите сумму';
                if (double.tryParse(v.trim()) == null) return 'Введите корректное число';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Currency
            DropdownButtonFormField<Currency>(
              initialValue: _currency,
              decoration: const InputDecoration(
                labelText: 'Валюта',
                border: OutlineInputBorder(),
              ),
              items: Currency.values.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.symbol} ${c.code}'),
                  )).toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 16),

            // Billing period
            DropdownButtonFormField<BillingPeriod>(
              initialValue: _billingPeriod,
              decoration: const InputDecoration(
                labelText: 'Период оплаты',
                border: OutlineInputBorder(),
              ),
              items: BillingPeriod.values.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(_periodLabel(p)),
                  )).toList(),
              onChanged: (v) => setState(() => _billingPeriod = v!),
            ),
            const SizedBox(height: 16),

            // Category
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Без категории')),
                  ...categories.map((cat) => DropdownMenuItem<String?>(
                        value: cat.id,
                        child: Text(cat.name),
                      )),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Start date
            _DatePickerField(
              label: 'Дата начала',
              date: _startDate,
              dateFormat: _dateFormat,
              onTap: () => _pickDate(
                initial: _startDate,
                onPicked: (d) => setState(() => _startDate = d),
              ),
            ),
            const SizedBox(height: 16),

            // Next billing date
            _DatePickerField(
              label: 'Следующая дата списания',
              date: _nextBillingDate,
              dateFormat: _dateFormat,
              onTap: () => _pickDate(
                initial: _nextBillingDate,
                onPicked: (d) => setState(() => _nextBillingDate = d),
              ),
            ),
            const SizedBox(height: 16),

            // Reminder
            DropdownButtonFormField<int>(
              initialValue: _reminderDays,
              decoration: const InputDecoration(
                labelText: 'Напоминание',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Выключено')),
                DropdownMenuItem(value: 1, child: Text('За 1 день')),
                DropdownMenuItem(value: 3, child: Text('За 3 дня')),
                DropdownMenuItem(value: 7, child: Text('За 7 дней')),
              ],
              onChanged: (v) => setState(() => _reminderDays = v!),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Заметка (необязательно)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(BillingPeriod period) {
    switch (period) {
      case BillingPeriod.weekly:
        return 'Еженедельно';
      case BillingPeriod.monthly:
        return 'Ежемесячно';
      case BillingPeriod.quarterly:
        return 'Ежеквартально';
      case BillingPeriod.semiannual:
        return 'Раз в полгода';
      case BillingPeriod.annual:
        return 'Ежегодно';
      case BillingPeriod.custom:
        return 'Другой период';
    }
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.dateFormat,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Text(dateFormat.format(date)),
      ),
    );
  }
}
