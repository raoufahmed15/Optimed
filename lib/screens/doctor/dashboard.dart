import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';
import '../../services/server_service.dart';
import '../../services/stat_service.dart';
import '../../models/patient.dart';
import '../../core/database.dart';
import '../../core/constants.dart';
import '../../core/language_provider.dart';
import '../../core/app_localizations.dart';
import 'analytics_screen.dart';
import 'patient_card.dart';
import 'all_patients_screen.dart';
import 'prescription_customizer_screen.dart';
import 'import_migration_screen.dart';
import 'doctor_profile_screen.dart';
import 'custom_fields_widget.dart';

const Color kOptiBlue = Color(0xFF0070BB);

class DoctorDashboard extends StatefulWidget {
  final Map<String, dynamic> currentDoctor;
  final VoidCallback onLogout;
  const DoctorDashboard({
    super.key,
    required this.currentDoctor,
    required this.onLogout,
  });
  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  List<Patient> _activePatients = [];
  List<Patient> _allPatients = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  Map<String, dynamic> _stats = {};
  late ServerService _serverService;

  bool _isFullScreen = false;

  Timer? _refreshTimer;
  Timer? _changeListenerTimer;
  String? _lastChangeTimestamp;

  String _nurseCallStatus = "idle";
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final Set<int> _hiddenFromCompleted = {};
  HttpServer? _chatServer;
  bool _chatServerRunning = false;
  DateTime? _lastNurseHeartbeat;
  int _unreadMessageCount = 0;
  int _lastSeenNurseMessageCount = 0;
  Timer? _unreadCheckTimer;
  final AudioPlayer _messageAudioPlayer = AudioPlayer();
  bool _isChatOpen = false;
  int _soundPlayedForCount = 0;
  late Map<String, dynamic> _doctorData;
  final GlobalKey<AnalyticsScreenState> _analyticsKey =
      GlobalKey<AnalyticsScreenState>();

  AppLocalizations get _l => LanguageProvider.of(context).l;

  String get _doctorDisplayName {
    String name = _doctorData['name'] ?? _doctorData['full_name'] ?? 'Doctor';
    if (!name.toLowerCase().startsWith('dr.')) return "Dr. $name";
    return name;
  }

