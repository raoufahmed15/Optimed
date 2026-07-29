// lib/models/patient.dart
// ✅ UPDATED: أضيف amount_paid, remaining, credit, visit_date, client_id

class Patient {
  final int?    id;
  final String  name;
  final int     turn;
  final String  status;
  final String  date;

  // ── بيانات شخصية ───────────────────────────────────────────────────────
  final String? age;
  final String? phone;
  final String? priority;
  final String? gender;
  final String? visitType;
  final String? department;
  final String? notes;
  final String? nurse;

  // ── المبالغ ✅ NEW ────────────────────────────────────────────────────
  final double? fee;
  final double? amountPaid;   // المبلغ المدفوع فعلاً
  final double? remaining;    // الباقي على المريض
  final double? credit;       // رصيد لصالح المريض (دفع زيادة)

  // ── التواريخ ───────────────────────────────────────────────────────────
  final String? visitTime;
  final String? visitDate;    // ✅ NEW: تاريخ الزيارة الفعلية (قد يكون مستقبلي)
  final String? createdAt;

  // ── المزامنة ✅ NEW ───────────────────────────────────────────────────
  final String? clientId;     // idempotency key من الممرضة

  Patient({
    this.id,
    required this.name,
    required this.turn,
    required this.status,
    String? date,
    this.age,
    this.phone,
    this.priority,
    this.gender,
    this.visitType,
    this.department,
    this.notes,
    this.nurse,
    this.fee,
    this.amountPaid,
    this.remaining,
    this.credit,
    this.visitTime,
    this.visitDate,
    this.createdAt,
    this.clientId,
  }) : this.date = date ??
            "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

  // ══════════════════════════════════════════════════════════════════════════
  //  SAFE TYPE HELPERS
  //  mysql_client assoc() → Map<String, String?>
  //  jsonDecode         → Map<String, dynamic>
  // ══════════════════════════════════════════════════════════════════════════

