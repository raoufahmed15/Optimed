import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:xml/xml.dart';

import 'package:doctor_system/core/database.dart';
import 'package:doctor_system/core/language_provider.dart';
import 'package:doctor_system/core/app_localizations.dart';

const Color kOptiBlue = Color(0xFF0070BB);

const Map<String, String> kTargetFieldsAr = {
  'name':       'اسم المريض ✱',
  'phone':      'رقم الهاتف',
  'age':        'السن',
  'gender':     'الجنس',
  'visit_type': 'نوع الزيارة / الكشف',
  'priority':   'الأولوية',
  'department': 'القسم',
  'nurse':      'الممرضة',
  'fee':        'الرسوم / السعر',
  'date':       'تاريخ الزيارة',
  'visit_time': 'وقت الزيارة',
  'diagnosis':  'التشخيص',
  'treatment':  'العلاج / الروشتة',
  'notes':      'ملاحظات',
  'status':     'حالة السجل',
  'ignore':     '— تجاهل هذا العمود —',
};

const Map<String, String> kTargetFieldsEn = {
  'name':       'Patient Name ✱',
  'phone':      'Phone Number',
  'age':        'Age',
  'gender':     'Gender',
  'visit_type': 'Visit Type',
  'priority':   'Priority',
  'department': 'Department',
  'nurse':      'Nurse',
  'fee':        'Fee / Price',
  'date':       'Visit Date',
  'visit_time': 'Visit Time',
  'diagnosis':  'Diagnosis',
  'treatment':  'Treatment / Prescription',
  'notes':      'Notes',
  'status':     'Record Status',
  'ignore':     '— Ignore this column —',
};

Map<String, String> targetFields(AppLocalizations l) =>
    l.isArabic ? kTargetFieldsAr : kTargetFieldsEn;

// ══════════════════════════════════════════════════════════════════════════════
//  AutoMapper
// ══════════════════════════════════════════════════════════════════════════════
class AutoMapper {
  static const Map<String, List<String>> _aliases = {
    'name': ['name','اسم','الاسم','patient_name','full_name','fullname','client_name','customer','عميل','مريض','patient','اسم المريض','الاسم الكامل','الاسم بالكامل','patient full name','patientname','اسم_المريض','client','member','person'],
    'phone': ['phone','تليفون','هاتف','موبايل','mobile','telephone','tel','phone_number','phonenumber','contact','رقم الهاتف','رقم الموبايل','رقم التليفون','cell','cellphone','رقم موبايل','رقم الجوال','رقم_الهاتف','رقم_التليفون','mobile_number','phone_no','contact_number','tel_number'],
    'age': ['age','السن','العمر','patient_age','years','سنة','عمر','سن','age_years','عمر_المريض','سن_المريض'],
    'gender': ['gender','الجنس','sex','جنس','gender_type','patient_gender','جنس_المريض','النوع'],
    'visit_type': ['visit_type','نوع الزيارة','نوع الكشف','نوع_الكشف','نوع_الزيارة','visittype','visit','زيارة','service','خدمة','نوع الخدمة','نوع_الخدمة','appointment_type','type_of_visit','consultation_type','نوع_الاستشارة','نوع الاستشارة'],
    'priority': ['priority','الأولوية','أولوية','urgency','أولوية المريض','أولوية_المريض','priority_level','triage'],
    'department': ['department','القسم','قسم','dept','specialty','تخصص','التخصص','section','unit','clinic','عيادة','العيادة','specialization','التخصص_الطبي'],
    'notes': ['notes','ملاحظات','note','comments','comment','remarks','تعليقات','شكوى','complaint','ملاحظة','additional_notes','extra_notes','شكاوى','الشكوى','chief_complaint','ملاحظات_إضافية','ملاحظات_اضافية'],
    'nurse': ['nurse','ممرضة','الممرضة','nursename','nurse_name','staff','موظف','اسم الممرضة','attending_nurse','nurse_id','الممرض','ممرض'],
    'fee': ['fee','سعر','رسوم','price','cost','amount','مبلغ','تكلفة','الرسوم','السعر','payment','سعر الكشف','رسوم الكشف','total','total_fee','charge','consultation_fee','visit_fee','الأجرة','الاجرة','تكلفة_الكشف','المبلغ'],
    'date': ['date','تاريخ','visit_date','visitdate','appointment_date','تاريخ الزيارة','تاريخ_الزيارة','يوم','التاريخ','تاريخ_الكشف','تاريخ الكشف','appt_date','consultation_date','تاريخ_الاستشارة','encounter_date','service_date'],
    'visit_time': ['visit_time','وقت','time','visittime','appointment_time','وقت الزيارة','وقت_الزيارة','الوقت','appt_time','وقت_الكشف','وقت الكشف'],
    'diagnosis': ['diagnosis','تشخيص','diagnose','التشخيص','medical_diagnosis','تشخيص المرض','diagnosis_text','disease','condition','الحالة_المرضية','المرض','impression'],
    'treatment': ['treatment','علاج','العلاج','prescription','روشتة','remedy','الروشتة','الدواء','medications','drugs','medicine','treatment_plan','therapy','خطة_العلاج','الأدوية','الوصفة_الطبية','وصفة'],
    'status': ['status','الحالة','حالة','state','patient_status','visit_status','record_status','حالة_المريض','حالة_الزيارة'],
  };

