import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../domain/merchant.dart';
import '../domain/merchant_category.dart';
import 'merchant_providers.dart';

class EditMerchantScreen extends ConsumerStatefulWidget {
  final String merchantId;

  const EditMerchantScreen({
    super.key,
    required this.merchantId,
  });

  @override
  ConsumerState<EditMerchantScreen> createState() => _EditMerchantScreenState();
}

class _EditMerchantScreenState extends ConsumerState<EditMerchantScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _vpaController;
  late TextEditingController _phoneController;
  MerchantCategory _selectedCategory = MerchantCategory.grocery;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _vpaController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vpaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initFromMerchant(Merchant merchant) {
    if (!_initialized) {
      _nameController.text = merchant.name;
      _vpaController.text = merchant.upiVpa;
      _phoneController.text = merchant.phone ?? '';
      _selectedCategory = merchant.category;
      _initialized = true;
    }
  }

  Future<void> _submit(Merchant currentMerchant) async {
    if (!_formKey.currentState!.validate()) return;

    final updatedMerchant = currentMerchant.copyWith(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      upiVpa: _vpaController.text.trim(),
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      updatedAt: DateTime.now(),
    );

    final success = await ref
        .read(addMerchantControllerProvider.notifier)
        .updateMerchant(updatedMerchant);

    if (mounted) {
      if (success) {
        ref.invalidate(merchantDetailProvider(widget.merchantId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedMerchant.name} updated successfully'),
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
            content: Text(error ?? 'Failed to update merchant'),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchantAsync = ref.watch(merchantDetailProvider(widget.merchantId));
    final state = ref.watch(addMerchantControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Store Details'),
      ),
      body: merchantAsync.when(
        data: (merchant) {
          if (merchant == null) {
            return const Center(child: Text('Store not found'));
          }

          _initFromMerchant(merchant);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Store Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Update merchant name, UPI VPA, category, or contact number.',
                    style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Store Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Store / Merchant Name *',
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

                  // UPI VPA
                  TextFormField(
                    controller: _vpaController,
                    decoration: const InputDecoration(
                      labelText: 'Merchant UPI ID (VPA) *',
                      prefixIcon: Icon(Icons.qr_code),
                      helperText: 'Stored as merchant information only',
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
                      prefixIcon: Icon(Icons.phone),
                      helperText: 'Used for sending settlement receipts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: Validators.validatePhone,
                    enabled: !state.isLoading,
                  ),
                  const SizedBox(height: 32),

                  // Save Changes Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: state.isLoading ? null : () => _submit(merchant),
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
                              'Save Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
