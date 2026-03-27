import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class TelurProvider extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late DatabaseReference _riwayatRef;

  int _telurHariIni = 0;
  int _kandang1HariIni = 0;
  int _kandang2HariIni = 0;
  int _totalTelur = 0;
  bool _isSynced = false;

  int get telurHariIni => _telurHariIni;
  int get kandang1HariIni => _kandang1HariIni;
  int get kandang2HariIni => _kandang2HariIni;
  int get totalTelur => _totalTelur;
  bool get isSynced => _isSynced;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  int _readKandang1(Map<dynamic, dynamic> data) {
    return _toInt(data['kandang1_hari_ini'] ?? data['kandang_1_hari_ini']);
  }

  int _readKandang2(Map<dynamic, dynamic> data) {
    return _toInt(data['kandang2_hari_ini'] ?? data['kandang_2_hari_ini']);
  }

  TelurProvider() {
    _riwayatRef = _database.ref('riwayat/summary');
    _initializeRiwayat();
  }

  Future<void> _initializeRiwayat() async {
    try {
      // Set initial values if not exist
      final snapshot = await _riwayatRef.get();

      if (!snapshot.exists) {
        // Create initial structure
        await _riwayatRef.set({
          'telur_hari_ini': 0,
          'kandang1_hari_ini': 0,
          'kandang2_hari_ini': 0,
          'total_telur': 0,
          'last_reset_date': DateTime.now().toIso8601String().split('T')[0],
        });
      }

      // Fetch current data
      _loadRiwayat();

      // Listen for changes
      _riwayatRef.onValue.listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          _telurHariIni = _toInt(data['telur_hari_ini']);
          _kandang1HariIni = _readKandang1(data);
          _kandang2HariIni = _readKandang2(data);
          _totalTelur = _toInt(data['total_telur']);

          notifyListeners();
        }
      });

      _isSynced = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing telur data: $e');
      _isSynced = false;
    }
  }

  Future<void> _loadRiwayat() async {
    try {
      final snapshot = await _riwayatRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _telurHariIni = _toInt(data['telur_hari_ini']);
        _kandang1HariIni = _readKandang1(data);
        _kandang2HariIni = _readKandang2(data);
        _totalTelur = _toInt(data['total_telur']);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading telur data: $e');
    }
  }

  Future<void> addTelurHariIni(int jumlah) async {
    try {
      final newTotal = _telurHariIni + jumlah;
      await _riwayatRef.update({'telur_hari_ini': newTotal});
      _telurHariIni = newTotal;
      notifyListeners();
    } catch (e) {
      print('Error adding telur hari ini: $e');
    }
  }

  Future<void> setTotalTelur(int total) async {
    try {
      await _riwayatRef.update({'total_telur': total});
      _totalTelur = total;
      notifyListeners();
    } catch (e) {
      print('Error setting total telur: $e');
    }
  }

  Future<void> resetTelurHariIni() async {
    try {
      final todayDate = DateTime.now().toIso8601String().split('T')[0];
      await _riwayatRef.update({
        'telur_hari_ini': 0,
        'kandang1_hari_ini': 0,
        'kandang2_hari_ini': 0,
        'last_reset_date': todayDate,
      });
      _telurHariIni = 0;
      _kandang1HariIni = 0;
      _kandang2HariIni = 0;
      notifyListeners();
    } catch (e) {
      print('Error resetting telur hari ini: $e');
    }
  }

  Future<void> manualReset() async {
    try {
      await _riwayatRef.set({
        'telur_hari_ini': 0,
        'kandang1_hari_ini': 0,
        'kandang2_hari_ini': 0,
        'total_telur': 0,
        'last_reset_date': DateTime.now().toIso8601String().split('T')[0],
      });
      _telurHariIni = 0;
      _kandang1HariIni = 0;
      _kandang2HariIni = 0;
      _totalTelur = 0;
      notifyListeners();
    } catch (e) {
      print('Error manual reset: $e');
    }
  }
}
