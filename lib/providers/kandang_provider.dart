import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/kandang_model.dart';

class KandangProvider extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late DatabaseReference _kandangRef;
  static const String _sharedKandangPath = 'kontrol/kandang';

  List<Kandang> _kandangs = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;
  StreamSubscription? _sensorSubscription;

  // Sensor Real-time Listeners
  int _infra1Value = 0;
  int _infra2Value = 0;

  List<Kandang> get kandangs => _kandangs;
  bool get isLoading => _isLoading;
  int get infra1Value => _infra1Value;
  int get infra2Value => _infra2Value;

  /// Initialize provider dengan user ID dan load data dari Firebase
  Future<void> initializeWithUser(String userId) async {
    _kandangRef = _database.ref(_sharedKandangPath);

    try {
      // Pastikan ada data awal agar user baru tidak selalu input dari nol.
      await _ensureInitialKandangData(userId);
    } catch (e) {
      if (kDebugMode) {
        print('Warning ensuring kandang initial data: $e');
      }
    }

    // Clear previous listener
    await _subscription?.cancel();

    // Load data dari Firebase dengan real-time listener
    _subscription = _kandangRef.onValue.listen(
      (event) {
        try {
          if (event.snapshot.exists && event.snapshot.value is Map) {
            final data =
                Map<dynamic, dynamic>.from(event.snapshot.value as Map);
            _kandangs =
                data.entries.where((entry) => entry.value is Map).map((entry) {
              final kandangData =
                  Map<dynamic, dynamic>.from(entry.value as Map);
              return Kandang(
                id: entry.key.toString(),
                nama: kandangData['nama'] ?? '',
                jumlahAyam: kandangData['jumlahAyam'] ?? 0,
                dibuat: kandangData['dibuat'] != null
                    ? DateTime.parse(kandangData['dibuat'])
                    : DateTime.now(),
                infraPath: kandangData['infraPath'],
              );
            }).toList();
          } else {
            _kandangs = [];
          }
          _isLoading = false;
          notifyListeners();
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing kandang data: $e');
          }
          _isLoading = false;
          notifyListeners();
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Error listening kandang data: $error');
        }
        _isLoading = false;
        notifyListeners();
      },
    );

    // Start listening to sensors from 'data' folder
    listenToSensors();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _ensureInitialKandangData(String userId) async {
    final sharedSnapshot = await _kandangRef.get();
    if (sharedSnapshot.exists) return;

    try {
      final legacyRef = _database.ref('users/$userId/kandang');
      final legacySnapshot = await legacyRef.get();
      if (legacySnapshot.exists) {
        await _kandangRef.set(legacySnapshot.value);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Warning reading legacy kandang data: $e');
      }
    }

    await _kandangRef.set({
      'kandang1': {
        'nama': 'Kandang 1',
        'jumlahAyam': 100,
        'dibuat': DateTime.now().toIso8601String(),
        'infraPath': 'infra1',
      },
      'kandang2': {
        'nama': 'Kandang 2',
        'jumlahAyam': 120,
        'dibuat': DateTime.now().toIso8601String(),
        'infraPath': 'infra2',
      },
    });
  }

  /// Clear semua data saat logout
  Future<void> clearData() async {
    await _subscription?.cancel();
    await _sensorSubscription?.cancel();
    _kandangs = [];
    _isLoading = true;
    _infra1Value = 0;
    _infra2Value = 0;
    notifyListeners();
  }

  void addKandang(String nama, int jumlahAyam, {String? infraPath}) async {
    try {
      const uuid = Uuid();
      final newId = uuid.v4();

      final newKandang = {
        'nama': nama,
        'jumlahAyam': jumlahAyam,
        'dibuat': DateTime.now().toIso8601String(),
        if (infraPath != null) 'infraPath': infraPath,
      };

      await _kandangRef.child(newId).set(newKandang);
      // Data akan automatically di-update via listener
    } catch (e) {
      print('Error adding kandang: $e');
    }
  }

  void updateKandang(
    String id,
    String nama,
    int jumlahAyam, {
    String? infraPath,
  }) async {
    try {
      final index = _kandangs.indexWhere((k) => k.id == id);
      if (index != -1) {
        final updated = {
          'nama': nama,
          'jumlahAyam': jumlahAyam,
          'dibuat': _kandangs[index].dibuat.toIso8601String(),
          if (infraPath != null) 'infraPath': infraPath,
        };

        await _kandangRef.child(id).set(updated);
        // Data akan automatically di-update via listener
      }
    } catch (e) {
      print('Error updating kandang: $e');
    }
  }

  void deleteKandang(String id) async {
    try {
      await _kandangRef.child(id).remove();
      // Data akan automatically di-updated via listener
    } catch (e) {
      print('Error deleting kandang: $e');
    }
  }

  Kandang? getKandangById(String id) {
    try {
      return _kandangs.firstWhere((k) => k.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Listen to sensor data dari Firebase 'data' folder
  /// Update infra1 dan infra2 values secara real-time
  void listenToSensors() {
    try {
      // Cancel previous sensor listener jika ada
      _sensorSubscription?.cancel();

      // Listen ke 'data' folder untuk mendapatkan infra1 dan infra2
      _sensorSubscription = _database.ref('data').onValue.listen(
        (event) {
          if (event.snapshot.exists) {
            final data = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            _infra1Value = data['infra1'] ?? 0;
            _infra2Value = data['infra2'] ?? 0;

            // Trigger notifyListeners() agar UI terupdate
            notifyListeners();
          }
        },
        onError: (error) {
          print('Error listening to sensors: $error');
        },
      );
    } catch (e) {
      print('Error setting up sensor listener: $e');
    }
  }

  /// Get current sensor value berdasarkan kandang index
  /// Index 0 → infra1Value, Index 1 → infra2Value
  int getCurrentSensorValue(int kandangIndex) {
    if (kandangIndex == 0) {
      return _infra1Value;
    } else if (kandangIndex == 1) {
      return _infra2Value;
    }
    return 0;
  }

  /// Capture sensor value snapshot saat jadwal panen
  /// Digunakan untuk menyimpan hitungan telur ke riwayat
  Future<void> captureSensorSnapshot({
    required String kandangId,
    required int kandangIndex,
    required String jenisPanen, // 'pagi' atau 'sore'
    required String jam,
  }) async {
    try {
      int sensorValue = getCurrentSensorValue(kandangIndex);
      print(
        'Captured sensor snapshot for $kandangId: $sensorValue telur ($jenisPanen)',
      );

      // Notify listeners agar dashboard bisa update last capture status
      notifyListeners();
    } catch (e) {
      print('Error capturing sensor snapshot: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }
}