  @override
  void initState() {
    super.initState();
    _doctorData = Map<String, dynamic>.from(widget.currentDoctor);
    _serverService = ServerService();
    _initializeApp();
    _startAutoRefresh();
    _startChangeListener();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _changeListenerTimer?.cancel();
    _unreadCheckTimer?.cancel();
    _messageAudioPlayer.dispose();
    _serverService.stopServer();
    _chatServer?.close(force: true);
    _searchController.dispose();
    try {
      windowManager.setFullScreen(false);
    } catch (_) {}
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await windowManager.setFullScreen(_isFullScreen);
      } catch (e) {
        debugPrint('⚠️ setFullScreen error: $e');
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      await DatabaseService.database;
      await DatabaseService.cleanOldMessages();
      await _loadSeenMessageBaseline();
      await _startChatServer();
      await _serverService.startServer(_doctorData);
      await _loadPatients();
      _startUnreadMessageChecker();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSeenMessageBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('doctor_last_seen_nurse_msg_count') ?? 0;
      final result = await DatabaseService.execute(
        "SELECT COUNT(*) as count FROM messages WHERE sender = :sender",
        {'sender': 'Nurse'},
      );
      final actualCount =
          DatabaseService.toInt(result.rows.first.assoc()['count']);
      final baseline = saved > actualCount ? actualCount : saved;
      _lastSeenNurseMessageCount = baseline;
      _soundPlayedForCount = actualCount;
    } catch (e) {
      debugPrint("⚠️ _loadSeenMessageBaseline error: $e");
    }
  }

  Future<void> _saveSeenMessageBaseline(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('doctor_last_seen_nurse_msg_count', count);
    } catch (e) {
      debugPrint("⚠️ _saveSeenMessageBaseline error: $e");
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted &&
          _searchQuery.isEmpty &&
          (_selectedIndex == 0 || _selectedIndex == 2)) {
        _loadPatients();
        _checkNurseCallStatus();
      }
    });
  }

  void _startChangeListener() {
    _changeListenerTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      try {
        final timestamp =
            await DatabaseService.getSetting('last_patient_change');
        if (timestamp != null && timestamp != _lastChangeTimestamp) {
          _lastChangeTimestamp = timestamp;
          if (mounted &&
              _searchQuery.isEmpty &&
              (_selectedIndex == 0 || _selectedIndex == 2)) {
            _loadPatients();
          }
          if (mounted) {
            _analyticsKey.currentState?.refreshAll();
          }
        }
      } catch (_) {}
    });
  }

  void _startUnreadMessageChecker() {
    _checkUnreadMessages();
    _unreadCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) _checkUnreadMessages();
    });
  }

  Future<void> _checkUnreadMessages() async {
    try {
      final result = await DatabaseService.execute(
        "SELECT COUNT(*) as count FROM messages WHERE sender = :sender",
        {'sender': 'Nurse'},
      );
      final nurseCount =
          DatabaseService.toInt(result.rows.first.assoc()['count']);
      final unread = nurseCount - _lastSeenNurseMessageCount;
      if (!_isChatOpen &&
          nurseCount > _lastSeenNurseMessageCount &&
          nurseCount > _soundPlayedForCount) {
        _soundPlayedForCount = nurseCount;
        _playMessageSound();
      }
      if (mounted) {
        setState(() =>
            _unreadMessageCount = _isChatOpen ? 0 : (unread < 0 ? 0 : unread));
      }
    } catch (_) {}
  }

  void _playMessageSound() async {
    try {
      await _messageAudioPlayer.stop();
      await _messageAudioPlayer.play(AssetSource('masseage_sound.mp3'));
    } catch (e) {
      debugPrint("Error playing message sound: $e");
    }
  }

  Future<void> _checkNurseCallStatus() async {
    try {
      final value = await DatabaseService.getSetting('nurse_call');
      if (value != null && _nurseCallStatus != value) {
        setState(() => _nurseCallStatus = value);
        if (value == 'coming') {
          Timer(const Duration(seconds: 5), () {
            if (mounted && _nurseCallStatus == 'coming') _resetCall();
          });
        }
      }
    } catch (e) {
      debugPrint("Nurse call error: $e");
    }
  }

  Future<void> _startChatServer() async {
    if (_chatServerRunning) return;
    try {
      _chatServer = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
      _chatServerRunning = true;
      _chatServer!.listen((HttpRequest request) async {
        try {
          if (request.method == 'POST' && request.uri.path == '/send-message') {
            final content = await utf8.decoder.bind(request).join();
            final data = jsonDecode(content);
            await DatabaseService.execute(
              'INSERT INTO messages (sender, content, date, timestamp) '
              'VALUES (:sender, :content, :date, :timestamp)',
              {
                'sender': data['sender'],
                'content': data['content'],
                'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'timestamp':
                    data['timestamp'] ?? DateTime.now().toIso8601String(),
              },
            );
            request.response
              ..statusCode = 200
              ..write('{"status":"ok"}')
              ..close();
          } else if (request.method == 'GET' &&
              request.uri.path == '/get-messages') {
            final result = await DatabaseService.execute(
              'SELECT * FROM messages ORDER BY timestamp ASC',
            );
            final messages = result.rows
                .map((row) => Map<String, dynamic>.from(row.assoc()))
                .toList();
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(messages))
              ..close();
          } else if (request.method == 'POST' &&
              request.uri.path == '/nurse-heartbeat') {
            _lastNurseHeartbeat = DateTime.now();
            request.response
              ..statusCode = 200
              ..write('{"status":"ok"}')
              ..close();
          } else if (request.method == 'GET' &&
              request.uri.path == '/nurse-status') {
            final isOnline = _lastNurseHeartbeat != null &&
                DateTime.now().difference(_lastNurseHeartbeat!).inSeconds < 10;
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write('{"online":$isOnline}')
              ..close();
          } else {
            request.response
              ..statusCode = 404
              ..close();
          }
        } catch (e) {
          debugPrint('Error handling chat request: $e');
          request.response
            ..statusCode = 500
            ..close();
        }
      });
    } catch (e) {
      debugPrint('Error starting chat server: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  _loadPatients — بدون أي reorder تلقائي
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _loadPatients() async {
    final today = DateTime.now().toString().split(' ')[0];
    try {
      final activeResult = await DatabaseService.execute(
        "SELECT * FROM patients "
        "WHERE date = :date AND status IN ('waiting', 'in_progress') "
        "ORDER BY turn ASC",
        {'date': today},
      );
      final allResult = await DatabaseService.execute(
        "SELECT * FROM patients WHERE date = :date ORDER BY turn ASC",
        {'date': today},
      );
      if (mounted) {
        setState(() {
          _activePatients = activeResult.rows
              .map((row) => Patient.fromAssoc(row.assoc()))
              .toList();
          _allPatients = allResult.rows
              .map((row) => Patient.fromAssoc(row.assoc()))
              .toList();
        });
        _stats = await StatService.calculateStats(_allPatients);
      }
    } catch (e) {
      debugPrint('Error loading patients: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  _reorderActiveTurns — بتتكال من _updatePatientStatus و _beginExam
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _reorderActiveTurns() async {
    final today = DateTime.now().toString().split(' ')[0];
    try {
      // Pass 1: نحط أرقام كبيرة مؤقتة عشان منتعارضش
      final tempResult = await DatabaseService.execute(
        "SELECT id FROM patients "
        "WHERE date = :date AND status IN ('waiting', 'in_progress') "
        "ORDER BY turn ASC, id ASC",
        {'date': today},
      );
      final rows = tempResult.rows.toList();

      for (int i = 0; i < rows.length; i++) {
        final id = DatabaseService.toInt(rows[i].assoc()['id']);
        await DatabaseService.execute(
          "UPDATE patients SET turn = :turn WHERE id = :id",
          <String, dynamic>{'turn': 9000 + i, 'id': id},
        );
      }

      // Pass 2: نحط الأرقام الصح من 1
      for (int i = 0; i < rows.length; i++) {
        final id = DatabaseService.toInt(rows[i].assoc()['id']);
        await DatabaseService.execute(
          "UPDATE patients SET turn = :turn WHERE id = :id",
          <String, dynamic>{'turn': i + 1, 'id': id},
        );
      }

      await DatabaseService.updateSetting(
        'last_patient_change',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error reordering turns: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  _updatePatientStatus — للحذف/الأرشفة — بتعمل reorder
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _updatePatientStatus(int id, String status) async {
    try {
      await DatabaseService.updatePatientStatus(id, status);
      // await _reorderActiveTurns(); // Removed as reorder is now in updatePatientStatus
      await _loadPatients();
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ✅ _beginExam — بتعمل reorder بعد الإتمام عشان الممرضة تاخد الأرقام صح
  // ══════════════════════════════════════════════════════════════════════════
  void _beginExam(Patient patient) async {
    try {
      final int patientId = patient.id!;
      await DatabaseService.execute(
        "UPDATE patients SET status = 'completed' WHERE id = :id",
        <String, dynamic>{'id': patientId},
      );
      // ✅ إعادة ترتيب أرقام الأدوار بعد إتمام الكشف
      // الممرضة بتجيب الأرقام من السيرفر كل 4 ثواني عبر _syncTurnsFromServer
      // await _reorderActiveTurns(); // Removed as reorder is now in updatePatientStatus
      await _loadPatients();
    } catch (e) {
      debugPrint('Error in _beginExam: $e');
    }
  }

  void _openClinicChat() {
    setState(() {
      _isChatOpen = true;
      _unreadMessageCount = 0;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatInterface(
        doctorName: _doctorDisplayName,
        l: _l,
      ),
    ).whenComplete(() async {
      if (mounted) {
        try {
          final result = await DatabaseService.execute(
            "SELECT COUNT(*) as count FROM messages WHERE sender = :sender",
            {'sender': 'Nurse'},
          );
          final nurseCount = DatabaseService.toInt(
            result.rows.first.assoc()['count'],
          );
          if (mounted) {
            _lastSeenNurseMessageCount = nurseCount;
            _soundPlayedForCount = nurseCount;
            setState(() => _isChatOpen = false);
            await _saveSeenMessageBaseline(nurseCount);
          }
        } catch (e) {
          debugPrint("⚠️ Error saving seen baseline on chat close: $e");
          if (mounted) setState(() => _isChatOpen = false);
        }
      }
    });
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(
            bottom: 80, left: screenWidth * 0.22, right: screenWidth * 0.22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      ));
  }

  void _hideFromCompleted(int id) {
    if (!mounted) return;
    setState(() => _hiddenFromCompleted.add(id));
    _showMsg(_l.patientCleared);
  }

  Future<void> _clearAllCompleted() async {
    final completed = _allPatients
        .where((p) =>
            p.status == 'completed' && !_hiddenFromCompleted.contains(p.id))
        .toList();
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_l.confirmClear),
            content: Text(_l.confirmClearBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_l.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_l.clearAll,
                      style: const TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
    if (confirm) {
      setState(() {
        for (final p in completed) {
          if (p.id != null) _hiddenFromCompleted.add(p.id!);
        }
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentDoctor');
    await _serverService.stopServer();
    await _chatServer?.close(force: true);
    widget.onLogout();
  }

  Widget _buildLangToggle(LanguageProviderState langState) {
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
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
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
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 3)
                ],
              ),
            ),
            const SizedBox(width: 5),
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
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langState = LanguageProvider.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kOptiBlue)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kOptiBlue,
        elevation: 2,
        toolbarHeight: 80,
        title: Transform.scale(
          scale: 1.6,
          child: Image.asset(
            'assets/OptiMed (1).png',
            width: 180,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('OptiMed',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFullScreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: Colors.white,
            ),
            tooltip: _isFullScreen ? 'إلغاء ملء الشاشة' : 'ملء الشاشة',
            onPressed: _toggleFullScreen,
          ),
          _buildLangToggle(langState),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 26),
            onPressed: () {
              _loadPatients();
              if (_selectedIndex == 1) {
                _analyticsKey.currentState?.refreshAll();
              }
            },
            tooltip: _l.refresh,
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _selectedIndex > 2 ? 3 : _selectedIndex,
        children: [
          _buildMainScreen(),
          AnalyticsScreen(key: _analyticsKey, stats: _stats),
          _buildCompletedScreen(),
          const AllPatientsScreen(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              FloatingActionButton(
                onPressed: _openClinicChat,
                backgroundColor: Colors.white,
                mini: true,
                heroTag: "chat_bot",
                child: const Icon(Icons.chat_bubble_rounded, color: kOptiBlue),
              ),
              if (_unreadMessageCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFAB(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 20),
          decoration: const BoxDecoration(
            color: kOptiBlue,
            boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Transform.scale(
                scale: 2.2,
                child: Image.asset('assets/OptiMed (1).png',
                    width: 140, fit: BoxFit.contain),
              ),
              const SizedBox(height: 15),
              Text(_doctorDisplayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                  textAlign: TextAlign.center),
              if ((_doctorData['specialization'] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_doctorData['specialization'],
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(padding: EdgeInsets.zero, children: [
              _drawerItem(0, Icons.home_rounded, _l.todaysQueue),
              _drawerItem(1, Icons.bar_chart_rounded, _l.analytics),
              _drawerItem(2, Icons.check_circle_rounded, _l.completedCases),
              _drawerItem(3, Icons.people_alt_rounded, _l.patientRecords),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              _drawerItem(
                -3,
                Icons.manage_accounts_rounded,
                _l.isArabic ? 'الملف الشخصي' : 'My Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorProfileScreen(
                        currentDoctor: _doctorData,
                        onProfileUpdated: (updated) {
                          setState(
                              () => _doctorData = {..._doctorData, ...updated});
                        },
                      ),
                    ),
                  );
                },
              ),
              _drawerItem(
                -1,
                Icons.receipt_long_rounded,
                _l.customizePrescription,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PrescriptionCustomizerScreen(
                                doctorId: int.tryParse(
                                        _doctorData['id']?.toString() ?? '0') ??
                                    0,
                              )));
                },
              ),
              _drawerItem(
                -2,
                Icons.upload_file_rounded,
                _l.importFromOldSystem,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ImportMigrationScreen()))
                      .then((_) => _loadPatients());
                },
              ),
              _drawerItem(
                -4,
                Icons.edit_note_rounded,
                'إدارة القوالب المخصصة',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PinnedTemplatesManager(
                        doctorId: int.tryParse(
                                _doctorData['id']?.toString() ?? '0') ??
                            0,
                      ),
                    ),
                  );
                },
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.red.withOpacity(0.05),
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text(_l.logout,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: _logout,
          ),
        ),
      ]),
    );
  }

  Widget _drawerItem(int index, IconData icon, String title,
      {VoidCallback? onTap}) {
    final bool isSelected = index >= 0 && _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? kOptiBlue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap ??
            () {
              setState(() => _selectedIndex = index);
              Navigator.pop(context);
              if (index == 1) {
                Future.delayed(const Duration(milliseconds: 200), () {
                  _analyticsKey.currentState?.refreshAll();
                });
              }
            },
        selected: isSelected,
        leading: Icon(icon,
            color: isSelected ? kOptiBlue : Colors.blueGrey.shade400),
        title: Text(title,
            style: TextStyle(
              color: isSelected ? kOptiBlue : Colors.blueGrey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            )),
      ),
    );
  }

  Widget _buildMainScreen() {
    final filtered = _activePatients
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    return Column(children: [
      _buildDoctorInfoBar(),
      _buildSearchField(),
      Expanded(
        child: filtered.isEmpty
            ? _buildEmptyState(
                title: _l.queueEmpty,
                subtitle: _l.noWaiting,
                icon: Icons.person_add_disabled_outlined)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _patientRow(filtered[index]),
              ),
      ),
    ]);
  }

  Widget _buildDoctorInfoBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Row(children: [
        const CircleAvatar(
            backgroundColor: kOptiBlue,
            child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 12),
        Text(_doctorDisplayName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        const Icon(Icons.circle, color: Colors.green, size: 12),
        const SizedBox(width: 5),
        Text(_l.online,
            style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: _l.searchHint,
          prefixIcon: const Icon(Icons.search, color: kOptiBlue),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _patientRow(Patient patient) {
    return Column(children: [
      PatientCard(
        patient: patient,
        doctorData: _doctorData,
        onStartExam: () => _beginExam(patient),
        onComplete: () {},
        onDelete: () => _updatePatientStatus(patient.id!, 'archived'),
      ),
      const SizedBox(height: 15),
    ]);
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
                color: kOptiBlue.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(icon, size: 80, color: kOptiBlue.withOpacity(0.2)),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const SizedBox(height: 25),
          OutlinedButton.icon(
            onPressed: _loadPatients,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(_l.refreshList),
            style: OutlinedButton.styleFrom(
              foregroundColor: kOptiBlue,
              side: BorderSide(color: kOptiBlue.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCompletedScreen() {
    final completed = _allPatients
        .where((p) =>
            p.status == 'completed' && !_hiddenFromCompleted.contains(p.id))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_l.completedToday(completed.length),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey)),
            if (completed.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _clearAllCompleted,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: Text(_l.clearAll),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: completed.isEmpty
            ? _buildEmptyState(
                title: _l.noCompletedCases,
                subtitle: _l.finishedAppear,
                icon: Icons.check_circle_outline)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: completed.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PatientCard(
                    patient: completed[index],
                    doctorData: _doctorData,
                    onStartExam: () {},
                    onComplete: () {},
                    onDelete: () => _hideFromCompleted(completed[index].id!),
                  ),
                ),
              ),
      ),
    ]);
  }

  Widget _buildFAB() {
    final isCalling = _nurseCallStatus == "calling";
    final isComing = _nurseCallStatus == "coming";
    return FloatingActionButton.extended(
      heroTag: "nurse_call",
      onPressed: isCalling ? _resetCall : _callNurse,
      backgroundColor:
          isComing ? Colors.green : (isCalling ? Colors.orange : kOptiBlue),
      label: Text(
        isComing ? _l.nursesComing : (isCalling ? _l.calling : _l.callNurse),
        style: const TextStyle(color: Colors.white),
      ),
      icon: Icon(
        isComing ? Icons.directions_run : Icons.notification_important,
        color: Colors.white,
      ),
    );
  }

  Future<void> _callNurse() async {
    await DatabaseService.updateSetting('nurse_call', 'calling');
    setState(() => _nurseCallStatus = "calling");
  }

  Future<void> _resetCall() async {
    await DatabaseService.updateSetting('nurse_call', 'idle');
    if (mounted) setState(() => _nurseCallStatus = "idle");
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Chat Interface
// ══════════════════════════════════════════════════════════════════════════════
class _ChatInterface extends StatefulWidget {
  final String doctorName;
  final AppLocalizations l;
  const _ChatInterface({required this.doctorName, required this.l});
  @override
  State<_ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<_ChatInterface> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _timer;
  bool _nurseOnline = false;
  AppLocalizations get _l => widget.l;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    try {
      final result = await DatabaseService.execute(
        'SELECT * FROM messages ORDER BY timestamp ASC',
      );
      final data = result.rows
          .map((row) => Map<String, dynamic>.from(row.assoc()))
          .toList();
      try {
        final res = await http
            .get(Uri.parse('http://127.0.0.1:8081/nurse-status'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200 && mounted) {
          setState(() => _nurseOnline = jsonDecode(res.body)['online'] == true);
        }
      } catch (_) {
        if (mounted) setState(() => _nurseOnline = false);
      }
      if (mounted) {
        final wasAtBottom = !_scrollController.hasClients ||
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 50;
        setState(() => _messages = data);
        if (wasAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _send() async {
    if (_msgController.text.trim().isEmpty) return;
    final content = _msgController.text;
    _msgController.clear();
    try {
      await DatabaseService.execute(
        'INSERT INTO messages (sender, content, date, timestamp) '
        'VALUES (:sender, :content, :date, :timestamp)',
        {
          'sender': 'Doctor',
          'content': content,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      await _loadMessages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(ts));
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: kOptiBlue.withOpacity(0.1),
                child: const Icon(Icons.person_outline, color: kOptiBlue)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_l.nurse,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(children: [
                      Icon(Icons.circle,
                          size: 8,
                          color: _nurseOnline ? Colors.green : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _nurseOnline ? _l.online : _l.offline,
                        style: TextStyle(
                          color: _nurseOnline ? Colors.green : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                  ]),
            ),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _messages.isEmpty
              ? Center(child: Text(_l.noMessages))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['sender'] == 'Doctor';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            const CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.person,
                                    color: Colors.white, size: 14)),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? kOptiBlue : Colors.grey[100],
                                borderRadius:
                                    BorderRadius.circular(15).copyWith(
                                  bottomLeft: isMe
                                      ? const Radius.circular(15)
                                      : Radius.zero,
                                  bottomRight: isMe
                                      ? Radius.zero
                                      : const Radius.circular(15),
                                ),
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(msg['content']?.toString() ?? '',
                                        style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                : Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text(
                                        _formatTime(
                                            msg['timestamp']?.toString()),
                                        style: TextStyle(
                                            color: isMe
                                                ? Colors.white70
                                                : Colors.grey,
                                            fontSize: 10)),
                                  ]),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            const CircleAvatar(
                                radius: 16,
                                backgroundColor: kOptiBlue,
                                child: Icon(Icons.person,
                                    color: Colors.white, size: 14)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 15,
            left: 15,
            right: 15,
            top: 10,
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                decoration: InputDecoration(
                  hintText: _l.typeMessage,
                  filled: true,
                  fillColor: const Color(0xFFF0F4F8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration:
                  const BoxDecoration(color: kOptiBlue, shape: BoxShape.circle),
              child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _send),
            ),
          ]),
        ),
      ]),
    );
  }
}
