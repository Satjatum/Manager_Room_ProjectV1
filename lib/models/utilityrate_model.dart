// ============================================
// UTILITY RATE MODEL
// ============================================

class UtilityRateModel {
  final String rateId;
  final String branchId;
  final String rateName;
  final double ratePrice;
  final String rateUnit;
  final bool isMetered;
  final bool isFixed;
  final double fixedAmount;
  final double additionalCharge;
  final String? rateDesc;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  UtilityRateModel({
    required this.rateId,
    required this.branchId,
    required this.rateName,
    required this.ratePrice,
    required this.rateUnit,
    required this.isMetered,
    required this.isFixed,
    required this.fixedAmount,
    required this.additionalCharge,
    this.rateDesc,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // สร้างจาก JSON (จาก Supabase)
  factory UtilityRateModel.fromJson(Map<String, dynamic> json) {
    return UtilityRateModel(
      rateId: json['rate_id'] as String,
      branchId: json['branch_id'] as String,
      rateName: json['rate_name'] as String,
      ratePrice: (json['rate_price'] as num).toDouble(),
      rateUnit: json['rate_unit'] as String,
      isMetered: json['is_metered'] as bool,
      isFixed: json['is_fixed'] as bool,
      fixedAmount: (json['fixed_amount'] as num? ?? 0).toDouble(),
      additionalCharge: (json['additional_charge'] as num? ?? 0).toDouble(),
      rateDesc: json['rate_desc'] as String?,
      isActive: json['is_active'] as bool,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // แปลงเป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'rate_id': rateId,
      'branch_id': branchId,
      'rate_name': rateName,
      'rate_price': ratePrice,
      'rate_unit': rateUnit,
      'is_metered': isMetered,
      'is_fixed': isFixed,
      'fixed_amount': fixedAmount,
      'additional_charge': additionalCharge,
      'rate_desc': rateDesc,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // คัดลอกพร้อมแก้ไขบางฟิลด์
  UtilityRateModel copyWith({
    String? rateId,
    String? branchId,
    String? rateName,
    double? ratePrice,
    String? rateUnit,
    bool? isMetered,
    bool? isFixed,
    double? fixedAmount,
    double? additionalCharge,
    String? rateDesc,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UtilityRateModel(
      rateId: rateId ?? this.rateId,
      branchId: branchId ?? this.branchId,
      rateName: rateName ?? this.rateName,
      ratePrice: ratePrice ?? this.ratePrice,
      rateUnit: rateUnit ?? this.rateUnit,
      isMetered: isMetered ?? this.isMetered,
      isFixed: isFixed ?? this.isFixed,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      additionalCharge: additionalCharge ?? this.additionalCharge,
      rateDesc: rateDesc ?? this.rateDesc,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // คำนวณค่าใช้จ่ายจากการใช้งาน
  double calculateCost(double usageAmount) {
    double total = 0;

    if (isMetered) {
      total += ratePrice * usageAmount;
    }

    if (isFixed) {
      total += fixedAmount;
    }

    total += additionalCharge;

    return total;
  }

  // แสดงรายละเอียดแบบย่อ
  String get displaySummary {
    if (isMetered && isFixed) {
      return '$rateName: ${ratePrice.toStringAsFixed(2)} บาท/$rateUnit + ${fixedAmount.toStringAsFixed(0)} บาท';
    } else if (isMetered) {
      return '$rateName: ${ratePrice.toStringAsFixed(2)} บาท/$rateUnit';
    } else if (isFixed) {
      return '$rateName: ${fixedAmount.toStringAsFixed(0)} บาท/$rateUnit';
    }
    return rateName;
  }

  // ประเภทการคิดค่าบริการ
  String get rateTypeDisplay {
    if (isMetered && isFixed) return 'มิเตอร์ + คงที่';
    if (isMetered) return 'มิเตอร์';
    if (isFixed) return 'คงที่';
    return 'ไม่ระบุ';
  }
}

// ============================================
// PAYMENT SETTINGS MODEL
// ============================================

enum LateFeeType {
  fixed,
  percentage,
  daily;

  String get displayName {
    switch (this) {
      case LateFeeType.fixed:
        return 'คงที่';
      case LateFeeType.percentage:
        return 'เปอร์เซ็นต์';
      case LateFeeType.daily:
        return 'รายวัน';
    }
  }

  static LateFeeType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'fixed':
        return LateFeeType.fixed;
      case 'percentage':
        return LateFeeType.percentage;
      case 'daily':
        return LateFeeType.daily;
      default:
        return LateFeeType.fixed;
    }
  }
}

class PaymentSettingsModel {
  final String settingId;
  final String branchId;

  // การตั้งค่าค่าปรับ
  final bool enableLateFee;
  final LateFeeType? lateFeeType;
  final double lateFeeAmount;
  final int lateFeeStartDay;
  final double? lateFeeMaxAmount;

  // การตั้งค่าส่วนลด
  final bool enableDiscount;
  final double earlyPaymentDiscount;
  final int earlyPaymentDays;

  final String? settingDesc;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentSettingsModel({
    required this.settingId,
    required this.branchId,
    required this.enableLateFee,
    this.lateFeeType,
    required this.lateFeeAmount,
    required this.lateFeeStartDay,
    this.lateFeeMaxAmount,
    required this.enableDiscount,
    required this.earlyPaymentDiscount,
    required this.earlyPaymentDays,
    this.settingDesc,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // สร้างจาก JSON
  factory PaymentSettingsModel.fromJson(Map<String, dynamic> json) {
    return PaymentSettingsModel(
      settingId: json['setting_id'] as String,
      branchId: json['branch_id'] as String,
      enableLateFee: json['enable_late_fee'] as bool,
      lateFeeType: json['late_fee_type'] != null
          ? LateFeeType.fromString(json['late_fee_type'] as String)
          : null,
      lateFeeAmount: (json['late_fee_amount'] as num? ?? 0).toDouble(),
      lateFeeStartDay: json['late_fee_start_day'] as int? ?? 1,
      lateFeeMaxAmount: json['late_fee_max_amount'] != null
          ? (json['late_fee_max_amount'] as num).toDouble()
          : null,
      enableDiscount: json['enable_discount'] as bool,
      earlyPaymentDiscount:
          (json['early_payment_discount'] as num? ?? 0).toDouble(),
      earlyPaymentDays: json['early_payment_days'] as int? ?? 0,
      settingDesc: json['setting_desc'] as String?,
      isActive: json['is_active'] as bool,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // แปลงเป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'setting_id': settingId,
      'branch_id': branchId,
      'enable_late_fee': enableLateFee,
      'late_fee_type': lateFeeType?.name,
      'late_fee_amount': lateFeeAmount,
      'late_fee_start_day': lateFeeStartDay,
      'late_fee_max_amount': lateFeeMaxAmount,
      'enable_discount': enableDiscount,
      'early_payment_discount': earlyPaymentDiscount,
      'early_payment_days': earlyPaymentDays,
      'setting_desc': settingDesc,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // คัดลอกพร้อมแก้ไขบางฟิลด์
  PaymentSettingsModel copyWith({
    String? settingId,
    String? branchId,
    bool? enableLateFee,
    LateFeeType? lateFeeType,
    double? lateFeeAmount,
    int? lateFeeStartDay,
    double? lateFeeMaxAmount,
    bool? enableDiscount,
    double? earlyPaymentDiscount,
    int? earlyPaymentDays,
    String? settingDesc,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentSettingsModel(
      settingId: settingId ?? this.settingId,
      branchId: branchId ?? this.branchId,
      enableLateFee: enableLateFee ?? this.enableLateFee,
      lateFeeType: lateFeeType ?? this.lateFeeType,
      lateFeeAmount: lateFeeAmount ?? this.lateFeeAmount,
      lateFeeStartDay: lateFeeStartDay ?? this.lateFeeStartDay,
      lateFeeMaxAmount: lateFeeMaxAmount ?? this.lateFeeMaxAmount,
      enableDiscount: enableDiscount ?? this.enableDiscount,
      earlyPaymentDiscount: earlyPaymentDiscount ?? this.earlyPaymentDiscount,
      earlyPaymentDays: earlyPaymentDays ?? this.earlyPaymentDays,
      settingDesc: settingDesc ?? this.settingDesc,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // คำนวณค่าปรับ
  double calculateLateFee({
    required DateTime dueDate,
    required double subtotal,
    DateTime? paymentDate,
  }) {
    if (!enableLateFee) return 0;

    final date = paymentDate ?? DateTime.now();
    final daysLate = date.difference(dueDate).inDays;

    if (daysLate < lateFeeStartDay) return 0;

    double fee = 0;

    switch (lateFeeType) {
      case LateFeeType.fixed:
        fee = lateFeeAmount;
        break;
      case LateFeeType.percentage:
        fee = subtotal * (lateFeeAmount / 100);
        break;
      case LateFeeType.daily:
        final chargeDays = daysLate - lateFeeStartDay + 1;
        fee = lateFeeAmount * chargeDays;
        break;
      case null:
        fee = 0;
    }

    // จำกัดค่าปรับสูงสุด
    if (lateFeeMaxAmount != null && fee > lateFeeMaxAmount!) {
      fee = lateFeeMaxAmount!;
    }

    return fee;
  }

  // คำนวณส่วนลด
  double calculateDiscount({
    required DateTime dueDate,
    required double subtotal,
    DateTime? paymentDate,
  }) {
    if (!enableDiscount) return 0;

    final date = paymentDate ?? DateTime.now();
    final daysEarly = dueDate.difference(date).inDays;

    if (daysEarly < earlyPaymentDays) return 0;

    return subtotal * (earlyPaymentDiscount / 100);
  }

  // ตรวจสอบว่าควรคิดค่าปรับหรือไม่
  bool shouldApplyLateFee(DateTime dueDate, [DateTime? currentDate]) {
    if (!enableLateFee) return false;

    final date = currentDate ?? DateTime.now();
    final daysLate = date.difference(dueDate).inDays;

    return daysLate >= lateFeeStartDay;
  }

  // ตรวจสอบว่าควรให้ส่วนลดหรือไม่
  bool shouldApplyDiscount(DateTime dueDate, [DateTime? paymentDate]) {
    if (!enableDiscount) return false;

    final date = paymentDate ?? DateTime.now();
    final daysEarly = dueDate.difference(date).inDays;

    return daysEarly >= earlyPaymentDays;
  }

  // สรุปการตั้งค่าค่าปรับ
  String get lateFeeDisplay {
    if (!enableLateFee) return 'ไม่เปิดใช้งาน';

    String text = '';
    switch (lateFeeType) {
      case LateFeeType.fixed:
        text = '${lateFeeAmount.toStringAsFixed(0)} บาท';
        break;
      case LateFeeType.percentage:
        text = '${lateFeeAmount.toStringAsFixed(1)}%';
        break;
      case LateFeeType.daily:
        text = '${lateFeeAmount.toStringAsFixed(0)} บาท/วัน';
        break;
      case null:
        text = 'ไม่ระบุ';
    }

    text += ' (หลังครบกำหนด $lateFeeStartDay วัน)';

    if (lateFeeMaxAmount != null) {
      text += ' สูงสุด ${lateFeeMaxAmount!.toStringAsFixed(0)} บาท';
    }

    return text;
  }

  // สรุปการตั้งค่าส่วนลด
  String get discountDisplay {
    if (!enableDiscount) return 'ไม่เปิดใช้งาน';

    return '${earlyPaymentDiscount.toStringAsFixed(1)}% '
        '(ชำระก่อนกำหนด $earlyPaymentDays วัน)';
  }

  // สรุปการตั้งค่าแบบสั้น
  String get summaryDisplay {
    List<String> parts = [];

    if (enableLateFee) {
      parts.add('ค่าปรับ: ${lateFeeType?.displayName ?? "N/A"}');
    }

    if (enableDiscount) {
      parts.add('ส่วนลด: ${earlyPaymentDiscount.toStringAsFixed(1)}%');
    }

    if (parts.isEmpty) {
      return 'ไม่มีการตั้งค่า';
    }

    return parts.join(' | ');
  }
}

// ============================================
// HELPER FUNCTIONS
// ============================================

class PaymentCalculator {
  /// คำนวณยอดรวมทั้งหมดรวมค่าปรับและส่วนลด
  static double calculateFinalAmount({
    required double subtotal,
    required PaymentSettingsModel settings,
    required DateTime dueDate,
    DateTime? paymentDate,
  }) {
    final lateFee = settings.calculateLateFee(
      dueDate: dueDate,
      subtotal: subtotal,
      paymentDate: paymentDate,
    );

    final discount = settings.calculateDiscount(
      dueDate: dueDate,
      subtotal: subtotal,
      paymentDate: paymentDate,
    );

    return subtotal - discount + lateFee;
  }

  /// สร้างรายละเอียดการคำนวณ
  static Map<String, dynamic> calculateBreakdown({
    required double subtotal,
    required PaymentSettingsModel settings,
    required DateTime dueDate,
    DateTime? paymentDate,
  }) {
    final lateFee = settings.calculateLateFee(
      dueDate: dueDate,
      subtotal: subtotal,
      paymentDate: paymentDate,
    );

    final discount = settings.calculateDiscount(
      dueDate: dueDate,
      subtotal: subtotal,
      paymentDate: paymentDate,
    );

    final total = subtotal - discount + lateFee;

    return {
      'subtotal': subtotal,
      'discount': discount,
      'late_fee': lateFee,
      'total': total,
      'has_discount': discount > 0,
      'has_late_fee': lateFee > 0,
    };
  }
}
