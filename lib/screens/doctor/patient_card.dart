import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/language_provider.dart';
import '../../models/patient.dart';
import 'kashf.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final Map<String, dynamic>? doctorData;
  final VoidCallback onStartExam;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const PatientCard({
    super.key,
    required this.patient,
    this.doctorData,
    required this.onStartExam,
    required this.onComplete,
    required this.onDelete,
  });

  bool _isMale(String? gender) {
    if (gender == null || gender.trim().isEmpty) return true;
    final v = gender.trim().toLowerCase();
    return v == 'male' || v == 'ذكر' || v == 'م';
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageProvider.of(context).l;

    final bool isCompleted = patient.status == 'completed';
    final bool isInProgress = patient.status == 'in_progress';
    final bool male = _isMale(patient.gender);

    const Color kSuccessColor = Color(0xFF2E7D32);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          male ? Icons.male : Icons.female,
                          color: male ? Colors.blue : Colors.pink,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          patient.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${patient.age ?? "--"} ${l.years}${patient.department != null && patient.department!.isNotEmpty && patient.department != "General" ? " | ${patient.department}" : ""}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            patient.visitType ?? l.examination,
                            style: const TextStyle(
                              color: Colors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${l.turn} ${patient.turn}',
                    style: const TextStyle(
                        color: kPrimaryRed, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                if (!isCompleted) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // ✅ الإصلاح: نتحقق إن الدكتور حفظ فعلاً قبل ما نشيل المريض
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KashfScreen(
                              patient: patient,
                              doctorData: doctorData,
                            ),
                          ),
                        );
                        if (saved == true) onStartExam();
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(
                        isInProgress ? l.completeExam : l.startExam,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kSuccessColor,
                        side:
                            const BorderSide(color: kSuccessColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: kSuccessColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l.examDone,
                          style: const TextStyle(
                              color: kSuccessColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
