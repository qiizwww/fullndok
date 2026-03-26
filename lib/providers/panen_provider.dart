import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/panen_model.dart';

class PanenProvider extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  static const bool _allowFlutterAutoCaptureWrite = false;

  // Tracking snapshot untuk time-windowing logic
  final Map<String, int> _snapshotPagiHariIni = {}; // kandangId -> nilaiPagi
  final Map<String, int> _snapshotSoreHariIni = {}; // kandangId -> nilaiSore

  final List<Panen> _panens = [];

  List<Panen> get panens => _panens;

  List<Panen> getPanenByKandang(String kandangId) {
    return _panens.where((p) => p.kandangId == kandangId).toList();
  }

  List<Panen> getPanenByDate(DateTime date) {
    return _panens.where((p) {
      return p.tanggalPanen.year == date.year &&
          p.tanggalPanen.month == date.month &&
          p.tanggalPanen.day == date.day;
    }).toList();
  }

  List<Panen> getPanenByDateRange(DateTime startDate, DateTime endDate) {
    return _panens.where((p) {
      return p.tanggalPanen.isAfter(startDate) &&
          p.tanggalPanen.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  void addPanen(
    String kandangId,
    String kandangNama,
    int jumlahTelur,
    DateTime tanggalPanen,
    String jam,
    String catatan,
  ) {
    const uuid = Uuid();
    final newPanen = Panen(
      id: uuid.v4(),
      kandangId: kandangId,
      kandangNama: kandangNama,
      jumlahTelur: jumlahTelur,
      tanggalPanen: tanggalPanen,
      jam: jam,
      catatan: catatan,
    );
    _panens.add(newPanen);
    _panens.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));
    notifyListeners();
  }

  void deletePanen(String id) {
    _panens.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  int getTotalPanenHari(DateTime date, String kandangId) {
    return _panens.where((p) {
      return p.kandangId == kandangId &&
          p.tanggalPanen.year == date.year &&
          p.tanggalPanen.month == date.month &&
          p.tanggalPanen.day == date.day;
    }).fold(0, (sum, p) => sum + p.jumlahTelur);
  }

  /// Get total panen per hari untuk semua kandang
  int getTotalHarianSemuaKandang(DateTime date) {
    return _panens.where((p) {
      return p.tanggalPanen.year == date.year &&
          p.tanggalPanen.month == date.month &&
          p.tanggalPanen.day == date.day;
    }).fold(0, (sum, p) => sum + p.jumlahTelur);
  }

  /// Get last harvest info untuk kandang
  /// Berguna untuk dashboard "Status Panen Terakhir"
  Panen? getLastHarvestStatus(String kandangId) {
    final panenKandang =
        _panens.where((p) => p.kandangId == kandangId).toList();
    if (panenKandang.isEmpty) return null;
    panenKandang.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));
    return panenKandang.first;
  }

  /// Get panen history per kandang grouped by date untuk riwayat
  Map<DateTime, List<Panen>> getPanenHistoryGroupedByDate(String kandangId) {
    final map = <DateTime, List<Panen>>{};
    final panenKandang =
        _panens.where((p) => p.kandangId == kandangId).toList();

    for (final panen in panenKandang) {
      final dateKey = DateTime(
        panen.tanggalPanen.year,
        panen.tanggalPanen.month,
        panen.tanggalPanen.day,
      );
      map.putIfAbsent(dateKey, () => []).add(panen);
    }

    return map;
  }

  /// Add panen dari sensor snapshot dengan tracking jenis panen (pagi/sore)
  void addPanenFromSensor(
    String kandangId,
    String kandangNama,
    int sensorValue,
    String jenisPanen,
    String jam, {
    int? panenSebelumnya,
  }) {
    const uuid = Uuid();

    // Jika panen sore dan ada panen pagi, hitung delta
    int jumlahTelur = sensorValue;
    if (jenisPanen == 'sore' && panenSebelumnya != null) {
      jumlahTelur = sensorValue - panenSebelumnya;
    }

    final newPanen = Panen(
      id: uuid.v4(),
      kandangId: kandangId,
      kandangNama: kandangNama,
      jumlahTelur: jumlahTelur,
      tanggalPanen: DateTime.now(),
      jam: jam,
      catatan: 'Panen $jenisPanen - Auto capture dari sensor',
      jenisPanen: jenisPanen,
      panenSebelumnya: panenSebelumnya,
      sensorSnapshot: sensorValue,
    );

    _panens.add(newPanen);
    _panens.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));
    notifyListeners();
  }

  // ============================================
  // TIME-WINDOWING & SNAPSHOT TRACKING
  // ============================================

  /// Get nilai panen pagi hari ini untuk delta calculation sore
  int? getPanenPagiTodayValue(String kandangId) {
    return _snapshotPagiHariIni[kandangId];
  }

  /// Get nilai panen sore hari ini
  int? getPanenSoreTodayValue(String kandangId) {
    return _snapshotSoreHariIni[kandangId];
  }

  /// Cek apakah panen pagi sudah di-record hari ini
  bool isPanenPagiRecordedToday(String kandangId) {
    return _snapshotPagiHariIni.containsKey(kandangId);
  }

  /// Cek apakah panen sore sudah di-record hari ini
  bool isPanenSoreRecordedToday(String kandangId) {
    return _snapshotSoreHariIni.containsKey(kandangId);
  }

  /// Reset snapshot harian (call setelah panen sore selesai atau tengah malam)
  void resetDailySnapshots() {
    _snapshotPagiHariIni.clear();
    _snapshotSoreHariIni.clear();
    if (kDebugMode) {
      print('✅ Daily snapshots reset');
    }
    notifyListeners();
  }

  /// AUTO-CAPTURE DARI SCHEDULER
  /// Panggil ini saat scheduler trigger jam 09:00
  Future<void> captureScheduledPanenPagi(
    String kandangId,
    String kandangNama,
    int sensorValue,
  ) async {
    try {
      // Jika sudah di-record pagi ini, skip
      if (isPanenPagiRecordedToday(kandangId)) {
        if (kDebugMode) {
          print('⚠️ Panen pagi untuk $kandangId sudah di-record hari ini');
        }
        return;
      }

      // Time-Window Pagi: Ambil nilai sensor sebagai total telur pagi
      // (Karena ini akumulasi dari jam 15:01 kemarin hingga 09:00 hari ini)
      int jumlahTelur = sensorValue;

      // Simpan ke snapshot untuk reference delta sore nanti
      _snapshotPagiHariIni[kandangId] = sensorValue;

      const uuid = Uuid();
      final newPanen = Panen(
        id: uuid.v4(),
        kandangId: kandangId,
        kandangNama: kandangNama,
        jumlahTelur: jumlahTelur,
        tanggalPanen: DateTime.now(),
        jam: '09:00',
        catatan: 'Auto-capture PAGI dari scheduler',
        jenisPanen: 'pagi',
        sensorSnapshot: sensorValue,
        panenSebelumnya: null, // Pagi tidak butuh panenSebelumnya
      );

      _panens.add(newPanen);
      _panens.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));

      // Guard: auto-capture write hanya dari Railway worker.
      if (_allowFlutterAutoCaptureWrite) {
        await _savePanenToFirebase(newPanen);
      }

      if (kDebugMode) {
        print('✅ Panen Pagi recorded untuk $kandangNama: $jumlahTelur telur');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error capturing panen pagi: $e');
      }
    }
  }

  /// AUTO-CAPTURE DARI SCHEDULER
  /// Panggil ini saat scheduler trigger jam 15:00
  /// Dengan delta calculation: nilai_sore - nilai_pagi
  Future<void> captureScheduledPanenSore(
    String kandangId,
    String kandangNama,
    int sensorValue,
  ) async {
    try {
      // Jika sudah di-record sore ini, skip
      if (isPanenSoreRecordedToday(kandangId)) {
        if (kDebugMode) {
          print('⚠️ Panen sore untuk $kandangId sudah di-record hari ini');
        }
        return;
      }

      // Ambil nilai pagi hari ini
      int? nilaiPagi = getPanenPagiTodayValue(kandangId);

      // Time-Window Sore: Hitung delta dari nilai pagi
      int jumlahTelur = sensorValue;
      if (nilaiPagi != null) {
        jumlahTelur = sensorValue - nilaiPagi;
      } else {
        if (kDebugMode) {
          print(
            '⚠️ Nilai pagi tidak ditemukan untuk $kandangId, gunakan nilai sensor langsung',
          );
        }
      }

      // Simpan ke snapshot
      _snapshotSoreHariIni[kandangId] = sensorValue;

      const uuid = Uuid();
      final newPanen = Panen(
        id: uuid.v4(),
        kandangId: kandangId,
        kandangNama: kandangNama,
        jumlahTelur: jumlahTelur,
        tanggalPanen: DateTime.now(),
        jam: '15:00',
        catatan:
            'Auto-capture SORE dari scheduler${nilaiPagi != null ? ' (delta: $sensorValue - $nilaiPagi)' : ''}',
        jenisPanen: 'sore',
        sensorSnapshot: sensorValue,
        panenSebelumnya: nilaiPagi,
      );

      _panens.add(newPanen);
      _panens.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));

      // Guard: auto-capture write hanya dari Railway worker.
      if (_allowFlutterAutoCaptureWrite) {
        await _savePanenToFirebase(newPanen);
      }

      if (kDebugMode) {
        print(
          '✅ Panen Sore recorded untuk $kandangNama: $jumlahTelur telur${nilaiPagi != null ? ' (delta: $sensorValue - $nilaiPagi)' : ''}',
        );
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error capturing panen sore: $e');
      }
    }
  }

  /// Simpan panen ke Firebase
  Future<void> _savePanenToFirebase(Panen panen) async {
    try {
      final ref = _database.ref('riwayat/records').push();
      await ref.set({
        'id': panen.id,
        'kandang_id': panen.kandangId,
        'kandang_nama': panen.kandangNama,
        'jumlah_telur': panen.jumlahTelur,
        'tanggal_panen': panen.tanggalPanen.toIso8601String(),
        'jam': panen.jam,
        'jenis_panen': panen.jenisPanen,
        'sensor_snapshot': panen.sensorSnapshot,
        'panen_sebelumnya': panen.panenSebelumnya,
        'catatan': panen.catatan,
      });

      await _updateRiwayatSummary(panen);

      if (kDebugMode) {
        print('✅ Panen saved to Firebase: ${panen.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving panen to Firebase: $e');
      }
    }
  }

  Future<void> _updateRiwayatSummary(Panen panen) async {
    final now = panen.tanggalPanen;
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final summaryRef = _database.ref('riwayat/summary');

    await summaryRef.runTransaction((current) {
      final data = Map<dynamic, dynamic>.from(
        (current as Map?) ?? <dynamic, dynamic>{},
      );

      int telurHariIni = (data['telur_hari_ini'] ?? 0) as int;
      int totalTelur = (data['total_telur'] ?? 0) as int;
      int kandang1 = (data['kandang1_hari_ini'] ?? 0) as int;
      int kandang2 = (data['kandang2_hari_ini'] ?? 0) as int;
      final lastDate = '${data['last_reset_date'] ?? ''}';

      if (lastDate != dateKey) {
        telurHariIni = 0;
        kandang1 = 0;
        kandang2 = 0;
      }

      telurHariIni += panen.jumlahTelur;
      totalTelur += panen.jumlahTelur;

      final kandangIdLower = panen.kandangId.toLowerCase();
      if (kandangIdLower == 'kandang1' || kandangIdLower == 'kandang_1') {
        kandang1 += panen.jumlahTelur;
      }
      if (kandangIdLower == 'kandang2' || kandangIdLower == 'kandang_2') {
        kandang2 += panen.jumlahTelur;
      }

      return Transaction.success({
        ...data,
        'telur_hari_ini': telurHariIni,
        'kandang1_hari_ini': kandang1,
        'kandang2_hari_ini': kandang2,
        'total_telur': totalTelur,
        'last_reset_date': dateKey,
        'updated_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Load snapshots dari Firebase ketika app start (untuk sync state)
  Future<void> loadTodaySnapshots() async {
    try {
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final ref = _database.ref('panen_snapshot/$todayKey');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

        // Load snapshot pagi
        if (data.containsKey('pagi')) {
          final pagiData = Map<dynamic, dynamic>.from(data['pagi'] as Map);
          pagiData.forEach((kandangId, value) {
            if (kandangId != 'timestamp') {
              _snapshotPagiHariIni[kandangId] = value as int;
            }
          });
        }

        // Load snapshot sore
        if (data.containsKey('sore')) {
          final soreData = Map<dynamic, dynamic>.from(data['sore'] as Map);
          soreData.forEach((kandangId, value) {
            if (kandangId != 'timestamp' &&
                !kandangId.toString().startsWith('delta_')) {
              _snapshotSoreHariIni[kandangId] = value as int;
            }
          });
        }

        if (kDebugMode) {
          print('✅ Today snapshots loaded from Firebase');
          print('   Pagi: $_snapshotPagiHariIni');
          print('   Sore: $_snapshotSoreHariIni');
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading today snapshots: $e');
      }
    }
  }

  /// Restore historical panen dari Firebase saat app start
  Future<void> restorePanenHistoryFromFirebase() async {
    try {
      final ref = _database.ref('riwayat/records');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        _panens.clear();

        data.forEach((key, value) {
          if (value is! Map) return;
          final panenData = Map<dynamic, dynamic>.from(value);
          final tanggalRaw = panenData['tanggal_panen'];
          final tanggal = DateTime.tryParse('${tanggalRaw ?? ''}');
          if (tanggal == null) return;

          final panen = Panen(
            id: panenData['id'] ?? '',
            kandangId: panenData['kandang_id'] ?? '',
            kandangNama: panenData['kandang_nama'] ?? '',
            jumlahTelur: panenData['jumlah_telur'] ?? 0,
            tanggalPanen: tanggal,
            jam: panenData['jam'] ?? '',
            catatan: panenData['catatan'] ?? '',
            jenisPanen: panenData['jenis_panen'],
            sensorSnapshot: panenData['sensor_snapshot'],
            panenSebelumnya: panenData['panen_sebelumnya'],
          );
          _panens.add(panen);
        });
      } else {
        // Fallback legacy structure: /riwayat langsung berisi records + summary.
        final legacySnapshot = await _database.ref('riwayat').get();
        if (legacySnapshot.exists) {
          final legacyData = Map<dynamic, dynamic>.from(
            legacySnapshot.value as Map,
          );
          _panens.clear();

          legacyData.forEach((key, value) {
            if (value is! Map) return;
            final panenData = Map<dynamic, dynamic>.from(value);
            if (!panenData.containsKey('kandang_id')) return;
            final tanggalRaw = panenData['tanggal_panen'];
            final tanggal = DateTime.tryParse('${tanggalRaw ?? ''}');
            if (tanggal == null) return;

            _panens.add(
              Panen(
                id: panenData['id'] ?? '',
                kandangId: panenData['kandang_id'] ?? '',
                kandangNama: panenData['kandang_nama'] ?? '',
                jumlahTelur: panenData['jumlah_telur'] ?? 0,
                tanggalPanen: tanggal,
                jam: panenData['jam'] ?? '',
                catatan: panenData['catatan'] ?? '',
                jenisPanen: panenData['jenis_panen'],
                sensorSnapshot: panenData['sensor_snapshot'],
                panenSebelumnya: panenData['panen_sebelumnya'],
              ),
            );
          });
        }

        _panens.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));

        if (kDebugMode) {
          print('✅ Restored ${_panens.length} panen records from Firebase');
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error restoring panen history: $e');
      }
    }
  }
}