  static String _norm(String s) {
    var v = s.trim();
    const sq = '\u2018\u2019\u201c\u201d\uFEFF"\'';
    while (v.isNotEmpty && sq.contains(v[0])) v = v.substring(1);
    while (v.isNotEmpty && sq.contains(v[v.length - 1])) v = v.substring(0, v.length - 1);
    return v.toLowerCase().trim().replaceAll(RegExp(r'[\s\-_\.]+'), '_');
  }

  static String? suggest(String rawColumn) {
    final norm = _norm(rawColumn);
    if (norm.isEmpty) return 'ignore';
    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        if (norm == _norm(alias)) return entry.key;
      }
    }
    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        final na = _norm(alias);
        if (na.length >= 4 && norm.startsWith(na)) return entry.key;
        if (na.length >= 4 && na.startsWith(norm) && norm.length >= 4) return entry.key;
      }
    }
    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        final na = _norm(alias);
        if (na.length >= 5 && norm.contains(na)) return entry.key;
        if (na.length >= 5 && na.contains(norm) && norm.length >= 5) return entry.key;
      }
    }
    return null;
  }

  static ImportedPatient applyMapping(Map<String, dynamic> row, Map<String, String> mapping) {
    final mapped = <String, dynamic>{};
    for (final col in row.keys) {
      final target = mapping[col];
      if (target == null || target == 'ignore') continue;
      final val = row[col]?.toString().trim() ?? '';
      if (val.isEmpty) continue;
      if (!mapped.containsKey(target)) mapped[target] = val;
    }
    return ImportedPatient(
      name: mapped['name'] ?? '', phone: mapped['phone'] ?? '',
      age: mapped['age'] ?? '', gender: mapped['gender'] ?? '',
      visitType: mapped['visit_type'] ?? '', priority: mapped['priority'] ?? '',
      department: mapped['department'] ?? '', notes: mapped['notes'] ?? '',
      nurse: mapped['nurse'] ?? '', fee: mapped['fee'] ?? '',
      date: mapped['date'] ?? '', visitTime: mapped['visit_time'] ?? '',
      diagnosis: mapped['diagnosis'] ?? '', treatment: mapped['treatment'] ?? '',
      status: mapped['status'] ?? '',
    );
  }
}

class _Sanitizer {
  static Map<String, dynamic> sanitize(Map<String, dynamic> raw) {
    return {
      'name':       _text(raw['name'], fallback: 'مجهول'),
      'status':     _status(raw['status']),
      'date':       _date(raw['date']),
      'age':        _age(raw['age']),
      'phone':      _phone(raw['phone']),
      'gender':     _gender(raw['gender']),
      'visit_type': _visitType(raw['visit_type']),
      'priority':   _priority(raw['priority']),
      'department': _text(raw['department'], fallback: 'استقبال'),
      'notes':      _text(raw['notes']),
      'nurse':      _text(raw['nurse'], fallback: 'مستورد'),
      'fee':        _fee(raw['fee']),
      'visit_time': _time(raw['visit_time']),
      'diagnosis':  _text(raw['diagnosis']),
      'treatment':  _text(raw['treatment']),
    };
  }

  static String _status(dynamic v) {
    final s = v?.toString().toLowerCase().trim() ?? '';
    if (['completed','done','finished','archived','منتهي','مكتمل','تم'].any((x) => s.contains(x))) return 'completed';
    if (['waiting','pending','new','انتظار','جديد'].any((x) => s.contains(x))) return 'waiting';
    if (['in_progress','active','جاري'].any((x) => s.contains(x))) return 'in_progress';
    return 'completed';
  }

