// ✅ استخدم هذا الملف في أي مكان بتحمل بيانات المرضى

class DataHelper {
  /// تحويل آمن للـ int من أي نوع (String, num, int, null)
  static int safeToInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      // إزالة أي مسافات وتحويل
      final trimmed = value.trim();
      return int.tryParse(trimmed) ?? defaultValue;
    }
    return defaultValue;
  }

  /// تحويل آمن للـ double
  static double safeToDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  /// تحويل آمن للـ String
  static String safeToString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  /// تحويل آمن لـ Map من البيانات
  static Map<String, dynamic> sanitizePatientData(
      Map<String, dynamic> patient) {
    return {
      'id': safeToInt(patient['id']),
      'name': safeToString(patient['name']),
      'turn': safeToInt(patient['turn']),
      'age': safeToInt(patient['age']),
      'phone': safeToString(patient['phone']),
      'gender': safeToString(patient['gender']),
      'visit_type': safeToString(patient['visit_type']),
      'status': safeToString(patient['status']),
      'date': safeToString(patient['date']),
      'priority': safeToString(patient['priority']),
      'department': safeToString(patient['department']),
      'nurse': safeToString(patient['nurse']),
      'fee': safeToDouble(patient['fee']),
      'diagnosis': safeToString(patient['diagnosis']),
      'treatment': safeToString(patient['treatment']),
      'notes': safeToString(patient['notes']),
      'visit_time': safeToString(patient['visit_time']),
      'consultation_duration': safeToString(patient['consultation_duration']),
    };
  }
}