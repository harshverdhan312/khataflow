import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../domain/merchant.dart';
import '../domain/merchant_category.dart';
import 'merchant_providers.dart';

class AddMerchantScreen extends ConsumerStatefulWidget {
  const AddMerchantScreen({super.key});

  @override
  ConsumerState<AddMerchantScreen> createState() => _AddMerchantScreenState();
}

class _AddMerchantScreenState extends ConsumerState<AddMerchantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vpaController = TextEditingController();
  final _phoneController = TextEditingController();
  MerchantCategory _selectedCategory = MerchantCategory.grocery;

  @override
  void dispose() {
    _nameController.dispose();
    _vpaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final input = CreateMerchantInput(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      upiVpa: _vpaController.text.trim(),
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    final success = await ref.read(addMerchantControllerProvider.notifier).submit(input);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${input.name} added successfully'),
            backgroundColor: AppColors.settledGreen,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        final error = ref.read(addMerchantControllerProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to add merchant'),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addMerchantControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Store Tab'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Store Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add the merchant where you maintain a credit tab.',
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Store Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Store / Merchant Name *',
                  hintText: 'e.g. Sharma Kirana Store',
                  prefixIcon: Icon(Icons.storefront),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: Validators.validateMerchantName,
                enabled: !state.isLoading,
              ),
              const SizedBox(height: 16),

              // Category Selection
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: MerchantCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category.displayName),
                    selected: isSelected,
                    onSelected: state.isLoading
                        ? null
                        : (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            }
                          },
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // UPI VPA TextFormField
              TextFormField(
                controller: _vpaController,
                decoration: const InputDecoration(
                  labelText: 'Verified UPI ID (VPA) *',
                  hintText: 'e.g. sharmakirana@okhdfcbank or 9876543210@paytm',
                  prefixIcon: Icon(Icons.qr_code),
                  helperText: 'Used to settle dues directly via UPI',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.validateUpiVpa,
                enabled: !state.isLoading,
              ),
              const SizedBox(height: 16),

              // Optional Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Merchant Phone (Optional)',
                  hintText: 'e.g. 9876543210',
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Used to send statement receipts on WhatsApp',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhone,
                enabled: !state.isLoading,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
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
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Store Tab',
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
