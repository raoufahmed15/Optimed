// lib/services/server_service.dart
// ✅ UPDATED: دعم amount_paid, remaining, credit, visit_date في /add
// ✅ UPDATED: _sanitizeRow يرجع الحقول الجديدة
// ✅ UPDATED: /nurse/stats بيشمل إحصائيات مالية تفصيلية
// ✅ UPDATED: /patient-visits يرجع amount_paid مع كل زيارة
// ✅ الـ idempotency check على client_id لا يزال كما هو (محكم)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import '../core/database.dart';

class ServerService {
  HttpServer? _server;
  bool _isRunning = false;
  late Map<String, dynamic> _doctor;

  bool get isRunning => _isRunning;

  // ══════════════════════════════════════════════════════════════════════════
  //  TYPE HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static String? _toStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _hashPassword(String password) {
    final bytes  = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String _safeParam(HttpRequest request, String key) {
    try {
      return (request.uri.queryParameters[key] ?? '').trim();
    } catch (_) {
      try {
        final raw = request.uri.query;
        for (final part in raw.split('&')) {
          final idx = part.indexOf('=');
          if (idx < 0) continue;
          final k = part.substring(0, idx);
          final v = part.substring(idx + 1);
          if (k == key) {
            try {
              return Uri.decodeComponent(v.replaceAll('+', ' ')).trim();
            } catch (_) {
              return v.trim();
            }
          }
        }
      } catch (_) {}
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  START / STOP
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> startServer(Map<String, dynamic> doctor) async {
    try {
      _doctor = doctor;

      await _ensureNursesTable();
      await _ensureNurseUsernameColumn();
      await _ensureClientIdColumn();
      await _ensurePaymentColumns(); // ✅ NEW

      await DatabaseService.updateSetting('nurse_call',          'idle');
      await DatabaseService.updateSetting('current_call_name',   '');
      await DatabaseService.updateSetting('current_call_phone',  '');
      await DatabaseService.updateSetting('current_call_turn',   '--');
      await DatabaseService.updateSetting('current_call_ts',     '');

      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _isRunning = true;

      final interfaces = await NetworkInterface.list();
      String ip = 'localhost';
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127.')) {
            ip = addr.address;
            break;
          }
        }
      }
      debugPrint('✅ Server running at: http://$ip:8080');
      _server!.listen((req) async => await _handleRequest(req));
    } catch (e) {
      debugPrint('❌ Server failed: $e');
      _isRunning = false;
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _isRunning = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ENSURE COLUMNS / TABLES
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _ensureNursesTable() async {
    try {
      final conn = await DatabaseService.database;
      await conn.execute("""
        CREATE TABLE IF NOT EXISTS nurses (
          id         VARCHAR(36)  PRIMARY KEY DEFAULT (UUID()),
          name       VARCHAR(255) NOT NULL,
          username   VARCHAR(100) NOT NULL UNIQUE,
          password   VARCHAR(64)  NOT NULL,
          phone      VARCHAR(30)  DEFAULT '',
          shift      VARCHAR(100) DEFAULT '',
          role       VARCHAR(50)  DEFAULT 'Nurse',
          created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      """, {});
      debugPrint('✅ nurses table ready');
    } catch (e) {
      debugPrint('⚠️ Could not ensure nurses table: $e');
    }
  }

  Future<void> _ensureNurseUsernameColumn() async {
    try {
      final conn = await DatabaseService.database;
      await conn.execute("""
        ALTER TABLE patients
        ADD COLUMN IF NOT EXISTS nurse_username VARCHAR(100) DEFAULT ''
      """, {});
      debugPrint('✅ nurse_username column ready');
    } catch (_) {
      try {
        final conn = await DatabaseService.database;
        await conn.execute("SELECT nurse_username FROM patients LIMIT 1", {});
      } catch (_) {
        try {
          final conn = await DatabaseService.database;
          await conn.execute("""
            ALTER TABLE patients ADD COLUMN nurse_username VARCHAR(100) DEFAULT ''
          """, {});
          debugPrint('✅ nurse_username column added');
        } catch (e2) {
          debugPrint('⚠️ Could not add nurse_username: $e2');
        }
      }
    }
  }

  Future<void> _ensureClientIdColumn() async {
    try {
      final conn = await DatabaseService.database;
      await conn.execute("""
        ALTER TABLE patients
        ADD COLUMN IF NOT EXISTS client_id VARCHAR(255) NULL DEFAULT NULL
      """, {});
      debugPrint('✅ client_id column ready');
    } catch (_) {
      try {
        final conn = await DatabaseService.database;
        await conn.execute("SELECT client_id FROM patients LIMIT 1", {});
      } catch (_) {
        try {
          final conn = await DatabaseService.database;
          await conn.execute("""
            ALTER TABLE patients ADD COLUMN client_id VARCHAR(255) NULL DEFAULT NULL
          """, {});
          debugPrint('✅ client_id column added');
        } catch (e2) {
          debugPrint('⚠️ Could not add client_id: $e2');
        }
      }
    }

    try {
      final conn = await DatabaseService.database;
      await conn.execute(
          "UPDATE patients SET client_id = NULL WHERE client_id = ''");
      await conn.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_client_id_unique ON patients(client_id)");
      debugPrint('✅ client_id unique index ready');
    } catch (_) {
      try {
        final conn = await DatabaseService.database;
        await conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_client_id ON patients(client_id)");
      } catch (_) {}
    }
  }

  // ✅ NEW — يضمن وجود حقول الدفع و visit_date
  Future<void> _ensurePaymentColumns() async {
    final cols = {
      'amount_paid': 'DECIMAL(10,2) DEFAULT 0.00',
      'remaining':   'DECIMAL(10,2) DEFAULT 0.00',
      'credit':      'DECIMAL(10,2) DEFAULT 0.00',
      'visit_date':  'DATE NULL',
    };

    for (final entry in cols.entries) {
      try {
        final conn = await DatabaseService.database;
        await conn.execute(
          "ALTER TABLE patients ADD COLUMN IF NOT EXISTS `${entry.key}` ${entry.value}",
          {},
        );
        debugPrint('✅ ${entry.key} column ready');
      } catch (_) {
        // MySQL 5.7 doesn't support IF NOT EXISTS in ALTER
        try {
          final conn = await DatabaseService.database;
          await conn.execute("SELECT `${entry.key}` FROM patients LIMIT 1", {});
        } catch (_) {
          try {
            final conn = await DatabaseService.database;
            await conn.execute(
              "ALTER TABLE patients ADD COLUMN `${entry.key}` ${entry.value}",
              {},
            );
            debugPrint('✅ ${entry.key} column added (fallback)');
          } catch (e2) {
            debugPrint('⚠️ Could not add ${entry.key}: $e2');
          }
        }
      }
    }

    // إضافة index لـ visit_date
    try {
      final conn = await DatabaseService.database;
      await conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_patients_visit_date ON patients(visit_date)",
        {},
      );
    } catch (_) {}

    debugPrint('✅ Payment columns ready');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REQUEST HANDLER
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers
          .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers
          .add('Access-Control-Allow-Headers', 'Content-Type');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      final path   = request.uri.path;
      final method = request.method;

      // ── ping ──────────────────────────────────────────────────────────────
      if (method == 'GET' && path == '/ping') {
        _json(request, {'status': 'online'});
        return;
      }

      // ── nurse register ────────────────────────────────────────────────────
      if (method == 'POST' && path == '/nurse/register') {
        final data     = await _readJson(request);
        final name     = (data['name']     ?? '').toString().trim();
        final username = (data['username'] ?? '').toString().trim();
        final password = (data['password'] ?? '').toString();
        final phone    = (data['phone']    ?? '').toString().trim();
        final shift    = (data['shift']    ?? '').toString().trim();
        final role     = (data['role']     ?? 'Nurse').toString().trim();

        if (name.isEmpty || username.isEmpty || password.isEmpty) {
          request.response.statusCode = 400;
          _json(request, {'success': false, 'message': 'الاسم واسم المستخدم وكلمة المرور مطلوبة'});
          return;
        }

        final conn     = await DatabaseService.database;
        final existing = await conn.execute(
          'SELECT id FROM nurses WHERE username = :u LIMIT 1',
          {'u': username},
        );
        if (existing.rows.isNotEmpty) {
          request.response.statusCode = 409;
          _json(request, {'success': false, 'message': 'اسم المستخدم مستخدم بالفعل'});
          return;
        }

        final newId = '${DateTime.now().millisecondsSinceEpoch}_$username';
        await conn.execute(
          "INSERT INTO nurses (id, name, username, password, phone, shift, role) "
          "VALUES (:id, :name, :username, :password, :phone, :shift, :role)",
          {
            'id': newId, 'name': name, 'username': username,
            'password': password, 'phone': phone, 'shift': shift, 'role': role,
          },
        );

        request.response.statusCode = 201;
        _json(request, {
          'success': true,
          'user': {
            'id': newId, 'name': name, 'username': username,
            'phone': phone, 'shift': shift, 'role': role,
            'created_at': DateTime.now().toIso8601String(),
          },
        });
        return;
      }

      // ── nurse login ───────────────────────────────────────────────────────
      if (method == 'POST' && path == '/nurse/login') {
        final data     = await _readJson(request);
        final username = (data['username'] ?? '').toString().trim();
        final password = (data['password'] ?? '').toString();

        if (username.isEmpty || password.isEmpty) {
          request.response.statusCode = 400;
          _json(request, {'success': false, 'message': 'اسم المستخدم وكلمة المرور مطلوبان'});
          return;
        }

        final conn   = await DatabaseService.database;
        final result = await conn.execute(
          'SELECT * FROM nurses WHERE username = :u AND password = :p LIMIT 1',
          {'u': username, 'p': password},
        );

        if (result.rows.isEmpty) {
          request.response.statusCode = 401;
          _json(request, {'success': false, 'message': 'اسم المستخدم أو كلمة المرور غير صحيحة'});
          return;
        }

        final row = result.rows.first.assoc();
        _json(request, {
          'success': true,
          'user': {
            'id': row['id'] ?? '', 'name': row['name'] ?? '',
            'username': row['username'] ?? '', 'phone': row['phone'] ?? '',
            'shift': row['shift'] ?? '', 'role': row['role'] ?? 'Nurse',
          },
        });
        return;
      }

      // ── nurses list ───────────────────────────────────────────────────────
      if (method == 'GET' && path == '/nurses') {
        final conn   = await DatabaseService.database;
        final result = await conn.execute(
          'SELECT id, name, username, phone, shift, role, created_at '
          'FROM nurses ORDER BY created_at ASC',
          {},
        );
        final nurses = result.rows.map((r) {
          final row = r.assoc();
          return {
            'id': row['id'] ?? '', 'name': row['name'] ?? '',
            'username': row['username'] ?? '', 'phone': row['phone'] ?? '',
            'shift': row['shift'] ?? '', 'role': row['role'] ?? 'Nurse',
            'created_at': row['created_at'] ?? '',
          };
        }).toList();
        _json(request, nurses);
        return;
      }

      // ── nurse stats ✅ UPDATED — بيشمل إحصائيات مالية ──────────────────
      if (method == 'GET' && path == '/nurse/stats') {
        final params    = request.uri.queryParameters;
        final today     = DateTime.now().toString().split(' ')[0];
        final startDate = params['start'] ?? today;
        final endDate   = params['end']   ?? today;

        final conn      = await DatabaseService.database;
        final nursesRes = await conn.execute(
          'SELECT id, name, username, shift FROM nurses ORDER BY name ASC',
          {},
        );

        final List<Map<String, dynamic>> stats = [];

        for (final nurseRow in nursesRes.rows) {
          final nr       = nurseRow.assoc();
          final username = nr['username'] ?? '';
          final name     = nr['name']     ?? '';
          final shift    = nr['shift']    ?? '';

          final sentRes = await conn.execute(
            "SELECT COUNT(*) as total_sent FROM patients "
            "WHERE nurse_username = :u AND date >= :start AND date <= :end",
            {'u': username, 'start': startDate, 'end': endDate},
          );
          final totalSent = _toInt(sentRes.rows.first.assoc()['total_sent']);

          final completedRes = await conn.execute(
            "SELECT COUNT(*) as total_completed FROM patients "
            "WHERE nurse_username = :u AND date >= :start AND date <= :end "
            "AND status IN ('completed', 'archived')",
            {'u': username, 'start': startDate, 'end': endDate},
          );
          final totalCompleted =
              _toInt(completedRes.rows.first.assoc()['total_completed']);

          // ✅ UPDATED — إحصائيات مالية تفصيلية
          final financialRes = await conn.execute(
            "SELECT "
            "COALESCE(SUM(CAST(fee AS DECIMAL(10,2))), 0)         as total_fee, "
            "COALESCE(SUM(CAST(amount_paid AS DECIMAL(10,2))), 0) as total_paid, "
            "COALESCE(SUM(CAST(remaining AS DECIMAL(10,2))), 0)   as total_remaining, "
            "COALESCE(SUM(CAST(credit AS DECIMAL(10,2))), 0)      as total_credit "
            "FROM patients "
            "WHERE nurse_username = :u AND date >= :start AND date <= :end "
            "AND status IN ('completed', 'archived')",
            {'u': username, 'start': startDate, 'end': endDate},
          );
          final finRow = financialRes.rows.first.assoc();

          final typesRes = await conn.execute(
            "SELECT visit_type, COUNT(*) as count FROM patients "
            "WHERE nurse_username = :u AND date >= :start AND date <= :end "
            "AND status IN ('completed', 'archived') GROUP BY visit_type",
            {'u': username, 'start': startDate, 'end': endDate},
          );
          final visitTypes = typesRes.rows.map((r) {
            final row = r.assoc();
            return {
              'visit_type': row['visit_type'] ?? '',
              'count':      _toInt(row['count']),
            };
          }).toList();

          stats.add({
            'username':        username,
            'name':            name,
            'shift':           shift,
            'total_sent':      totalSent,
            'total_completed': totalCompleted,
            // ── مالي ✅ NEW ──
            'total_earnings':  _toDouble(finRow['total_fee']),       // للتوافق القديم
            'total_fee':       _toDouble(finRow['total_fee']),
            'total_paid':      _toDouble(finRow['total_paid']),
            'total_remaining': _toDouble(finRow['total_remaining']),
            'total_credit':    _toDouble(finRow['total_credit']),
            'visit_types':     visitTypes,
            'period_start':    startDate,
            'period_end':      endDate,
          });
        }

        _json(request, {'success': true, 'stats': stats});
        return;
      }

      // ── clinic info GET ───────────────────────────────────────────────────
      if (method == 'GET' && path == '/clinic-info') {
        final fields = [
          'doctor_name', 'department', 'ticker', 'waiting_msg',
          'header_color', 'card_color', 'accent_color', 'logo_base64', 'updated_at',
        ];
        final Map<String, String> info = {};
        for (final key in fields) {
          final val = await DatabaseService.getSetting(key);
          if (val != null) info[key] = val;
        }
        _json(request, {
          'ticker':       info['ticker']       ?? 'الرجاء الالتزام بالهدوء في قاعة الانتظار',
          'waiting_msg':  info['waiting_msg']  ?? 'في انتظار أول مريض',
          'header_color': info['header_color'] ?? '',
          'card_color':   info['card_color']   ?? '',
          'accent_color': info['accent_color'] ?? '',
          'logo_base64':  info['logo_base64']  ?? '',
          'updated_at':   info['updated_at']   ?? '',
        });
        return;
      }

      // ── clinic info POST ──────────────────────────────────────────────────
      if (method == 'POST' && path == '/clinic-info') {
        final data   = await _readJson(request);
        final fields = {
          'doctor_name':  data['doctor_name']?.toString()  ?? '',
          'department':   data['department']?.toString()   ?? '',
          'ticker':       data['ticker']?.toString()       ?? '',
          'waiting_msg':  data['waiting_msg']?.toString()  ?? '',
          'header_color': data['header_color']?.toString() ?? '',
          'card_color':   data['card_color']?.toString()   ?? '',
          'accent_color': data['accent_color']?.toString() ?? '',
          'logo_base64':  data['logo_base64']?.toString()  ?? '',
          'updated_at':   DateTime.now().toIso8601String(),
        };
        for (final e in fields.entries) {
          await DatabaseService.updateSetting(e.key, e.value);
        }
        _json(request, {'success': true});
        return;
      }

      // ── visit types ───────────────────────────────────────────────────────
      if (method == 'GET' && path == '/visit-types') {
        final raw = await DatabaseService.getSetting('visit_types_list') ?? '[]';
        request.response.statusCode = 200;
        request.response.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
        request.response.write(raw);
        await request.response.close();
        return;
      }

      if (method == 'POST' && path == '/visit-types') {
        final body = await utf8.decoder.bind(request).join();
        try {
          final decoded = jsonDecode(body);
          if (decoded is! List) throw const FormatException('not a list');
        } catch (_) {
          request.response.statusCode = 400;
          request.response.write(jsonEncode({'error': 'يجب إرسال قائمة'}));
          await request.response.close();
          return;
        }
        await DatabaseService.updateSetting('visit_types_list', body);
        _json(request, {'success': true});
        return;
      }

      // ── nurse call ────────────────────────────────────────────────────────
      if (method == 'GET' && path == '/check-call') {
        final status = await DatabaseService.getSetting('nurse_call') ?? 'idle';
        _json(request, {'status': status});
        return;
      }

      if (method == 'POST' && path == '/update-call') {
        final data      = await _readJson(request);
        final newStatus = data['status']?.toString() ?? 'idle';
        await DatabaseService.updateSetting('nurse_call', newStatus);
        _json(request, {'success': true});
        return;
      }

      if (method == 'POST' && path == '/call-only') {
        final data = await _readJson(request);
        await DatabaseService.updateSetting('current_call_name',  data['name']?.toString()  ?? '');
        await DatabaseService.updateSetting('current_call_phone', data['phone']?.toString() ?? '');
        await DatabaseService.updateSetting('current_call_turn',  data['turn']?.toString()  ?? '--');
        await DatabaseService.updateSetting('current_call_ts',    DateTime.now().toIso8601String());
        _json(request, {'success': true});
        return;
      }

      if (method == 'GET' && path == '/current-call') {
        final name  = await DatabaseService.getSetting('current_call_name')  ?? '';
        final phone = await DatabaseService.getSetting('current_call_phone') ?? '';
        final turn  = await DatabaseService.getSetting('current_call_turn')  ?? '--';
        final ts    = await DatabaseService.getSetting('current_call_ts')    ?? '';
        _json(request, {'name': name, 'phone': phone, 'turn': turn, 'timestamp': ts});
        return;
      }

      // ════════════════════════════════════════════════════════════════════════
      //  ✅ POST /add — مع دعم كامل للحقول الجديدة
      //
      //  الحقول الجديدة: amount_paid, remaining, credit, visit_date
      //  الـ idempotency check على client_id كما هو
      // ════════════════════════════════════════════════════════════════════════
      if (method == 'POST' && path == '/add') {
        final data     = await _readJson(request);
        final name     = data['name']?.toString().trim()      ?? '';
        final clientId = data['client_id']?.toString().trim() ?? '';

        if (name.isEmpty) {
          request.response.statusCode = 400;
          _json(request, {'error': 'اسم المريض مطلوب'});
          return;
        }

        final today = DateTime.now().toString().split(' ')[0];
        final conn  = await DatabaseService.database;

        // ── Step 1: Idempotency check على client_id ──────────────────────
        if (clientId.isNotEmpty) {
          try {
            final checkRes = await conn.execute(
              'SELECT id, turn, visit_time, amount_paid, remaining, credit '
              'FROM patients WHERE client_id = :client_id LIMIT 1',
              {'client_id': clientId},
            );
            if (checkRes.rows.isNotEmpty) {
              final row        = checkRes.rows.first.assoc();
              final existingId = _toInt(row['id']);
              final existTurn  = _toInt(row['turn']);
              final visitTime  = row['visit_time']?.toString() ??
                  DateFormat('HH:mm').format(DateTime.now());

              debugPrint('⚡ Idempotent /add: client_id=$clientId already exists → id=$existingId turn=$existTurn');

              _json(request, {
                'success':     true,
                'id':          existingId,
                'turn':        existTurn,
                'name':        name,
                'visit_time':  visitTime,
                'amount_paid': _toDouble(row['amount_paid']), // ✅ NEW
                'remaining':   _toDouble(row['remaining']),   // ✅ NEW
                'credit':      _toDouble(row['credit']),      // ✅ NEW
              });
              return;
            }
          } catch (e) {
            debugPrint('⚠️ client_id pre-check failed: $e');
          }
        }

        // ── Step 2: حساب التيرن ───────────────────────────────────────────
        final nurseTurn = _toInt(data['turnNumber'] ?? data['turn']);
        int finalTurn;
        if (nurseTurn > 0) {
          finalTurn = nurseTurn;
        } else {
          final maxTurnRes = await conn.execute(
            "SELECT COALESCE(MAX(turn), 0) as max_turn FROM patients "
            "WHERE date = :date AND status IN ('waiting', 'in_progress')",
            {'date': today},
          );
          final maxTurn = _toInt(maxTurnRes.rows.first.assoc()['max_turn']);
          finalTurn = maxTurn + 1;
        }

        final inStatus    = data['status']?.toString()  ?? 'waiting';
        final finalStatus = inStatus == 'in_progress' ? 'in_progress' : 'waiting';
        final now         = DateFormat('HH:mm').format(DateTime.now());
        final nurseUsername = (data['nurse_username'] ?? '').toString().trim();

        // ── ✅ NEW: حساب بيانات الدفع ──────────────────────────────────────
        final double fee        = _toDouble(data['fee'] ?? data['price']);
        final double amountPaid = _toDouble(data['amount_paid']);
        double remaining        = _toDouble(data['remaining']);
        double credit           = _toDouble(data['credit']);

        // لو الممرضة بعتت amount_paid بس ما بعتتش remaining/credit → نحسبهم
        if (remaining == 0.0 && credit == 0.0 && amountPaid > 0) {
          final diff = amountPaid - fee;
          remaining  = diff < 0 ? diff.abs() : 0.0;
          credit     = diff > 0 ? diff       : 0.0;
        }

        // ── ✅ NEW: تاريخ الزيارة ──────────────────────────────────────────
        final visitDateRaw = data['visit_date']?.toString().trim() ?? '';
        final String? visitDate = visitDateRaw.isNotEmpty ? visitDateRaw : today;

        // ── Step 3: INSERT ────────────────────────────────────────────────
        try {
          final insertRes = await conn.execute(
            "INSERT INTO patients "
            "(name, age, phone, gender, visit_type, priority, department, "
            " notes, nurse, nurse_username, "
            " fee, amount_paid, remaining, credit, "
            " turn, status, date, visit_date, visit_time, client_id) "
            "VALUES "
            "(:name, :age, :phone, :gender, :visit_type, :priority, :department, "
            " :notes, :nurse, :nurse_username, "
            " :fee, :amount_paid, :remaining, :credit, "
            " :turn, :status, :date, :visit_date, :visit_time, :client_id)",
            {
              'name':          name,
              'age':           data['age']?.toString()           ?? '',
              'phone':         data['phone']?.toString()          ?? '',
              'gender':        data['gender']?.toString()         ?? 'ذكر',
              'visit_type':    data['visit_type']?.toString()     ?? 'كشف',
              'priority':      data['priority']?.toString()       ?? 'عادي',
              'department':    data['department']?.toString()     ?? 'استقبال',
              'notes':         data['notes']?.toString()          ?? '',
              'nurse':         data['nurse']?.toString()          ?? 'غير معروف',
              'nurse_username': nurseUsername,
              'fee':           fee,
              'amount_paid':   amountPaid,   // ✅ NEW
              'remaining':     remaining,    // ✅ NEW
              'credit':        credit,       // ✅ NEW
              'turn':          finalTurn,
              'status':        finalStatus,
              'date':          today,
              'visit_date':    visitDate,    // ✅ NEW
              'visit_time':    now,
              'client_id':     clientId.isNotEmpty ? clientId : null,
            },
          );

          await DatabaseService.updateSetting(
            'last_patient_change',
            DateTime.now().toIso8601String(),
          );

          debugPrint('✅ /add INSERT: name=$name turn=$finalTurn '
              'fee=$fee paid=$amountPaid remaining=$remaining credit=$credit '
              'visit_date=$visitDate client_id=$clientId');

          _json(request, {
            'success':     true,
            'id':          _toInt(insertRes.lastInsertID),
            'turn':        finalTurn,
            'name':        name,
            'visit_time':  now,
            'amount_paid': amountPaid, // ✅ NEW
            'remaining':   remaining,  // ✅ NEW
            'credit':      credit,     // ✅ NEW
            'visit_date':  visitDate,  // ✅ NEW
          });
          return;
        } catch (e) {
          final msg = e.toString();
          // ── Step 4: Duplicate race condition → ارجع البيانات الموجودة ──
          if (msg.contains('Duplicate') || msg.contains('duplicate') ||
              msg.contains('unique')    || msg.contains('UNIQUE')) {
            debugPrint('⚠️ Duplicate INSERT for client_id=$clientId — returning existing record');
            if (clientId.isNotEmpty) {
              try {
                final checkRes = await conn.execute(
                  'SELECT id, turn, visit_time, amount_paid, remaining, credit '
                  'FROM patients WHERE client_id = :client_id LIMIT 1',
                  {'client_id': clientId},
                );
                if (checkRes.rows.isNotEmpty) {
                  final row = checkRes.rows.first.assoc();
                  _json(request, {
                    'success':     true,
                    'id':          _toInt(row['id']),
                    'turn':        _toInt(row['turn']),
                    'name':        name,
                    'visit_time':  row['visit_time']?.toString() ?? now,
                    'amount_paid': _toDouble(row['amount_paid']),
                    'remaining':   _toDouble(row['remaining']),
                    'credit':      _toDouble(row['credit']),
                  });
                  return;
                }
              } catch (_) {}
            }
          }
          debugPrint('❌ /add insert failed: $e');
          request.response.statusCode = 500;
          _json(request, {'error': 'Failed to save patient'});
          return;
        }
      }

      // ── notify change ─────────────────────────────────────────────────────
      if (method == 'POST' && path == '/notify-change') {
        await DatabaseService.updateSetting(
          'last_patient_change',
          DateTime.now().toIso8601String(),
        );
        _json(request, {'success': true});
        return;
      }

      // ── patients (today active) ───────────────────────────────────────────
      if (method == 'GET' && path == '/patients') {
        final today = DateTime.now().toString().split(' ')[0];
        final conn  = await DatabaseService.database;
        final res   = await conn.execute(
          'SELECT * FROM patients WHERE date = :date ORDER BY turn ASC',
          {'date': today},
        );
        final patients = res.rows.map((r) => _sanitizeRow(r.assoc())).toList();
        _json(request, patients);
        return;
      }

      // ── patients (all) ────────────────────────────────────────────────────
      if (method == 'GET' && path == '/patients/all') {
        final conn = await DatabaseService.database;
        final res  = await conn.execute(
          'SELECT * FROM patients ORDER BY id DESC',
          {},
        );
        final patients = res.rows.map((r) => _sanitizeRow(r.assoc())).toList();
        _json(request, patients);
        return;
      }

      // ── patients (unique) ─────────────────────────────────────────────────
      if (method == 'GET' && path == '/patients/unique') {
        final conn = await DatabaseService.database;
        final res  = await conn.execute(
          """
          SELECT MAX(name) AS name, phone
          FROM patients
          WHERE name IS NOT NULL AND name != ''
            AND phone IS NOT NULL AND phone != ''
          GROUP BY phone
          UNION
          SELECT name, '' AS phone
          FROM patients
          WHERE (phone IS NULL OR phone = '')
            AND name IS NOT NULL AND name != ''
          GROUP BY name
          ORDER BY name ASC
          """,
          {},
        );
        final patients = res.rows.map((r) {
          final row = r.assoc();
          return {
            'name':  row['name']?.toString()  ?? '',
            'phone': row['phone']?.toString() ?? '',
          };
        }).toList();
        _json(request, patients);
        return;
      }

      // ── patients (search) ─────────────────────────────────────────────────
      if (method == 'GET' && path == '/patients/search') {
        final q = _safeParam(request, 'q');
        if (q.isEmpty) {
          _json(request, []);
          return;
        }
        final conn = await DatabaseService.database;
        final like = '%$q%';
        final res  = await conn.execute(
          """
          SELECT MAX(name) AS name, phone
          FROM patients
          WHERE name IS NOT NULL AND name != ''
            AND phone IS NOT NULL AND phone != ''
            AND (name LIKE :like OR phone LIKE :like2)
          GROUP BY phone
          UNION
          SELECT name, '' AS phone
          FROM patients
          WHERE (phone IS NULL OR phone = '')
            AND name IS NOT NULL AND name != ''
            AND name LIKE :like3
          GROUP BY name
          ORDER BY name ASC
          LIMIT 30
          """,
          {'like': like, 'like2': like, 'like3': like},
        );
        final patients = res.rows.map((r) {
          final row = r.assoc();
          return {
            'name':  row['name']?.toString()  ?? '',
            'phone': row['phone']?.toString() ?? '',
          };
        }).toList();
        _json(request, patients);
        return;
      }

      // ── patients (active) ─────────────────────────────────────────────────
      if (method == 'GET' && path == '/patients/active') {
        final today = DateTime.now().toString().split(' ')[0];
        final conn  = await DatabaseService.database;
        final res   = await conn.execute(
          "SELECT * FROM patients WHERE date = :date "
          "AND status NOT IN (:s1, :s2) ORDER BY turn ASC",
          {'date': today, 's1': 'completed', 's2': 'archived'},
        );
        final patients = res.rows.map((r) => _sanitizeRow(r.assoc())).toList();
        _json(request, patients);
        return;
      }

      // ── patient visits ✅ UPDATED — بيرجع amount_paid ────────────────────
      if (method == 'GET' && path == '/patient-visits') {
        final name  = _safeParam(request, 'name');
        final phone = _safeParam(request, 'phone');

        debugPrint('🔍 patient-visits: name="$name" phone="$phone"');

        List<Map<String, String?>> visits = [];
        if (phone.isNotEmpty) {
          visits = await DatabaseService.getAllVisits(name, phone);
        }
        if (visits.isEmpty && name.isNotEmpty) {
          visits = await DatabaseService.getAllVisits(name, null);
        }

        debugPrint('✅ patient-visits found: ${visits.length} records');
        _json(request, visits);
        return;
      }

      // ── daily financial stats ✅ NEW ──────────────────────────────────────
      if (method == 'GET' && path == '/financial-stats') {
        final params = request.uri.queryParameters;
        final today  = DateTime.now().toString().split(' ')[0];
        final date   = params['date'] ?? today;

        final stats  = await DatabaseService.getStatistics(date);
        _json(request, stats);
        return;
      }

      // ── delete patient ────────────────────────────────────────────────────
      if (method == 'POST' && path == '/delete-patient') {
        final data      = await _readJson(request);
        final id        = _toInt(data['id']);
        final phone     = data['phone']?.toString()     ?? '';
        final visitTime = data['time']?.toString()      ?? '';
        final conn      = await DatabaseService.database;
        int affected    = 0;

        if (id > 0) {
          final r = await conn.execute(
            "UPDATE patients SET status = 'archived' WHERE id = :id "
            "AND status NOT IN (:s1, :s2)",
            {'id': id, 's1': 'completed', 's2': 'archived'},
          );
          affected = _toInt(r.affectedRows);
        }

        if (affected == 0 && phone.isNotEmpty && visitTime.isNotEmpty) {
          final r = await conn.execute(
            "UPDATE patients SET status = 'archived' "
            "WHERE phone = :phone AND visit_time = :vt "
            "AND status NOT IN (:s1, :s2)",
            {'phone': phone, 'vt': visitTime, 's1': 'completed', 's2': 'archived'},
          );
          affected = _toInt(r.affectedRows);
        }

        if (affected == 0 && phone.isNotEmpty) {
          final today = DateTime.now().toString().split(' ')[0];
          final r = await conn.execute(
            "UPDATE patients SET status = 'archived' "
            "WHERE phone = :phone AND date = :date "
            "AND status NOT IN (:s1, :s2)",
            {'phone': phone, 'date': today, 's1': 'completed', 's2': 'archived'},
          );
          affected = _toInt(r.affectedRows);
        }

        if (affected > 0) {
          await _reorderPatientTurns();
          await DatabaseService.updateSetting(
            'last_patient_change',
            DateTime.now().toIso8601String(),
          );
        }

        _json(request, {'success': true, 'deleted': affected});
        return;
      }

      // ── update patient ────────────────────────────────────────────────────
      if (method == 'POST' && path == '/update-patient') {
        final data          = await _readJson(request);
        final originalPhone = (data['original_phone'] ?? '').toString().trim();
        final originalName  = (data['original_name']  ?? '').toString().trim();
        final newName       = (data['name']            ?? '').toString().trim();
        final newPhone      = (data['phone']           ?? '').toString().trim();
        final newAge        = (data['age']             ?? '').toString().trim();
        final newGender     = (data['gender']          ?? 'ذكر').toString().trim();

        if (newName.isEmpty) {
          request.response.statusCode = 400;
          _json(request, {'error': 'الاسم الجديد مطلوب'});
          return;
        }

        final conn    = await DatabaseService.database;
        int   updated = 0;

        if (originalPhone.isNotEmpty) {
          final r = await conn.execute(
            "UPDATE patients SET name=:name, phone=:phone, age=:age, gender=:gender "
            "WHERE phone=:oPhone AND phone IS NOT NULL AND phone!=''",
            {'name': newName, 'phone': newPhone, 'age': newAge, 'gender': newGender, 'oPhone': originalPhone},
          );
          updated = _toInt(r.affectedRows);
        }
        if (updated == 0 && originalName.isNotEmpty) {
          final r = await conn.execute(
            "UPDATE patients SET name=:name, phone=:phone, age=:age, gender=:gender "
            "WHERE name=:oName",
            {'name': newName, 'phone': newPhone, 'age': newAge, 'gender': newGender, 'oName': originalName},
          );
          updated = _toInt(r.affectedRows);
        }
        _json(request, {'success': true, 'updated': updated});
        return;
      }

      // ── update payment ✅ NEW ────────────────────────────────────────────
      if (method == 'POST' && path == '/update-payment') {
        final data   = await _readJson(request);
        final id     = _toInt(data['id']);
        if (id <= 0) {
          request.response.statusCode = 400;
          _json(request, {'error': 'id مطلوب'});
          return;
        }

        final double fee        = _toDouble(data['fee']);
        final double amountPaid = _toDouble(data['amount_paid']);
        final diff      = amountPaid - fee;
        final remaining = diff < 0 ? diff.abs() : 0.0;
        final credit    = diff > 0 ? diff       : 0.0;

        final conn = await DatabaseService.database;
        await conn.execute(
          "UPDATE patients SET "
          "fee=:fee, amount_paid=:paid, remaining=:remaining, credit=:credit "
          "WHERE id=:id",
          {
            'fee': fee, 'paid': amountPaid,
            'remaining': remaining, 'credit': credit,
            'id': id,
          },
        );

        _json(request, {
          'success':   true,
          'fee':       fee,
          'paid':      amountPaid,
          'remaining': remaining,
          'credit':    credit,
        });
        return;
      }

      // ── import visit ──────────────────────────────────────────────────────
      if (method == 'POST' && path == '/import-visit') {
        final data = await _readJson(request);
        final name = (data['name'] ?? '').toString().trim();

        if (name.isEmpty) {
          request.response.statusCode = 400;
          _json(request, {'error': 'اسم المريض مطلوب'});
          return;
        }

        final date = (data['date'] ?? '').toString().trim().isNotEmpty
            ? data['date'].toString().trim()
            : DateTime.now().toString().split(' ')[0];

        final double fee        = _toDouble(data['fee']);
        final double amountPaid = _toDouble(data['amount_paid'] ?? data['fee']);
        final diff      = amountPaid - fee;
        final remaining = _toDouble(data['remaining'] ?? (diff < 0 ? diff.abs() : 0.0));
        final credit    = _toDouble(data['credit']    ?? (diff > 0 ? diff       : 0.0));

        final conn = await DatabaseService.database;

        final oldRes = await conn.execute(
          "SELECT COUNT(*) as c FROM patients WHERE import_source = :src",
          {'src': 'nurse_manual'},
        );
        final importTurn = 9000 + _toInt(oldRes.rows.first.assoc()['c']) + 1;

        await conn.execute(
          "INSERT INTO patients "
          "(name, phone, age, gender, visit_type, priority, department, notes, "
          " nurse, nurse_username, fee, amount_paid, remaining, credit, "
          " turn, status, date, visit_date, diagnosis, treatment, visit_time, import_source) "
          "VALUES "
          "(:name, :phone, :age, :gender, :visit_type, :priority, :department, :notes, "
          " :nurse, :nurse_username, :fee, :amount_paid, :remaining, :credit, "
          " :turn, 'completed', :date, :visit_date, :diagnosis, :treatment, :visit_time, 'nurse_manual')",
          {
            'name':          name,
            'phone':         (data['phone']       ?? '').toString().trim(),
            'age':           (data['age']         ?? '').toString().trim(),
            'gender':        (data['gender']      ?? 'ذكر').toString().trim(),
            'visit_type':    (data['visit_type']  ?? 'كشف').toString().trim(),
            'priority':      (data['priority']    ?? 'عادي').toString().trim(),
            'department':    (data['department']  ?? 'استقبال').toString().trim(),
            'notes':         (data['notes']       ?? '').toString().trim(),
            'nurse':         (data['nurse']       ?? 'مستورد').toString().trim(),
            'nurse_username':(data['nurse_username'] ?? '').toString().trim(),
            'fee':           fee,
            'amount_paid':   amountPaid,   // ✅ NEW
            'remaining':     remaining,    // ✅ NEW
            'credit':        credit,       // ✅ NEW
            'turn':          importTurn,
            'date':          date,
            'visit_date':    date,         // ✅ NEW
            'diagnosis':     (data['diagnosis']  ?? '').toString().trim(),
            'treatment':     (data['treatment']  ?? '').toString().trim(),
            'visit_time':    DateTime.now().toIso8601String(),
          },
        );

        request.response.statusCode = 201;
        _json(request, {'success': true, 'message': 'تم إضافة الكشف القديم بنجاح'});
        return;
      }

      // ── update visit ──────────────────────────────────────────────────────
      if (method == 'POST' && path == '/update-visit') {
        final data = await _readJson(request);
        final id   = data['id'];

        if (id == null) {
          request.response.statusCode = 400;
          _json(request, {'error': 'id مطلوب'});
          return;
        }

        final updateParts = <String>[];
        final params      = <String, dynamic>{};

        if (data.containsKey('date') &&
            (data['date'] ?? '').toString().trim().isNotEmpty) {
          updateParts.add('date = :date');
          params['date'] = data['date'].toString().trim();
        }
        if (data.containsKey('diagnosis')) {
          updateParts.add('diagnosis = :diagnosis');
          params['diagnosis'] = (data['diagnosis'] ?? '').toString().trim();
        }
        if (data.containsKey('treatment')) {
          updateParts.add('treatment = :treatment');
          params['treatment'] = (data['treatment'] ?? '').toString().trim();
        }
        if (data.containsKey('notes')) {
          updateParts.add('notes = :notes');
          params['notes'] = (data['notes'] ?? '').toString().trim();
        }

        if (updateParts.isEmpty) {
          request.response.statusCode = 400;
          _json(request, {'error': 'لا توجد بيانات للتحديث'});
          return;
        }

        params['id']  = id;
        params['src'] = 'nurse_manual';
        final conn    = await DatabaseService.database;
        final r       = await conn.execute(
          "UPDATE patients SET ${updateParts.join(', ')} "
          "WHERE id = :id AND import_source = :src",
          params,
        );

        if (_toInt(r.affectedRows) == 0) {
          request.response.statusCode = 403;
          _json(request, {'error': 'لا يمكن تعديل هذا الكشف'});
          return;
        }

        _json(request, {'success': true, 'updated': _toInt(r.affectedRows)});
        return;
      }

      request.response.statusCode = 404;
      await request.response.close();
    } catch (e) {
      debugPrint('❌ Request error: $e');
      try {
        request.response.statusCode = 500;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REORDER TURNS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _reorderPatientTurns() async {
    try {
      final today = DateTime.now().toString().split(' ')[0];
      final conn  = await DatabaseService.database;
      final res   = await conn.execute(
        "SELECT id FROM patients WHERE date = :date "
        "AND status IN ('waiting', 'in_progress') ORDER BY turn ASC",
        {'date': today},
      );
      int i = 1;
      for (final row in res.rows) {
        final id = row.assoc()['id'];
        await conn.execute(
          'UPDATE patients SET turn = :turn WHERE id = :id',
          {'turn': i, 'id': id},
        );
        i++;
      }
      debugPrint('✅ Turns reordered: ${res.rows.length} patients');
    } catch (e) {
      debugPrint('❌ Reorder error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  void _json(HttpRequest request, dynamic data) {
    request.response.statusCode =
        request.response.statusCode == 200 ? 200 : request.response.statusCode;
    request.response.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  // ✅ UPDATED — _sanitizeRow يشمل الحقول الجديدة
  static Map<String, dynamic> _sanitizeRow(Map<String, dynamic> row) {
    return {
      ...row,
      'id':            _toInt(row['id']),
      'turn':          _toInt(row['turn']),
      'fee':           _toDouble(row['fee']),
      'amount_paid':   _toDouble(row['amount_paid']),   // ✅ NEW
      'remaining':     _toDouble(row['remaining']),      // ✅ NEW
      'credit':        _toDouble(row['credit']),         // ✅ NEW
      'age':           row['age']?.toString(),
      'date':          row['date']?.toString(),
      'visit_date':    row['visit_date']?.toString(),    // ✅ NEW
      'visit_time':    row['visit_time']?.toString(),
      'created_at':    row['created_at']?.toString(),
      'nurse_username':row['nurse_username']?.toString() ?? '',
      'client_id':     row['client_id']?.toString(),     // ✅ NEW
    };
  }
}