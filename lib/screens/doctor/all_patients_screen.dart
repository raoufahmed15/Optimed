// lib/screens/doctor/all_patients_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/database.dart';
import '../../core/language_provider.dart';
import 'patient_profile_screen.dart';

const Color kOptiBlue = Color(0xFF0070BB);

class AllPatientsScreen extends StatefulWidget {
  const AllPatientsScreen({super.key});

  @override
  State<AllPatientsScreen> createState() => _AllPatientsScreenState();
}

class _AllPatientsScreenState extends State<AllPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _isSearching = false;
  int _totalFound = 0;

  get _l => LanguageProvider.of(context).l;

  /// البحث عن المرضى بالاسم أو الهاتف
  Future<void> _searchPatientHistory(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _history = [];
        _totalFound = 0;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      // استخدم DatabaseService.searchPatients بدل db.query
      final results = await DatabaseService.searchPatients(query);
      _totalFound = results.length;

      // إزالة التكرارات
      final seen = <String>{};
      final deduplicated = <Map<String, dynamic>>[];
      for (final r in results) {
        final phone = (r['phone'] ?? '').toString().trim().replaceAll(' ', '');
        final name = (r['name'] ?? '').toString().trim().toLowerCase();
        final key = phone.isNotEmpty ? 'phone_$phone' : 'name_$name';
        if (!seen.contains(key)) {
          seen.add(key);
          deduplicated.add(r);
        }
      }
      if (mounted) {
        setState(() {
          _history = deduplicated;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في البحث: $e')),
        );
      }
    }
  }

  void _openProfile(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientProfileScreen(
          patientName: patient['name'] ?? '',
          patientPhone: patient['phone'],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l.patientRecordsTitle),
        backgroundColor: kOptiBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchHeader(l),
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: kOptiBlue))
                : _history.isEmpty
                    ? _buildEmptyState(l)
                    : _buildPatientList(l),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: kOptiBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _searchPatientHistory,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: l.searchByNameOrPhone,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search, color: kOptiBlue),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _searchPatientHistory('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.foundPatients(_history.length, _totalFound),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientList(l) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final patient = _history[index];
        final gender = (patient['gender'] ?? '').toString();
        final isFemale = gender == 'female' || gender == 'أنثى';
        final status = patient['status'] ?? '';
        final isImported = (patient['nurse'] ?? '') == 'مستورد';

        return GestureDetector(
          onTap: () => _openProfile(patient),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: kOptiBlue.withOpacity(0.1),
                    child: Icon(
                      isFemale ? Icons.face_2 : Icons.face,
                      color: kOptiBlue,
                      size: 28,
                    ),
                  ),
                  if (isImported)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.teal, shape: BoxShape.circle),
                        child: const Icon(Icons.upload_rounded,
                            color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
              title: Text(
                patient['name'] ?? l.unknown,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.phone, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      patient['phone'] ?? l.noPhone,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.calendar_today,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${l.lastVisit}: ${patient['date'] ?? '--'}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ]),
                  if (isImported)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(children: [
                        Icon(Icons.upload_file,
                            size: 12, color: Colors.teal.shade400),
                        const SizedBox(width: 4),
                        Text(l.importedFromOld,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.teal.shade400,
                                fontStyle: FontStyle.italic)),
                      ]),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'completed'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      patient['visit_type'] ?? l.examination,
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'completed'
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(l) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery
                ? Icons.search_off_rounded
                : Icons.person_search_rounded,
            size: 100,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 15),
          Text(
            hasQuery
                ? l.noResultsFor(_searchController.text)
                : l.searchPrompt,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          if (hasQuery) ...[
            const SizedBox(height: 8),
            Text(
              l.tryAgain,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}