  static int _safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is BigInt) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static int? _safeIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is BigInt) return v.toInt();
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : int.tryParse(s);
    }
    return null;
  }

  static double? _safeDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is BigInt) return v.toDouble();
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : double.tryParse(s);
    }
    return null;
  }

  static String? _safeString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.trim().isEmpty ? null : v.trim();
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  fromMap — يقبل Map<String, dynamic>
  // ══════════════════════════════════════════════════════════════════════════
  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id:          _safeIntNullable(map['id']),
      name:        _safeString(map['name'])        ?? '',
      turn:        _safeInt(map['turn']),
      status:      _safeString(map['status'])      ?? 'waiting',
      date:        _safeString(map['date'])         ?? '',
      age:         _safeString(map['age']),
      phone:       _safeString(map['phone']),
      priority:    _safeString(map['priority']),
      gender:      _safeString(map['gender']),
      visitType:   _safeString(map['visit_type']),
      department:  _safeString(map['department']),
      notes:       _safeString(map['notes']),
      nurse:       _safeString(map['nurse']),
      fee:         _safeDouble(map['fee']),
      amountPaid:  _safeDouble(map['amount_paid']),   // ✅ NEW
      remaining:   _safeDouble(map['remaining']),      // ✅ NEW
      credit:      _safeDouble(map['credit']),         // ✅ NEW
      visitTime:   _safeString(map['visit_time']),
      visitDate:   _safeString(map['visit_date']),     // ✅ NEW
      createdAt:   _safeString(map['created_at']),
      clientId:    _safeString(map['client_id']),      // ✅ NEW
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  fromAssoc — خاص بـ row.assoc() من mysql_client (Map<String, String?>)
  // ══════════════════════════════════════════════════════════════════════════
  factory Patient.fromAssoc(Map<String, String?> map) {
    return Patient(
      id:          _safeIntNullable(map['id']),
      name:        _safeString(map['name'])        ?? '',
      turn:        _safeInt(map['turn']),
      status:      _safeString(map['status'])      ?? 'waiting',
      date:        _safeString(map['date'])         ?? '',
      age:         _safeString(map['age']),
      phone:       _safeString(map['phone']),
      priority:    _safeString(map['priority']),
      gender:      _safeString(map['gender']),
      visitType:   _safeString(map['visit_type']),
      department:  _safeString(map['department']),
      notes:       _safeString(map['notes']),
      nurse:       _safeString(map['nurse']),
      fee:         _safeDouble(map['fee']),
      amountPaid:  _safeDouble(map['amount_paid']),   // ✅ NEW
      remaining:   _safeDouble(map['remaining']),      // ✅ NEW
      credit:      _safeDouble(map['credit']),         // ✅ NEW
      visitTime:   _safeString(map['visit_time']),
      visitDate:   _safeString(map['visit_date']),     // ✅ NEW
      createdAt:   _safeString(map['created_at']),
      clientId:    _safeString(map['client_id']),      // ✅ NEW
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  toMap
  // ══════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> toMap() {
    return {
      'id':          id,
      'name':        name,
      'turn':        turn,
      'status':      status,
      'date':        date,
      'age':         age,
      'phone':       phone,
      'priority':    priority,
      'gender':      gender,
      'visit_type':  visitType,
      'department':  department,
      'notes':       notes,
      'nurse':       nurse,
      'fee':         fee,
      'amount_paid': amountPaid,    // ✅ NEW
      'remaining':   remaining,     // ✅ NEW
      'credit':      credit,        // ✅ NEW
      'visit_time':  visitTime,
      'visit_date':  visitDate,     // ✅ NEW
      'created_at':  createdAt,
      'client_id':   clientId,      // ✅ NEW
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS: حساب الحالة المالية
  // ══════════════════════════════════════════════════════════════════════════

  /// هل المريض دفع كامل السعر؟
  bool get isPaidFull {
    if (fee == null || fee == 0) return true;
    return (remaining ?? 0) == 0 && (credit ?? 0) == 0;
  }

  /// هل عليه باقي؟
  bool get hasRemaining => (remaining ?? 0) > 0;

  /// هل عنده رصيد لصالحه؟
  bool get hasCredit => (credit ?? 0) > 0;

  /// نسبة ما دُفع
  double get paymentProgress {
    if (fee == null || fee == 0) return 1.0;
    final paid = amountPaid ?? 0;
    return (paid / fee!).clamp(0.0, 1.0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  copyWith
  // ══════════════════════════════════════════════════════════════════════════
  Patient copyWith({
    int?    id,
    String? name,
    int?    turn,
    String? status,
    String? date,
    String? age,
    String? phone,
    String? priority,
    String? gender,
    String? visitType,
    String? department,
    String? notes,
    String? nurse,
    double? fee,
    double? amountPaid,
    double? remaining,
    double? credit,
    String? visitTime,
    String? visitDate,
    String? createdAt,
    String? clientId,
  }) {
    return Patient(
      id:          id          ?? this.id,
      name:        name        ?? this.name,
      turn:        turn        ?? this.turn,
      status:      status      ?? this.status,
      date:        date        ?? this.date,
      age:         age         ?? this.age,
      phone:       phone       ?? this.phone,
      priority:    priority    ?? this.priority,
      gender:      gender      ?? this.gender,
      visitType:   visitType   ?? this.visitType,
      department:  department  ?? this.department,
      notes:       notes       ?? this.notes,
      nurse:       nurse       ?? this.nurse,
      fee:         fee         ?? this.fee,
      amountPaid:  amountPaid  ?? this.amountPaid,
      remaining:   remaining   ?? this.remaining,
      credit:      credit      ?? this.credit,
      visitTime:   visitTime   ?? this.visitTime,
      visitDate:   visitDate   ?? this.visitDate,
      createdAt:   createdAt   ?? this.createdAt,
      clientId:    clientId    ?? this.clientId,
    );
  }

  @override
  String toString() =>
      'Patient(id: $id, name: $name, turn: $turn, status: $status, '
      'fee: $fee, paid: $amountPaid, remaining: $remaining, visitDate: $visitDate)';
}