  static String _date(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.isEmpty) return '';
    try {
      if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}').hasMatch(s)) {
        final parts = s.split('-');
        final y = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final d = int.tryParse(parts[2].split(' ')[0]) ?? 0;
        if (y >= 1900 && m >= 1 && m <= 12 && d >= 1 && d <= 31)
          return '$y-${m.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}';
      }
      final isoSlash = RegExp(r'^(\d{4})[/](\d{1,2})[/](\d{1,2})$').firstMatch(s);
      if (isoSlash != null) {
        final y = int.parse(isoSlash.group(1)!);
        final m = int.parse(isoSlash.group(2)!);
        final d = int.parse(isoSlash.group(3)!);
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31)
          return '$y-${m.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}';
      }
      final parts3 = RegExp(r'^(\d{1,4})[/\-\.](\d{1,2})[/\-\.](\d{1,4})$').firstMatch(s);
      if (parts3 != null) {
        final a = int.parse(parts3.group(1)!);
        final b = int.parse(parts3.group(2)!);
        final c = int.parse(parts3.group(3)!);
        int year, month, day;
        if (a >= 1900) { year = a; month = b; day = c; }
        else if (c >= 1900) {
          if (b > 12) { month = a; day = b; year = c; }
          else if (a > 12) { day = a; month = b; year = c; }
          else { day = a; month = b; year = c; }
        } else {
          final dt = DateTime.tryParse(s);
          if (dt != null) return dt.toString().split(' ')[0];
          return '';
        }
        if (year >= 1900 && month >= 1 && month <= 12 && day >= 1 && day <= 31)
          return '$year-${month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
      }
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt.toString().split(' ')[0];
    } catch (_) {}
    return '';
  }

  static String _time(dynamic v) {
    if (v == null) return '';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(v.toString());
    if (match != null) return '${match.group(1)!.padLeft(2,'0')}:${match.group(2)}';
    return '';
  }

  static String _age(dynamic v) {
    if (v == null) return '';
    final digits = RegExp(r'\d+').firstMatch(v.toString())?.group(0) ?? '';
    if (digits.isEmpty) return '';
    final age = int.tryParse(digits) ?? 0;
    if (age <= 0 || age > 150) return '';
    return age.toString();
  }

  static String _phone(dynamic v) {
    if (v == null) return '';
    var s = v.toString().replaceAll(RegExp(r'[^\d+\-]'), '').trim();
    s = s.replaceAll(RegExp(r'^00'), '0').replaceAll(' ', '');
    return s.length >= 7 ? s : '';
  }

  static String _gender(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty) return 'غير محدد';
    final lower = s.toLowerCase();
    if (lower.contains('ذكر') || lower == 'male' || lower == 'm' || lower == 'رجل' || lower == 'ولد') return 'ذكر';
    if (lower.contains('أنثى') || lower.contains('انثى') || lower == 'female' || lower == 'f' || lower == 'ست' || lower == 'بنت') return 'أنثى';
    return 'غير محدد';
  }

  static String _visitType(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty) return 'كشف';
    final lower = s.toLowerCase();
    if (lower.contains('إعادة') || lower.contains('اعادة') || lower.contains('متابعة') || lower.contains('follow')) return 'إعادة';
    if (lower.contains('طوارئ') || lower.contains('emergency')) return 'طوارئ';
    if (lower.contains('استشارة') || lower.contains('consultation')) return 'استشارة';
    return s.isNotEmpty ? s : 'كشف';
  }

  static String _priority(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty) return 'عادي';
    final lower = s.toLowerCase();
    if (lower.contains('حرج') || lower.contains('critical') || lower.contains('urgent') || lower == 'high') return 'حرج';
    if (lower.contains('عاجل') || lower.contains('important') || lower == 'medium') return 'عاجل';
    return 'عادي';
  }

  static double _fee(dynamic v) {
    if (v == null) return 0.0;
    try { return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0; } catch (_) { return 0.0; }
  }

  static String _text(dynamic v, {String fallback = ''}) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }
}

class ImportedPatient {
  final String name, phone, age, gender, visitType, priority;
  final String department, notes, nurse, date, visitTime;
  final String diagnosis, treatment, status, fee;

  const ImportedPatient({
    required this.name, this.phone = '', this.age = '', this.gender = '',
    this.visitType = '', this.priority = '', this.department = '',
    this.notes = '', this.nurse = '', this.fee = '', this.date = '',
    this.visitTime = '', this.diagnosis = '', this.treatment = '', this.status = '',
  });

  bool get hasName => name.trim().isNotEmpty;

  Map<String, dynamic> toRawMap() => {
    'name': name, 'phone': phone, 'age': age, 'gender': gender,
    'visit_type': visitType, 'priority': priority, 'department': department,
    'notes': notes, 'nurse': nurse, 'fee': fee, 'date': date,
    'visit_time': visitTime, 'diagnosis': diagnosis, 'treatment': treatment, 'status': status,
  };

  Map<String, dynamic> toPreviewMap() => _Sanitizer.sanitize(toRawMap());
}

class FileParser {
  static Future<List<Map<String, dynamic>>> parse(String filePath, String extension) async {
    switch (extension.toLowerCase()) {
      case 'csv': case 'txt': return _parseCsv(filePath);
      case 'json': return _parseJson(filePath);
      case 'xlsx': case 'xls': return _parseExcel(filePath);
      case 'xml': return _parseXml(filePath);
      case 'vcf': return _parseVcard(filePath);
      default: throw UnsupportedError('Unsupported format: .$extension');
    }
  }

