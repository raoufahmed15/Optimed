// lib/core/custom_fields_db.dart
// ══════════════════════════════════════════════════════════════════════════
//  Dynamic Custom Fields — Database Layer
//  أضِف هذا الملف وـimport'ه في أي شاشة محتاجه
// ══════════════════════════════════════════════════════════════════════════

import 'database.dart'; // DatabaseService + toInt + toStr

// ─────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────
class CustomField {
  final int? id;
  final int patientId;
  final int doctorId;
  String fieldName;
  String fieldValue;
  bool isPinned;
  bool showInPrescription;
  final DateTime? createdAt;

  CustomField({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.fieldName,
    required this.fieldValue,
    this.isPinned = false,
    this.showInPrescription = false,
    this.createdAt,
  });

  factory CustomField.fromRow(Map<String, String?> row) => CustomField(
        id: DatabaseService.toInt(row['id']),
        patientId: DatabaseService.toInt(row['patient_id']),
        doctorId: DatabaseService.toInt(row['doctor_id']),
        fieldName: row['field_name'] ?? '',
        fieldValue: row['field_value'] ?? '',
        isPinned: DatabaseService.toInt(row['is_pinned']) == 1,
        showInPrescription:
            DatabaseService.toInt(row['show_in_prescription']) == 1,
        createdAt: DateTime.tryParse(row['created_at'] ?? ''),
      );

  Map<String, dynamic> toMap() => {
        'patient_id': patientId,
        'doctor_id': doctorId,
        'field_name': fieldName.trim(),
        'field_value': fieldValue.trim(),
        'is_pinned': isPinned ? 1 : 0,
        'show_in_prescription': showInPrescription ? 1 : 0,
      };
}

// ─────────────────────────────────────────────────────────────────────────
//  Pinned Template Model
// ─────────────────────────────────────────────────────────────────────────
class PinnedTemplate {
  final int? id;
  final int doctorId;
  String fieldName;
  bool showInPrescription;
  int sortOrder;

  PinnedTemplate({
    this.id,
    required this.doctorId,
    required this.fieldName,
    this.showInPrescription = false,
    this.sortOrder = 0,
  });

  factory PinnedTemplate.fromRow(Map<String, String?> row) => PinnedTemplate(
        id: DatabaseService.toInt(row['id']),
        doctorId: DatabaseService.toInt(row['doctor_id']),
        fieldName: row['field_name'] ?? '',
        showInPrescription:
            DatabaseService.toInt(row['show_in_prescription']) == 1,
        sortOrder: DatabaseService.toInt(row['sort_order']),
      );
}

// ─────────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────────
class CustomFieldsDb {
  // ── CRUD على patient_custom_data ─────────────────────────────────────

  /// جلب كل الحقول لمريض معين
  static Future<List<CustomField>> getForPatient(int patientId) async {
    final res = await DatabaseService.execute(
      'SELECT * FROM patient_custom_data WHERE patient_id = :pid ORDER BY id ASC',
      {'pid': patientId},
    );
    return res.rows.map((r) => CustomField.fromRow(r.assoc())).toList();
  }

  /// جلب حقول الروشتة فقط
  static Future<List<CustomField>> getPrescriptionFields(int patientId) async {
    final res = await DatabaseService.execute(
      'SELECT * FROM patient_custom_data '
      'WHERE patient_id = :pid AND show_in_prescription = 1 ORDER BY id ASC',
      {'pid': patientId},
    );
    return res.rows.map((r) => CustomField.fromRow(r.assoc())).toList();
  }

  /// إضافة حقل جديد
  static Future<int> addField(CustomField field) async {
    final res = await DatabaseService.execute(
      'INSERT INTO patient_custom_data '
      '(patient_id, doctor_id, field_name, field_value, is_pinned, show_in_prescription) '
      'VALUES (:patient_id, :doctor_id, :field_name, :field_value, :is_pinned, :show_in_prescription)',
      field.toMap(),
    );
    return DatabaseService.toInt(res.lastInsertID);
  }

