import 'merchant_category.dart';

class Merchant {
  final String id;
  final String name;
  final MerchantCategory category;
  final String? phone;
  final String upiVpa;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const Merchant({
    required this.id,
    required this.name,
    required this.category,
    this.phone,
    required this.upiVpa,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Merchant copyWith({
    String? id,
    String? name,
    MerchantCategory? category,
    String? phone,
    String? upiVpa,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Merchant(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      upiVpa: upiVpa ?? this.upiVpa,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class CreateMerchantInput {
  final String name;
  final MerchantCategory category;
  final String? phone;
  final String upiVpa;

  const CreateMerchantInput({
    required this.name,
    required this.category,
    this.phone,
    required this.upiVpa,
  });
}