  static Future<List<Map<String, dynamic>>> _parseCsv(String path) async {
    String content = '';
    for (final enc in [utf8, latin1]) {
      try { content = await File(path).readAsString(encoding: enc); break; } catch (_) {}
    }
    if (content.isEmpty) return [];
    content = content.replaceAll('\uFEFF', '');
    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final delim = _detectDelimiter(lines.first);
    final headers = _splitLine(lines.first, delim);
    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < lines.length; i++) {
      final vals = _splitLine(lines[i], delim);
      final row = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        if (headers[j].isEmpty) continue;
        row[headers[j]] = j < vals.length ? vals[j] : '';
      }
      if (row.values.any((v) => v.toString().isNotEmpty)) rows.add(row);
    }
    return rows;
  }

  static String _detectDelimiter(String line) {
    final counts = {'\t': '\t'.allMatches(line).length, ';': ';'.allMatches(line).length, ',': ','.allMatches(line).length, '|': '|'.allMatches(line).length};
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _stripQuotes(String s) {
    var v = s.trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.substring(1, v.length - 1).trim();
    const sq = '\u2018\u2019\u201c\u201d\uFEFF';
    while (v.isNotEmpty && sq.contains(v[0])) v = v.substring(1);
    while (v.isNotEmpty && sq.contains(v[v.length - 1])) v = v.substring(0, v.length - 1);
    return v.trim();
  }

  static List<String> _splitLine(String line, String delim) {
    final result = <String>[];
    bool inQ = false;
    final buf = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') { inQ = !inQ; }
      else if (c == delim && !inQ) { result.add(_stripQuotes(buf.toString())); buf.clear(); }
      else { buf.write(c); }
    }
    result.add(_stripQuotes(buf.toString()));
    return result;
  }

  static Future<List<Map<String, dynamic>>> _parseJson(String path) async {
    dynamic decoded;
    try { decoded = jsonDecode(await File(path).readAsString()); }
    catch (e) { throw FormatException('Invalid JSON: $e'); }
    if (decoded is List) return decoded.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{'raw': e.toString()}).toList();
    if (decoded is Map) {
      for (final key in ['patients','data','records','items','clients','users','visits','appointments','list','results']) {
        if (decoded[key] is List) return (decoded[key] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      for (final val in decoded.values) {
        if (val is List && val.isNotEmpty && val.first is Map) return (val as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [Map<String, dynamic>.from(decoded)];
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> _parseExcel(String path) async {
    final excel = Excel.decodeBytes(await File(path).readAsBytes());
    List<Map<String, dynamic>> bestResult = [];
    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      if (sheet.rows.length < 2) continue;
      int headerRow = 0;
      for (int i = 0; i < sheet.rows.length && i < 10; i++) {
        if (sheet.rows[i].any((c) => c?.value != null)) { headerRow = i; break; }
      }
      final headers = sheet.rows[headerRow].map((c) => c?.value?.toString().trim() ?? '').toList();
      final rows = <Map<String, dynamic>>[];
      for (int i = headerRow + 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final map = <String, dynamic>{};
        bool hasData = false;
        for (int j = 0; j < headers.length; j++) {
          if (headers[j].isEmpty) continue;
          final v = j < row.length ? row[j]?.value?.toString() ?? '' : '';
          map[headers[j]] = v;
          if (v.isNotEmpty) hasData = true;
        }
        if (hasData) rows.add(map);
      }
      if (rows.length > bestResult.length) bestResult = rows;
    }
    return bestResult;
  }

  static Future<List<Map<String, dynamic>>> _parseXml(String path) async {
    final root = XmlDocument.parse(await File(path).readAsString()).rootElement;
    final rows = <Map<String, dynamic>>[];
    for (final child in root.descendants.whereType<XmlElement>()) {
      final children = child.children.whereType<XmlElement>().toList();
      if (children.isEmpty) continue;
      final map = <String, dynamic>{};
      for (final a in child.attributes) map[a.name.local] = a.value;
      for (final s in children) map[s.name.local] = s.innerText;
      if (map.isNotEmpty) rows.add(map);
    }
    return rows;
  }

  static Future<List<Map<String, dynamic>>> _parseVcard(String path) async {
    String content = '';
    try { content = await File(path).readAsString(); }
    catch (_) { content = await File(path).readAsString(encoding: latin1); }
    final cards = content.split('END:VCARD');
    final rows = <Map<String, dynamic>>[];
    for (final card in cards) {
      if (!card.contains('BEGIN:VCARD')) continue;
      final map = <String, dynamic>{};
      for (final line in card.split('\n')) {
        final t = line.trim();
        if (t.startsWith('FN:')) { map['name'] = t.substring(3); }
        else if (t.startsWith('N:') && !map.containsKey('name')) {
          final parts = t.substring(2).split(';');
          final nm = [parts.first, parts.length > 1 ? parts[1] : ''].where((p) => p.isNotEmpty).join(' ').trim();
          if (nm.isNotEmpty) map['name'] = nm;
        } else if (t.startsWith('TEL')) { map['phone'] = t.contains(':') ? t.split(':').last.trim() : ''; }
        else if (t.startsWith('NOTE:')) { map['notes'] = t.substring(5); }
        else if (t.startsWith('BDAY:')) { map['date'] = t.substring(5); }
      }
      if ((map['name'] ?? '').toString().isNotEmpty) rows.add(map);
    }
    return rows;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ImportMigrationScreen
// ══════════════════════════════════════════════════════════════════════════════
class ImportMigrationScreen extends StatefulWidget {
  const ImportMigrationScreen({super.key});
  @override
  State<ImportMigrationScreen> createState() => _ImportMigrationScreenState();
}

class _ImportMigrationScreenState extends State<ImportMigrationScreen> {
  _ImportStep _step = _ImportStep.pick;
  String? _filePath, _fileName, _fileExtension;
  List<Map<String, dynamic>> _rawRows = [];
  List<String> _fileColumns = [];
  Map<String, String> _userMapping = {};
  List<ImportedPatient> _parsedPatients = [];
  bool _skipDuplicates = true;
  bool _importHistorical = true;
  bool _isLoading = false;
  bool _showSanitized = true;
  String _statusMessage = '';
  int _importedCount = 0, _skippedCount = 0, _errorCount = 0;
  List<String> _errorLog = [];

  AppLocalizations get l => LanguageProvider.of(context).l;

  List<String> get _stepLabels => [
    l.pickFileStep,
    l.mapColumnsStep,
    l.reviewStep,
    l.doneStep,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LanguageProvider.of(context).addListener(_onLangChanged);
    });
  }

  @override
  void dispose() {
    LanguageProvider.of(context).removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv','json','xlsx','xls','xml','vcf','txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() {
        _filePath = file.path;
        _fileName = file.name;
        _fileExtension = file.extension ?? '';
        _isLoading = true;
        _statusMessage = l.readingFile;
      });
      _rawRows = await FileParser.parse(_filePath!, _fileExtension!);
      if (_rawRows.isEmpty) { _showError(l.emptyFile); return; }
      final allCols = <String>{};
      for (final row in _rawRows.take(20)) allCols.addAll(row.keys.where((k) => k.isNotEmpty));
      _fileColumns = allCols.toList();
      _userMapping = {};
      for (final col in _fileColumns) _userMapping[col] = AutoMapper.suggest(col) ?? 'ignore';
      setState(() { _isLoading = false; _step = _ImportStep.mapping; });
    } catch (e) { _showError(l.fileReadError(e.toString())); }
  }

  void _confirmMapping() {
    if (!_userMapping.values.contains('name')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.nameColumnRequired),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    _parsedPatients = _rawRows
        .map((row) => AutoMapper.applyMapping(row, _userMapping))
        .where((p) => p.hasName)
        .toList();
    if (_parsedPatients.isEmpty) { _showError(l.noValidRecords); return; }
    setState(() => _step = _ImportStep.preview);
  }

  Future<void> _startImport() async {
    setState(() {
      _isLoading     = true;
      _step          = _ImportStep.importing;
      _statusMessage = l.importingLabel;
    });
    try {
      final sanitizedList = _parsedPatients.map((p) => p.toPreviewMap()).toList();
      final result = await DatabaseService.batchImportPatients(sanitizedList);
      _importedCount = result['imported'] as int? ?? 0;
      _skippedCount  = result['skipped']  as int? ?? 0;
      _errorCount    = result['errors']   as int? ?? 0;
      _errorLog      = List<String>.from(result['errorLog'] as List? ?? []);
      if (mounted) setState(() { _isLoading = false; _step = _ImportStep.done; });
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _statusMessage = '${l.importError} $e'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.importError} $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _reset() => setState(() {
    _step = _ImportStep.pick; _filePath = _fileName = _fileExtension = null;
    _rawRows = []; _fileColumns = []; _userMapping = {}; _parsedPatients = [];
    _statusMessage = ''; _importedCount = _skippedCount = _errorCount = 0;
    _errorLog = [];
  });

  void _showError(String msg) {
    if (!mounted) return;
    setState(() { _isLoading = false; _statusMessage = msg; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Language Toggle Button ─────────────────────────────────────────────────
  Widget _buildLangToggle() {
    final langState = LanguageProvider.of(context);
    final isAr = langState.l.isArabic;
    return Tooltip(
      message: langState.l.switchLanguageTooltip,
      child: GestureDetector(
        onTap: () => langState.toggle(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: !isAr ? Colors.white : Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: !isAr ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Roboto',
                ),
                child: const Text('E'),
              ),
              const SizedBox(width: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isAr ? Colors.white : Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: isAr ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Roboto',
                ),
                child: const Text('A'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kOptiBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        toolbarHeight: 80,
        title: Text(
          l.importTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          _buildLangToggle(),
          if (_step != _ImportStep.pick && _step != _ImportStep.importing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: l.startOver,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepBar(),
            Expanded(child: _isLoading ? _buildLoading() : _buildStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBar() {
    int barIndex = _step == _ImportStep.pick
        ? 0
        : _step == _ImportStep.mapping
            ? 1
            : (_step == _ImportStep.preview || _step == _ImportStep.importing)
                ? 2
                : 3;
    final labels = _stepLabels;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) return Expanded(child: Container(height: 2, color: i ~/ 2 < barIndex ? kOptiBlue : Colors.grey.shade200));
          final idx = i ~/ 2;
          final isActive = idx == barIndex;
          final isDone = idx < barIndex;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? Colors.green : isActive ? kOptiBlue : Colors.grey.shade200,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text('${idx + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 3),
            Text(labels[idx], style: TextStyle(fontSize: 9, color: isActive ? kOptiBlue : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          ]);
        }),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _ImportStep.pick:      return _buildPickStep();
      case _ImportStep.mapping:   return _buildMappingStep();
      case _ImportStep.preview:   return _buildPreviewStep();
      case _ImportStep.importing: return _buildLoading();
      case _ImportStep.done:      return _buildDoneStep();
    }
  }

  // ── Step 1: Pick File ──────────────────────────────────────────────────────
  Widget _buildPickStep() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kOptiBlue, Color(0xFF005A9B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(l.transferTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l.transferSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 16),

      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
        child: Row(children: [
          Icon(Icons.auto_fix_high, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(l.autoFormatsNote, style: TextStyle(color: Colors.green.shade700, fontSize: 12))),
        ])),
      const SizedBox(height: 20),

      Text(l.supportedFormats, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _fmtChip('CSV', Icons.table_chart, Colors.green),
        _fmtChip('Excel', Icons.grid_on, Colors.blue),
        _fmtChip('JSON', Icons.code, Colors.orange),
        _fmtChip('XML', Icons.code_off, Colors.purple),
        _fmtChip('vCard', Icons.contact_page, Colors.teal),
        _fmtChip('TXT', Icons.text_snippet, Colors.grey),
      ]),
      const SizedBox(height: 20),

      Text(l.howItWorks, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
      const SizedBox(height: 10),
      _step1Item('1', l.importStep1Title, l.importStep1Sub),
      _step1Item('2', l.importStep2Title, l.importStep2Sub),
      _step1Item('3', l.importStep3Title, l.importStep3Sub),
      _step1Item('4', l.importStep4Title, l.importStep4Sub),
      _step1Item('5', l.importStep5Title, l.importStep5Sub),
      const SizedBox(height: 28),

      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: kOptiBlue, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
        icon: const Icon(Icons.upload_file, size: 22),
        label: Text(l.chooseFile, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: _pickFile,
      )),
      const SizedBox(height: 12),
      Center(child: Text(l.localStorageNote, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontStyle: FontStyle.italic))),
    ]));
  }

  // ── Step 2: Map Columns ────────────────────────────────────────────────────
  Widget _buildMappingStep() {
    final ignoredCount = _userMapping.values.where((v) => v == 'ignore').length;
    final mappedCount  = _userMapping.values.where((v) => v != 'ignore').length;
    final autoMapped   = _fileColumns.where((c) => AutoMapper.suggest(c) != null && _userMapping[c] != 'ignore').length;
    final fields       = targetFields(l);

    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.link, color: kOptiBlue, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(
            l.importFileSummary(_fileName ?? '', _fileColumns.length, _rawRows.length),
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            overflow: TextOverflow.ellipsis,
          )),
          _miniTag(l.mappedCount(mappedCount), Colors.green), const SizedBox(width: 4),
          if (autoMapped > 0) ...[_miniTag(l.autoCount(autoMapped), Colors.amber.shade700), const SizedBox(width: 4)],
          if (ignoredCount > 0) _miniTag(l.ignoredCount(ignoredCount), Colors.grey),
        ])),

      Container(color: Colors.blue.shade50, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(l.mappingInfo, style: TextStyle(color: Colors.blue.shade800, fontSize: 12))),
        ])),

      Expanded(child: ListView.separated(
        padding: const EdgeInsets.all(12), itemCount: _fileColumns.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final col      = _fileColumns[i];
          final selected = _userMapping[col] ?? 'ignore';
          final isAuto   = AutoMapper.suggest(col) != null;
          final isMapped = selected != 'ignore';
          final sample   = _rawRows.isNotEmpty ? (_rawRows.first[col]?.toString() ?? '') : '';
          String sanitizedSample = '';
          if (sample.isNotEmpty && isMapped) {
            try {
              final s  = _Sanitizer.sanitize({selected: sample});
              final sv = s[selected]?.toString() ?? '';
              if (sv != sample && sv.isNotEmpty) sanitizedSample = sv;
            } catch (_) {}
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isMapped ? kOptiBlue.withOpacity(0.4) : Colors.grey.shade200, width: isMapped ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(isMapped ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: isMapped ? Colors.green : Colors.grey),
                    const SizedBox(width: 5),
                    Flexible(child: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    if (isAuto && isMapped) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Text(l.autoSuggested, style: TextStyle(fontSize: 9, color: Colors.amber.shade800)),
                      ),
                    ],
                  ]),
                  if (sample.isNotEmpty) Padding(
                    padding: const EdgeInsets.only(top: 2, right: 19),
                    child: Text('${l.sampleLabel} $sample', style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                  ),
                ])),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 16, color: Colors.blueGrey)),
                Expanded(flex: 5, child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: selected, isExpanded: true, isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  items: fields.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: TextStyle(fontSize: 12, color: e.key == 'ignore' ? Colors.grey : Colors.black87)),
                  )).toList(),
                  onChanged: (val) => setState(() => _userMapping[col] = val!),
                ))),
              ]),
              if (sanitizedSample.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 4, right: 19),
                child: Row(children: [
                  Icon(Icons.auto_fix_high, size: 10, color: Colors.green.shade600), const SizedBox(width: 3),
                  Text('${l.afterNorm} $sanitizedSample', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          );
        },
      )),

      Container(color: Colors.white, padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!_userMapping.values.contains('name'))
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
            child: Row(children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(l.nameColumnRequired, style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
            ]),
          ),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kOptiBlue, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.check),
          label: Text(l.confirmMappingBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _confirmMapping,
        )),
      ])),
    ]);
  }

  // ── Step 3: Preview ────────────────────────────────────────────────────────
  Widget _buildPreviewStep() {
    final preview = _parsedPatients.take(5).toList();
    int genderFixed = 0, dateFixed = 0, feeFixed = 0;
    for (final p in _parsedPatients) {
      final s = p.toPreviewMap();
      if (p.gender.isNotEmpty && s['gender'] != p.gender) genderFixed++;
      if (p.date.isNotEmpty && s['date'] != p.date) dateFixed++;
      if (p.fee.isNotEmpty && s['fee'].toString() != p.fee) feeFixed++;
    }
    return Column(children: [
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.insert_drive_file_outlined, color: kOptiBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_fileName ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ]),
            const Divider(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _statBox('${_parsedPatients.length}', l.readyRecords, Icons.people, Colors.blue),
              _statBox('${_userMapping.values.where((v) => v != 'ignore').length}', l.mappedLbl, Icons.link, Colors.green),
              _statBox('${_userMapping.values.where((v) => v == 'ignore').length}', l.ignoredLbl, Icons.block, Colors.grey),
            ]),
          ])),
        const SizedBox(height: 12),

        Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)),
          child: Row(children: [
            Icon(Icons.archive_outlined, color: Colors.blue.shade700, size: 18), const SizedBox(width: 8),
            Expanded(child: Text(l.archiveNote, style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w500))),
          ])),

        if (genderFixed > 0 || dateFixed > 0 || feeFixed > 0)
          Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_fix_high, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 6),
                Text(l.autoNormalized, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
              ]),
              const SizedBox(height: 6),
              if (dateFixed > 0)   Text(l.datesFixed(dateFixed),   style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
              if (genderFixed > 0) Text(l.genderFixed(genderFixed), style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
              if (feeFixed > 0)    Text(l.feeFixed(feeFixed),       style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
            ])),

        Row(children: [
          Text(l.previewFirst5, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _showSanitized = !_showSanitized),
            icon: Icon(_showSanitized ? Icons.visibility : Icons.visibility_off, size: 14),
            label: Text(_showSanitized ? l.afterNormalize : l.originalValues, style: const TextStyle(fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 6),
        ...preview.map((p) => _previewCard(p, sanitized: _showSanitized)),
        const SizedBox(height: 16),

        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(children: [
          SwitchListTile(dense: true, activeColor: kOptiBlue,
            title: Text(l.skipDuplicates, style: const TextStyle(fontSize: 14)),
            subtitle: Text(l.skipDuplicatesSub, style: const TextStyle(fontSize: 11)),
            value: _skipDuplicates, onChanged: (v) => setState(() => _skipDuplicates = v)),
          const Divider(height: 1),
          SwitchListTile(dense: true, activeColor: kOptiBlue,
            title: Text(l.keepOriginalDates, style: const TextStyle(fontSize: 14)),
            subtitle: Text(l.keepOriginalDatesSub, style: const TextStyle(fontSize: 11)),
            value: _importHistorical, onChanged: (v) => setState(() => _importHistorical = v)),
        ])),
        const SizedBox(height: 24),
      ]))),

      Container(color: Colors.white, padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.download_done_rounded, size: 22),
          label: Text(l.startImport(_parsedPatients.length), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: _startImport,
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: TextButton.icon(
          onPressed: () => setState(() => _step = _ImportStep.mapping),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: Text(l.editMapping, style: const TextStyle(color: Colors.blueGrey)),
        )),
      ])),
    ]);
  }

  // ── Step 4: Done ───────────────────────────────────────────────────────────
  Widget _buildDoneStep() {
    final isSuccess = _importedCount > 0;
    return Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: isSuccess ? Colors.green.shade50 : Colors.orange.shade50, shape: BoxShape.circle),
        child: Icon(isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
          color: isSuccess ? Colors.green : Colors.orange, size: 70)),
      const SizedBox(height: 24),
      Text(isSuccess ? l.importDone : l.importDoneWithErrors,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _resultBadge('$_importedCount', l.importedLabel, Colors.green), const SizedBox(width: 16),
        _resultBadge('$_skippedCount', l.skippedLabel, Colors.orange), const SizedBox(width: 16),
        _resultBadge('$_errorCount', l.errorLabel, Colors.red),
      ]),

      if (_errorLog.isNotEmpty) ...[
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(l.errorDetailsTitle, style: const TextStyle(fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite, height: 300,
                child: ListView.builder(
                  itemCount: _errorLog.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('• ${_errorLog[i]}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade200)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red.shade700), const SizedBox(width: 6),
              Text(l.viewErrorDetails, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 24),

      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
        child: Text(l.importDoneNote, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueAccent, fontSize: 13))),
      const SizedBox(height: 32),

      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: kOptiBlue, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.arrow_back),
        label: Text(l.backToDashboard, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(height: 12),
      TextButton(onPressed: _reset, child: Text(l.importAnotherFile, style: const TextStyle(color: Colors.blueGrey))),
    ])));
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const CircularProgressIndicator(color: kOptiBlue), const SizedBox(height: 20),
    Text(_statusMessage.isNotEmpty ? _statusMessage : l.processing, style: const TextStyle(color: Colors.blueGrey)),
    if (_importedCount > 0) ...[
      const SizedBox(height: 10),
      Text(l.importedCount(_importedCount), style: const TextStyle(color: kOptiBlue, fontWeight: FontWeight.bold)),
    ],
  ]));

  // ── Helper Widgets ─────────────────────────────────────────────────────────
  Widget _fmtChip(String label, IconData icon, Color color) => Chip(
    avatar: Icon(icon, size: 14, color: Colors.white),
    label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    backgroundColor: color,
    padding: const EdgeInsets.symmetric(horizontal: 4),
  );

  Widget _step1Item(String n, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 28, height: 28, decoration: const BoxDecoration(color: kOptiBlue, shape: BoxShape.circle),
        child: Center(child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(sub, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ])),
    ]),
  );

  Widget _miniTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );

  Widget _statBox(String value, String label, IconData icon, Color color) => Column(children: [
    Icon(icon, color: color, size: 20), const SizedBox(height: 2),
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);

  Widget _previewCard(ImportedPatient p, {bool sanitized = true}) {
    final data      = sanitized ? p.toPreviewMap() : p.toRawMap();
    final name      = data['name']?.toString()       ?? p.name;
    final phone     = data['phone']?.toString()      ?? '';
    final age       = data['age']?.toString()        ?? '';
    final gender    = data['gender']?.toString()     ?? '';
    final visitType = data['visit_type']?.toString() ?? '';
    final dept      = data['department']?.toString() ?? '';
    final fee       = data['fee'];
    final diagnosis = data['diagnosis']?.toString()  ?? '';
    final date      = data['date']?.toString()       ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person, color: kOptiBlue, size: 16), const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
        ]),
        if (date.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 10))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (age.isNotEmpty)       _tag('${l.ageLabel}: $age'),
          if (gender.isNotEmpty)    _tag(gender),
          if (visitType.isNotEmpty) _tag(visitType),
          if (dept.isNotEmpty)      _tag(dept),
          if (fee != null && fee != 0 && fee.toString() != '0.0')
            _tag('${fee.toString().replaceAll(RegExp(r'\.0+$'), '')} ${l.isArabic ? 'ج' : 'EGP'}'),
          if (diagnosis.isNotEmpty) _tag(diagnosis, Colors.purple),
        ]),
      ]),
    );
  }

  Widget _tag(String text, [Color? color]) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: (color ?? kOptiBlue).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color ?? kOptiBlue, fontWeight: FontWeight.w500)),
  );

  Widget _resultBadge(String value, String label, Color color) => Column(children: [
    Container(
      width: 60, height: 60,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Center(child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20))),
    ),
    const SizedBox(height: 6),
    Text(label, style: TextStyle(color: color, fontSize: 12)),
  ]);
}

enum _ImportStep { pick, mapping, preview, importing, done }