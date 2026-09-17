import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import 'expense_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory? _selectedCategory;
  DateTime _expenseDate = DateTime.now();
  String? _categoryError;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _categoryError = _selectedCategory == null ? 'Please select a category' : null;
    });

    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      return;
    }

    try {
      final amountPaise = CurrencyFormatter.parseInputToPaise(_amountController.text);

      final trimmedNote = _noteController.text.trim();
      final effectiveNote = trimmedNote.isNotEmpty ? trimmedNote : null;

      final input = CreateExpenseInput(
        amountPaise: amountPaise,
        category: _selectedCategory!,
        note: effectiveNote,
        expenseDate: _expenseDate,
      );

      final success = await ref.read(addExpenseControllerProvider.notifier).submit(input);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense added'),
              backgroundColor: AppColors.settledGreen,
            ),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        } else {
          final error = ref.read(addExpenseControllerProvider).errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error ?? 'Failed to add expense'),
              backgroundColor: AppColors.outstandingRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addExpenseControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Record your personal spending locally.',
                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  hintText: '0.00',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(),
                ),
                validator: Validators.validateExpenseAmount,
                enabled: !state.isLoading,
              ),
              const SizedBox(height: 20),

              // Category Selection
              Row(
                children: [
                  const Text(
                    'Category *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (_categoryError != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _categoryError!,
                      style: const TextStyle(
                        color: AppColors.outstandingRed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category.displayName),
                    selected: isSelected,
                    onSelected: state.isLoading
                        ? null
                        : (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                              if (_selectedCategory != null) {
                                _categoryError = null;
                              }
                            });
                          },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundColor: AppColors.cardDark,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.borderDark,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Expense Date Picker
              InkWell(
                onTap: state.isLoading ? null : _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date *',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _expenseDate.toFormattedDate(),
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimaryDark),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Note (Optional)
              TextFormField(
                controller: _noteController,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'e.g. Lunch with team, Groceries',
                  prefixIcon: Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: Validators.validateExpenseNote,
                enabled: !state.isLoading,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Expense',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
