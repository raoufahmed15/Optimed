// lib/services/stat_service.dart

import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import '../core/database.dart';

class StatService {
  // ══════════════════════════════════════════════════════════════════════════
  //  SAFE HELPERS — assoc() بيرجع String? مش num
  //  لازم نعمل parse يدوي عبر DatabaseService.toInt / toDouble
  // ══════════════════════════════════════════════════════════════════════════

  static int _i(dynamic v) => DatabaseService.toInt(v);
  static double _d(dynamic v) => DatabaseService.toDouble(v);

  // ══════════════════════════════════════════════════════════════════════════
  //  MAIN
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> calculateStats(
      List<Patient> patients) async {
    try {
      final now = DateTime.now();
      final weekAgo =
          now.subtract(const Duration(days: 7)).toString().split(' ')[0];
      final monthAgo =
          now.subtract(const Duration(days: 30)).toString().split(' ')[0];
      final yearAgo =
          now.subtract(const Duration(days: 365)).toString().split(' ')[0];

      final todayPatients = patients.length;
      final completedToday =
          patients.where((p) => p.status == 'completed').length;
      final urgentToday = patients.where((p) => p.priority == 'عاجل').length;

      double weeklyEarnings = 0.0;
      double monthlyEarnings = 0.0;
      double yearlyEarnings = 0.0;

      try {
        // ← assoc()['total'] بيرجع String? (مثلاً "1500.00" أو null)
        // _d() بيعمل double.tryParse عليها بأمان

        final wRes = await DatabaseService.execute(
          "SELECT SUM(fee) as total FROM patients WHERE date >= :from AND status = 'completed'",
          {'from': weekAgo},
        );
        weeklyEarnings = _d(wRes.rows.first.assoc()['total']);

        final mRes = await DatabaseService.execute(
          "SELECT SUM(fee) as total FROM patients WHERE date >= :from AND status = 'completed'",
          {'from': monthAgo},
        );
        monthlyEarnings = _d(mRes.rows.first.assoc()['total']);

        final yRes = await DatabaseService.execute(
          "SELECT SUM(fee) as total FROM patients WHERE date >= :from AND status = 'completed'",
          {'from': yearAgo},
        );
        yearlyEarnings = _d(yRes.rows.first.assoc()['total']);
      } catch (e) {
        debugPrint('Error calculating earnings: $e');
      }

      final peakHours = await _analyzePeakHours();
      final genderDistribution = await _getGenderDistribution();
      final departmentDistribution = await _getDepartmentDistribution();
      final visitTypeDistribution = await _getVisitTypeDistribution();

      return {
        'todayPatients': todayPatients,
        'completedToday': completedToday,
        'urgentToday': urgentToday,
        'weeklyEarnings': weeklyEarnings,
        'monthlyEarnings': monthlyEarnings,
        'yearlyEarnings': yearlyEarnings,
        'peakHours': peakHours,
        'genderDistribution': genderDistribution,
        'departmentDistribution': departmentDistribution,
        'visitTypeDistribution': visitTypeDistribution,
      };
    } catch (e) {
      debugPrint('Error calculating stats: $e');
      return {'todayPatients': 0};
    }
  }

  // ── Visit types ────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _getVisitTypeDistribution() async {
    try {
      final result = await DatabaseService.execute(
        'SELECT visit_type, COUNT(*) as count FROM patients GROUP BY visit_type',
        {},
      );
      return result.rows.map((row) {
        final r = row.assoc();
        return {
          'visit_type': r['visit_type'] ?? '',
          'count': _i(r['count']),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting visit types: $e');
      return [];
    }
  }

  // ── Peak hours ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _analyzePeakHours() async {
    try {
      final result = await DatabaseService.execute(
        "SELECT HOUR(visit_time) as hour, COUNT(*) as count "
        "FROM patients WHERE visit_time IS NOT NULL AND visit_time != '' "
        "GROUP BY hour ORDER BY count DESC LIMIT 5",
        {},
      );
      return result.rows.map((row) {
        final r = row.assoc();
        return {
          'hour': '${_i(r['hour'])}:00',
          'count': _i(r['count']),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error analyzing peak hours: $e');
      return [];
    }
  }

  // ── Gender ─────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _getGenderDistribution() async {
    try {
      final result = await DatabaseService.execute(
        "SELECT gender, COUNT(*) as count FROM patients "
        "WHERE gender IS NOT NULL AND gender != '' GROUP BY gender",
        {},
      );
      return result.rows.map((row) {
        final r = row.assoc();
        return {
          'gender': r['gender'] ?? '',
          'count': _i(r['count']),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting gender distribution: $e');
      return [];
    }
  }

  // ── Department ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _getDepartmentDistribution() async {
    try {
      final result = await DatabaseService.execute(
        "SELECT department, COUNT(*) as count "
        "FROM patients WHERE department IS NOT NULL AND department != '' "
        "GROUP BY department ORDER BY count DESC LIMIT 5",
        {},
      );
      return result.rows.map((row) {
        final r = row.assoc();
        return {
          'department': r['department'] ?? '',
          'count': _i(r['count']),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting department distribution: $e');
      return [];
    }
  }
}