  /// تعديل حقل موجود
  static Future<void> updateField(CustomField field) async {
    await DatabaseService.execute(
      'UPDATE patient_custom_data SET '
      'field_name = :field_name, field_value = :field_value, '
      'is_pinned = :is_pinned, show_in_prescription = :show_in_prescription '
      'WHERE id = :id',
      {
        'field_name': field.fieldName.trim(),
        'field_value': field.fieldValue.trim(),
        'is_pinned': field.isPinned ? 1 : 0,
        'show_in_prescription': field.showInPrescription ? 1 : 0,
        'id': field.id,
      },
    );

    if (field.isPinned) {
      await DatabaseService.execute(
        'UPDATE doctor_pinned_field_templates SET show_in_prescription = :rx '
        'WHERE doctor_id = :did AND field_name = :fn',
        {
          'rx': field.showInPrescription ? 1 : 0,
          'did': field.doctorId,
          'fn': field.fieldName,
        },
      );
    } else {
      await DatabaseService.execute(
        'DELETE FROM doctor_pinned_field_templates '
        'WHERE doctor_id = :did AND field_name = :fn',
        {
          'did': field.doctorId,
          'fn': field.fieldName,
        },
      );
    }
  }

  /// حذف حقل
  static Future<void> deleteField(int fieldId) async {
    await DatabaseService.execute(
      'DELETE FROM patient_custom_data WHERE id = :id',
      {'id': fieldId},
    );
  }

  // ── Pinned Templates (قوالب الدكتور) ──────────────────────────────────

  /// جلب قوالب الدكتور
  static Future<List<PinnedTemplate>> getDoctorTemplates(int doctorId) async {
    final res = await DatabaseService.execute(
      'SELECT * FROM doctor_pinned_field_templates '
      'WHERE doctor_id = :did ORDER BY sort_order ASC, id ASC',
      {'did': doctorId},
    );
    return res.rows.map((r) => PinnedTemplate.fromRow(r.assoc())).toList();
  }

  /// إضافة قالب للدكتور
  static Future<void> addDoctorTemplate(PinnedTemplate t) async {
    final count = await DatabaseService.execute(
      'SELECT COUNT(*) as c FROM doctor_pinned_field_templates WHERE doctor_id = :did',
      {'did': t.doctorId},
    );
    final nextOrder = DatabaseService.toInt(count.rows.first.assoc()['c']);

    await DatabaseService.execute(
      'INSERT IGNORE INTO doctor_pinned_field_templates '
      '(doctor_id, field_name, show_in_prescription, sort_order) '
      'VALUES (:did, :fn, :rx, :so)',
      {
        'did': t.doctorId,
        'fn': t.fieldName.trim(),
        'rx': t.showInPrescription ? 1 : 0,
        'so': nextOrder,
      },
    );
  }

  /// حذف قالب
  static Future<void> deleteDoctorTemplate(int templateId) async {
    await DatabaseService.execute(
      'DELETE FROM doctor_pinned_field_templates WHERE id = :id',
      {'id': templateId},
    );
  }

  /// تحديث قالب (show_in_prescription فقط)
  static Future<void> updateDoctorTemplate(PinnedTemplate t) async {
    await DatabaseService.execute(
      'UPDATE doctor_pinned_field_templates SET show_in_prescription = :rx WHERE id = :id',
      {'rx': t.showInPrescription ? 1 : 0, 'id': t.id},
    );
  }

  // ── Auto-seed من قوالب الدكتور ─────────────────────────────────────────
  /// يُستدعى بعد إضافة مريض جديد: يزرع الحقول الـ pinned تلقائياً
  static Future<void> seedPinnedFields({
    required int patientId,
    required int doctorId,
  }) async {
    final templates = await getDoctorTemplates(doctorId);
    for (final t in templates) {
      // تحقق ما يتكررش لو اتنادى أكتر من مرة
      final exists = await DatabaseService.execute(
        'SELECT id FROM patient_custom_data '
        'WHERE patient_id = :pid AND field_name = :fn LIMIT 1',
        {'pid': patientId, 'fn': t.fieldName},
      );
      if (exists.rows.isEmpty) {
        await DatabaseService.execute(
          'INSERT INTO patient_custom_data '
          '(patient_id, doctor_id, field_name, field_value, is_pinned, show_in_prescription) '
          'VALUES (:pid, :did, :fn, \'\', 1, :rx)',
          {
            'pid': patientId,
            'did': doctorId,
            'fn': t.fieldName,
            'rx': t.showInPrescription ? 1 : 0,
          },
        );
      }
    }
  }
}
