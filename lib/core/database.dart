import 'package:mysql_client/mysql_client.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'custom_fields_db.dart';

class DatabaseService {
  static MySQLConnection? _conn;

  static const String _host = "127.0.0.1";
  static const String _user = "root";
  static const String _password = "123456";
  static const String _dbName = "clinic_db";
  static const int _port = 3306;

  static Future<MySQLConnection> get database async {
    if (_conn != null && _conn!.connected) return _conn!;
    _conn = null;
    return await _connect();
  }

  static Future<MySQLConnection> _connect() async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: _host,
        port: _port,
        userName: _user,
        password: _password,
        databaseName: _dbName,
      );
      await conn.connect();
      _conn = conn;
      return _conn!;
    } catch (e) {
      _conn = null;
      throw Exception('فشل الاتصال بقاعدة البيانات: $e');
    }
  }

  static Future<IResultSet> execute(
    String query, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      final conn = await database;
      return await conn.execute(query, params ?? {});
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('connection closed') ||
          msg.contains('can not execute') ||
          msg.contains('socketexception') ||
          msg.contains('broken pipe')) {
        _conn = null;
        final conn = await _connect();
        return await conn.execute(query, params ?? {});
      }
      rethrow;
    }
  }

  static Future<void> closeConnection() async {
    if (_conn != null && _conn!.connected) await _conn!.close();
    _conn = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TYPE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static int toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is BigInt) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static double toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is BigInt) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  static String? toStr(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.trim().isEmpty ? null : v.trim();
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static String _hashPassword(String password) => hashPassword(password);

  // ══════════════════════════════════════════════════════════════════════════
  //  DOCTOR AUTH
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String?> registerDoctor({
    required String username,
    required String password,
    required String fullName,
    required String phone,
    String specialization = 'Medical Specialist',
  }) async {
    try {
      final existUser = await execute(
        "SELECT id FROM doctors WHERE username = :u LIMIT 1",
        {"u": username.trim()},
      );
      if (existUser.rows.isNotEmpty) {
        return 'Username already exists. Please choose another.';
      }

      if (phone.trim().isNotEmpty) {
        final existPhone = await execute(
          "SELECT id FROM doctors WHERE phone = :p LIMIT 1",
          {"p": phone.trim()},
        );
        if (existPhone.rows.isNotEmpty) {
          return 'Phone number already registered.';
        }
      }

      final result = await execute(
        "INSERT INTO doctors (username, password, full_name, phone, specialization) "
        "VALUES (:u, :p, :fn, :ph, :sp)",
        {
          "u": username.trim(),
          "p": _hashPassword(password),
          "fn": fullName.trim(),
          "ph": phone.trim(),
          "sp": specialization.trim(),
        },
      );

      if (toInt(result.affectedRows) == 0) {
        return 'Registration failed. Please try again.';
      }
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Duplicate entry') || msg.contains('unique')) {
        return 'Username or phone already exists. Please choose another.';
      }
      return 'Registration error: $msg';
    }
  }

  static Future<Map<String, dynamic>?> loginDoctor({
    required String usernameOrPhone,
    required String password,
  }) async {
    try {
      final result = await execute(
        "SELECT id, username, full_name, phone, specialization "
        "FROM doctors "
        "WHERE (username = :id OR phone = :id) AND password = :p "
        "LIMIT 1",
        {
          "id": usernameOrPhone.trim(),
          "p": _hashPassword(password),
        },
      );

      if (result.rows.isEmpty) return null;

      final row = result.rows.first.assoc();
      return {
        'id': toStr(row['id']) ?? '',
        'username': toStr(row['username']) ?? '',
        'name': toStr(row['full_name'])?.isNotEmpty == true
            ? toStr(row['full_name'])!
            : usernameOrPhone.trim(),
        'phone': toStr(row['phone']) ?? '',
        'specialization': toStr(row['specialization']) ?? 'Medical Specialist',
      };
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ADD PATIENT
  // ══════════════════════════════════════════════════════════════════════════
  static Future<int> addPatient(Map<String, dynamic> data) async {
    try {
      final today = DateTime.now().toString().split(' ')[0];

      final nurseUsername =
          (data['nurse_username']?.toString().trim().isNotEmpty == true)
              ? data['nurse_username'].toString().trim()
              : data['nurse']?.toString().trim() ?? '';

      final double fee = toDouble(data['fee']);
      final double amountPaid = toDouble(data['amount_paid']);
      double remaining = toDouble(data['remaining']);
      double credit = toDouble(data['credit']);

      if (remaining == 0 && credit == 0 && amountPaid > 0) {
        final diff = amountPaid - fee;
        remaining = diff < 0 ? diff.abs() : 0.0;
        credit = diff > 0 ? diff : 0.0;
      }

      final String? visitDate =
          (data['visit_date']?.toString().trim().isNotEmpty == true)
              ? data['visit_date'].toString().trim()
              : today;

      final String? clientId =
          (data['client_id']?.toString().trim().isNotEmpty == true)
              ? data['client_id'].toString().trim()
              : null;

      final result = await execute(
        "INSERT INTO patients "
        "(name, turn, status, date, age, phone, gender, visit_type, "
        " fee, amount_paid, remaining, credit, visit_date, client_id, "
        " nurse, nurse_username, priority, department) "
        "VALUES (:name, :turn, 'waiting', :date, :age, :phone, :gender, :visit_type, "
        "        :fee, :amount_paid, :remaining, :credit, :visit_date, :client_id, "
        "        :nurse, :nurse_username, :priority, :department)",
        {
          "name": data['name']?.toString().trim() ?? "",
          "turn": toInt(data['turn']),
          "date": today,
          "age": data['age']?.toString() ?? "",
          "phone": data['phone']?.toString().trim() ?? "",
          "gender": data['gender']?.toString() ?? 'غير محدد',
          "visit_type": data['visit_type']?.toString() ?? 'كشف',
          "fee": fee,
          "amount_paid": amountPaid,
          "remaining": remaining,
          "credit": credit,
          "visit_date": visitDate,
          "client_id": clientId,
          "nurse": data['nurse']?.toString() ?? "",
          "nurse_username": nurseUsername,
          "priority": data['priority']?.toString() ?? 'عادي',
          "department": data['department']?.toString() ?? 'استقبال',
        },
      );
      final newPatientId = toInt(result.lastInsertID);
      final doctorId = toInt(data['doctor_id']);
      if (doctorId > 0) {
        await CustomFieldsDb.seedPinnedFields(
          patientId: newPatientId,
          doctorId: doctorId,
        );
      }
      return newPatientId;
    } catch (e) {
      throw Exception('خطأ في إضافة مريض: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  updatePatientStatus
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> updatePatientStatus(int patientId, String status) async {
    try {
      await execute(
        "UPDATE patients SET status = :status WHERE id = :id",
        {"status": status, "id": patientId},
      );

      if (status == 'archived') {
        await reorderActiveTurnsForToday();
      }
    } catch (e) {
      throw Exception('خطأ في تحديث الحالة: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  reorderActiveTurnsForToday
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> reorderActiveTurnsForToday() async {
    try {
      final today = DateTime.now().toString().split(' ')[0];

      final res = await execute(
        "SELECT id FROM patients "
        "WHERE date = :date AND status IN ('waiting', 'in_progress') "
        "ORDER BY turn ASC, id ASC",
        {'date': today},
      );
      final rows = res.rows.toList();

      for (int i = 0; i < rows.length; i++) {
        final id = toInt(rows[i].assoc()['id']);
        await execute(
          "UPDATE patients SET turn = :turn WHERE id = :id",
          {'turn': 9000 + i, 'id': id},
        );
      }

      for (int i = 0; i < rows.length; i++) {
        final id = toInt(rows[i].assoc()['id']);
        await execute(
          "UPDATE patients SET turn = :turn WHERE id = :id",
          {'turn': i + 1, 'id': id},
        );
      }

      await updateSetting(
          'last_patient_change', DateTime.now().toIso8601String());
    } catch (_) {
      // non-blocking
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  saveExamination ✅ UPDATED with extra_fields
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> saveExamination({
    required int patientId,
    required String diagnosis,
    required String treatment,
    required String duration,
    double? fee,
    double? amountPaid,
    String? extraFieldsJson, // NEW: الحقول الإضافية
  }) async {
    try {
      String extraSet = '';
      final Map<String, dynamic> params = {
        "diag": diagnosis.trim(),
        "treat": treatment.trim(),
        "time": DateTime.now().toIso8601String(),
        "dur": duration.trim(),
        "id": patientId,
      };

      // NEW: إضافة extra_fields إذا وجدت
      if (extraFieldsJson != null && extraFieldsJson.isNotEmpty) {
        extraSet += ', extra_fields = :extra_fields';
        params['extra_fields'] = extraFieldsJson;
      }

      if (fee != null) {
        final double paid = amountPaid ?? fee;
        final double diff = paid - fee;
        params['fee'] = fee;
        params['amount_paid'] = paid;
        params['remaining'] = diff < 0 ? diff.abs() : 0.0;
        params['credit'] = diff > 0 ? diff : 0.0;
        extraSet +=
            ', fee = :fee, amount_paid = :amount_paid, remaining = :remaining, credit = :credit';
      }

      await execute(
        "UPDATE patients SET "
        "diagnosis = :diag, treatment = :treat, status = 'completed', "
        "visit_time = :time, consultation_duration = :dur$extraSet "
        "WHERE id = :id",
        params,
      );

      await updateSetting(
          'last_patient_change', DateTime.now().toIso8601String());
    } catch (e) {
      throw Exception('خطأ في حفظ الفحص: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE PAYMENT
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> updatePayment({
    required int patientId,
    required double fee,
    required double amountPaid,
  }) async {
    try {
      final diff = amountPaid - fee;
      final remaining = diff < 0 ? diff.abs() : 0.0;
      final credit = diff > 0 ? diff : 0.0;

      await execute(
        "UPDATE patients SET "
        "fee = :fee, amount_paid = :amount_paid, "
        "remaining = :remaining, credit = :credit "
        "WHERE id = :id",
        {
          "fee": fee,
          "amount_paid": amountPaid,
          "remaining": remaining,
          "credit": credit,
          "id": patientId,
        },
      );
    } catch (e) {
      throw Exception('خطأ في تحديث الدفع: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GET PATIENT BY ID
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, String?>?> getPatientById(int patientId) async {
    try {
      final result = await execute(
        "SELECT * FROM patients WHERE id = :id",
        {"id": patientId},
      );
      return result.rows.isNotEmpty ? result.rows.first.assoc() : null;
    } catch (e) {
      throw Exception('خطأ في جلب المريض: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GET ALL PATIENTS
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, String?>>> getAllPatients({
    String? status,
    String? date,
    int limit = 100,
  }) async {
    try {
      String query = "SELECT * FROM patients WHERE 1=1";
      final params = <String, dynamic>{};

      if (status != null && status.isNotEmpty) {
        query += " AND status = :status";
        params["status"] = status;
      }
      if (date != null && date.isNotEmpty) {
        query += " AND date = :date";
        params["date"] = date;
      }
      query += " ORDER BY id DESC LIMIT :lim";
      params["lim"] = limit;

      final result = await execute(query, params);
      return result.rows.map((r) => r.assoc()).toList();
    } catch (e) {
      throw Exception('خطأ في جلب المرضى: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GET ALL VISITS (includes extra_fields)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, String?>>> getAllVisits(
      String name, String? phone) async {
    try {
      final result = await execute(
        "SELECT * FROM patients "
        "WHERE (name = :name OR (phone = :phone AND phone IS NOT NULL AND phone != '')) "
        "ORDER BY id DESC",
        {"name": name.trim(), "phone": phone?.trim() ?? ""},
      );
      return result.rows.map((r) => r.assoc()).toList();
    } catch (e) {
      throw Exception('خطأ في جلب الزيارات: $e');
    }
  }

  static Future<Map<String, String?>?> getLastVisit(
      String name, String? phone) async {
    try {
      final result = await execute(
        "SELECT * FROM patients "
        "WHERE (name = :name OR (phone = :phone AND phone IS NOT NULL AND phone != '')) "
        "AND status = 'completed' ORDER BY id DESC LIMIT 1",
        {"name": name.trim(), "phone": phone?.trim() ?? ""},
      );
      return result.rows.isNotEmpty ? result.rows.first.assoc() : null;
    } catch (e) {
      throw Exception('خطأ في جلب آخر زيارة: $e');
    }
  }

  static Future<void> deletePatient(int patientId) async {
    try {
      await execute(
        "DELETE FROM patients WHERE id = :id",
        {"id": patientId},
      );
    } catch (e) {
      throw Exception('خطأ في حذف المريض: $e');
    }
  }

  static Future<List<Map<String, String?>>> searchPatients(String query) async {
    try {
      final term = "%${query.trim()}%";
      final result = await execute(
        "SELECT * FROM patients WHERE name LIKE :s OR phone LIKE :s "
        "ORDER BY date DESC LIMIT 50",
        {"s": term},
      );
      return result.rows.map((r) => r.assoc()).toList();
    } catch (e) {
      throw Exception('خطأ في البحث: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> updateSetting(String key, String value) async {
    try {
      await execute(
        "INSERT INTO settings (`key`, value) VALUES (:key, :value) "
        "ON DUPLICATE KEY UPDATE value = :value",
        {"key": key, "value": value},
      );
    } catch (e) {
      throw Exception('خطأ في تحديث الإعدادات: $e');
    }
  }

  static Future<String?> getSetting(String key) async {
    try {
      final res = await execute(
        "SELECT value FROM settings WHERE `key` = :key",
        {"key": key},
      );
      return res.rows.isNotEmpty ? res.rows.first.assoc()['value'] : null;
    } catch (e) {
      throw Exception('خطأ في جلب الإعداد: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MESSAGES
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> cleanOldMessages() async {
    try {
      final today = DateTime.now().toString().split(' ')[0];
      await execute(
        "DELETE FROM messages WHERE DATE(created_at) != :today",
        {"today": today},
      );
    } catch (e) {
      throw Exception('خطأ في حذف الرسائل: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getMessages({
    String? receiver,
    int limit = 50,
  }) async {
    try {
      String query = "SELECT * FROM messages WHERE 1=1";
      final params = <String, dynamic>{};
      if (receiver != null && receiver.isNotEmpty) {
        query += " AND (receiver = :r OR receiver = 'all')";
        params['r'] = receiver;
      }
      query += " ORDER BY created_at DESC LIMIT :lim";
      params['lim'] = limit;

      final result = await execute(query, params);
      return result.rows.map((r) {
        final row = r.assoc();
        return <String, dynamic>{
          'id': toInt(row['id']),
          'sender': row['sender'] ?? '',
          'receiver': row['receiver'] ?? 'all',
          'content': row['content'] ?? '',
          'is_read': toInt(row['is_read']),
          'created_at': row['created_at'] ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('خطأ في جلب الرسائل: $e');
    }
  }

  static Future<void> sendMessage({
    required String sender,
    required String content,
    String receiver = 'all',
  }) async {
    try {
      await execute(
        "INSERT INTO messages (sender, receiver, content) "
        "VALUES (:sender, :receiver, :content)",
        {
          'sender': sender.trim(),
          'receiver': receiver.trim(),
          'content': content.trim(),
        },
      );
    } catch (e) {
      throw Exception('خطأ في إرسال الرسالة: $e');
    }
  }

  static Future<void> markMessagesAsRead(String receiver) async {
    try {
      await execute(
        "UPDATE messages SET is_read = 1 "
        "WHERE (receiver = :r OR receiver = 'all') AND is_read = 0",
        {'r': receiver},
      );
    } catch (e) {
      throw Exception('خطأ في تحديث الرسائل: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATISTICS
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getStatistics(String date) async {
    try {
      final total = await execute(
        "SELECT COUNT(*) as count FROM patients WHERE date = :date",
        {"date": date},
      );

      final completed = await execute(
        "SELECT COUNT(*) as count, "
        "COALESCE(SUM(fee), 0)         as total_fee, "
        "COALESCE(SUM(amount_paid), 0) as total_paid, "
        "COALESCE(SUM(remaining), 0)   as total_remaining, "
        "COALESCE(SUM(credit), 0)      as total_credit "
        "FROM patients WHERE date = :date AND status = 'completed'",
        {"date": date},
      );

      final waiting = await execute(
        "SELECT COUNT(*) as count FROM patients WHERE date = :date AND status = 'waiting'",
        {"date": date},
      );

      final completedRow = completed.rows.first.assoc();

      return {
        'total': toInt(total.rows.first.assoc()['count']),
        'completed': toInt(completedRow['count']),
        'waiting': toInt(waiting.rows.first.assoc()['count']),
        'total_fee': toDouble(completedRow['total_fee']),
        'total_paid': toDouble(completedRow['total_paid']),
        'total_remaining': toDouble(completedRow['total_remaining']),
        'total_credit': toDouble(completedRow['total_credit']),
      };
    } catch (e) {
      throw Exception('خطأ في الإحصائيات: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FINANCIAL STATS
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getFinancialStats({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final res = await execute(
        "SELECT "
        "COALESCE(SUM(fee), 0)         as total_fee, "
        "COALESCE(SUM(amount_paid), 0) as total_paid, "
        "COALESCE(SUM(remaining), 0)   as total_remaining, "
        "COALESCE(SUM(credit), 0)      as total_credit, "
        "COUNT(*) as total_patients "
        "FROM patients "
        "WHERE date BETWEEN :from AND :to AND status = 'completed'",
        {'from': fromDate, 'to': toDate},
      );

      final row = res.rows.first.assoc();
      return {
        'total_fee': toDouble(row['total_fee']),
        'total_paid': toDouble(row['total_paid']),
        'total_remaining': toDouble(row['total_remaining']),
        'total_credit': toDouble(row['total_credit']),
        'total_patients': toInt(row['total_patients']),
      };
    } catch (e) {
      throw Exception('خطأ في الإحصائيات المالية: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  IMPORT HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<bool> patientExists({
    required String name,
    String? phone,
    String? date,
  }) async {
    try {
      if (phone != null && phone.trim().isNotEmpty) {
        final res = await execute(
          "SELECT id FROM patients WHERE phone = :phone AND phone != '' LIMIT 1",
          {"phone": phone.trim()},
        );
        if (res.rows.isNotEmpty) return true;
      }
      if (date != null && date.trim().isNotEmpty) {
        final res = await execute(
          "SELECT id FROM patients WHERE name = :name AND date = :date LIMIT 1",
          {"name": name.trim(), "date": date.trim()},
        );
        if (res.rows.isNotEmpty) return true;
      }
      return false;
    } catch (e) {
      throw Exception('خطأ في التحقق: $e');
    }
  }

  static Future<int> _importPatient(Map<String, dynamic> data) async {
    final nurseUsername =
        (data['nurse_username']?.toString().trim().isNotEmpty == true)
            ? data['nurse_username'].toString().trim()
            : data['nurse']?.toString().trim() ?? '';

    final double fee = toDouble(data['fee']);
    final double amountPaid =
        data['amount_paid'] != null ? toDouble(data['amount_paid']) : fee;
    final diff = amountPaid - fee;
    final remaining = data['remaining'] != null
        ? toDouble(data['remaining'])
        : (diff < 0 ? diff.abs() : 0.0);
    final credit = data['credit'] != null
        ? toDouble(data['credit'])
        : (diff > 0 ? diff : 0.0);

    final importDate = (data['date']?.toString() ?? '').isNotEmpty
        ? data['date'].toString()
        : DateTime.now().toString().split(' ')[0];

    final result = await execute(
      "INSERT INTO patients "
      "(name, turn, status, date, age, phone, gender, visit_type, "
      " fee, amount_paid, remaining, credit, visit_date, "
      " nurse, nurse_username, priority, department, "
      " diagnosis, treatment, visit_time) "
      "VALUES "
      "(:name, 0, :status, :date, :age, :phone, :gender, :visit_type, "
      " :fee, :amount_paid, :remaining, :credit, :visit_date, "
      " :nurse, :nurse_username, :priority, :department, "
      " :diag, :treat, :vtime)",
      {
        "name": data['name']?.toString().trim() ?? "",
        "status": data['status']?.toString() ?? 'completed',
        "date": importDate,
        "age": data['age']?.toString() ?? "",
        "phone": data['phone']?.toString().trim() ?? "",
        "gender": data['gender']?.toString() ?? 'غير محدد',
        "visit_type": data['visit_type']?.toString() ?? 'كشف',
        "fee": fee,
        "amount_paid": amountPaid,
        "remaining": remaining,
        "credit": credit,
        "visit_date": importDate,
        "nurse": data['nurse']?.toString() ?? "",
        "nurse_username": nurseUsername,
        "priority": data['priority']?.toString() ?? 'عادي',
        "department": data['department']?.toString() ?? 'استقبال',
        "diag": data['diagnosis']?.toString() ?? "",
        "treat": data['treatment']?.toString() ?? "",
        "vtime": data['visit_time']?.toString() ?? "",
      },
    );
    return toInt(result.lastInsertID);
  }

  static Future<Map<String, dynamic>> batchImportPatients(
      List<Map<String, dynamic>> patients) async {
    int imported = 0, skipped = 0, errors = 0;
    final errorLog = <String>[];

    for (final p in patients) {
      final name = p['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      try {
        final isDup = await patientExists(
          name: name,
          phone: p['phone']?.toString(),
          date: p['date']?.toString(),
        );
        if (isDup) {
          skipped++;
          continue;
        }
      } catch (_) {
        skipped++;
        continue;
      }
      try {
        await _importPatient(p);
        imported++;
      } catch (e) {
        errorLog.add('$name → $e');
        errors++;
      }
    }

    return {
      'imported': imported,
      'skipped': skipped,
      'errors': errors,
      'errorLog': errorLog,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DEBUG IMPORT TEST
  // ══════════════════════════════════════════════════════════════════════════
  static Future<String> debugImportTest() async {
    final log = StringBuffer();
    try {
      log.writeln('🔌 Testing connection...');
      await database;
      log.writeln('✅ Connected OK');

      log.writeln('📋 Columns in patients table:');
      final cols = await execute("SHOW COLUMNS FROM patients");
      final colNames = <String>[];
      for (final row in cols.rows) {
        final r = row.assoc();
        colNames.add(r['Field'] ?? '');
        log.writeln('  • ${r['Field']} | ${r['Type']}');
      }

      final requiredCols = [
        'diagnosis',
        'treatment',
        'visit_time',
        'nurse_username',
        'amount_paid',
        'remaining',
        'credit',
        'visit_date',
        'client_id',
        'extra_fields', // NEW: check for extra_fields column
      ];
      final missing = requiredCols.where((c) => !colNames.contains(c)).toList();
      if (missing.isNotEmpty) {
        log.writeln('❌ MISSING COLUMNS: $missing');
        log.writeln('👉 Please run: ALTER TABLE patients ADD COLUMN extra_fields TEXT DEFAULT NULL;');
      } else {
        log.writeln('🎉 All required columns exist!');
      }

      log.writeln('');
      log.writeln('👨‍⚕️ Checking doctors table...');
      final doctorsCols = await execute("SHOW COLUMNS FROM doctors");
      log.writeln(
          '✅ doctors table exists — ${doctorsCols.rows.length} columns');
    } catch (e) {
      log.writeln('❌ ERROR: $e');
    }
    return log.toString();
  }
}