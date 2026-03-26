import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/penjadwalan_model.dart';

class PenjadwalanProvider extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late DatabaseReference _penjadwalanRef;

  List<Penjadwalan> _penjadwalans = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<Penjadwalan> get penjadwalans => _penjadwalans;
  bool get isLoading => _isLoading;

  /// Initialize provider dengan user ID dan load data dari Firebase
  Future<void> initializeWithUser(String userId) async {
    _penjadwalanRef = _database.ref('kontrol/penjadwalan');

    try {
      // Pastikan jadwal awal tersedia agar login pertama langsung ada isi.
      await _ensureInitialPenjadwalanData();
    } catch (e) {
      if (kDebugMode) {
        print('Warning ensuring penjadwalan initial data: $e');
      }
    }

    // Clear previous listener
    await _subscription?.cancel();

    // Load data dari Firebase dengan real-time listener
    _subscription = _penjadwalanRef.onValue.listen(
      (event) {
        try {
          if (event.snapshot.exists && event.snapshot.value is Map) {
            final data =
                Map<dynamic, dynamic>.from(event.snapshot.value as Map);
            _penjadwalans =
                data.entries.where((entry) => entry.value is Map).map((entry) {
              return Penjadwalan.fromJson({
                'id': entry.key,
                ...Map<dynamic, dynamic>.from(entry.value as Map),
              });
            }).toList();

            // Sort berdasarkan nomor untuk urutan yang rapi
            _penjadwalans.sort((a, b) {
              int numA =
                  int.tryParse(a.id.replaceAll('penjadwalan', '')) ?? 999;
              int numB =
                  int.tryParse(b.id.replaceAll('penjadwalan', '')) ?? 999;
              return numA.compareTo(numB);
            });
          } else {
            _penjadwalans = [];
          }
          _isLoading = false;
          notifyListeners();
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing penjadwalan data: $e');
          }
          _isLoading = false;
          notifyListeners();
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Error listening penjadwalan data: $error');
        }
        _isLoading = false;
        notifyListeners();
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _ensureInitialPenjadwalanData() async {
    final snapshot = await _penjadwalanRef.get();
    if (snapshot.exists) return;

    await _penjadwalanRef.set({
      'penjadwalan1': {
        'kandangId': 'kandang1',
        'kandangNama': 'Kandang 1',
        'jam': '09:00',
        'durasi': '30 menit',
        'keterangan': 'Panen pagi',
        'aktif': true,
      },
      'penjadwalan2': {
        'kandangId': 'kandang2',
        'kandangNama': 'Kandang 2',
        'jam': '15:00',
        'durasi': '30 menit',
        'keterangan': 'Panen sore',
        'aktif': true,
      },
    });
  }

  /// Get next penjadwalan number (penjadwalan1, penjadwalan2, dst)
  String _getNextPenjadwalanKey() {
    if (_penjadwalans.isEmpty) return 'penjadwalan1';

    int maxNum = 0;
    for (var p in _penjadwalans) {
      int num = int.tryParse(p.id.replaceAll('penjadwalan', '')) ?? 0;
      if (num > maxNum) maxNum = num;
    }
    return 'penjadwalan${maxNum + 1}';
  }

  /// Clear semua data saat logout
  Future<void> clearData() async {
    await _subscription?.cancel();
    _penjadwalans = [];
    _isLoading = true;
    notifyListeners();
  }

  List<Penjadwalan> getPenjadwalanByKandang(String kandangId) {
    return _penjadwalans.where((p) => p.kandangId == kandangId).toList();
  }

  Future<void> addPenjadwalan(
    String kandangId,
    String kandangNama,
    String jam,
    String durasi,
    String keterangan,
  ) async {
    try {
      final newId = _getNextPenjadwalanKey();

      final newPenjadwalan = Penjadwalan(
        id: newId,
        kandangId: kandangId,
        kandangNama: kandangNama,
        jam: jam,
        durasi: durasi,
        keterangan: keterangan,
        aktif: true,
      );

      await _penjadwalanRef.child(newId).set(newPenjadwalan.toJson());
      // Data akan automatically di-update via listener
    } catch (e) {
      print('Error adding penjadwalan: $e');
    }
  }

  Future<void> updatePenjadwalan(
    String id,
    String jam,
    String durasi,
    String keterangan,
    bool aktif,
  ) async {
    try {
      final index = _penjadwalans.indexWhere((p) => p.id == id);
      if (index != -1) {
        final updated = Penjadwalan(
          id: id,
          kandangId: _penjadwalans[index].kandangId,
          kandangNama: _penjadwalans[index].kandangNama,
          jam: jam,
          durasi: durasi,
          keterangan: keterangan,
          aktif: aktif,
        );

        await _penjadwalanRef.child(id).set(updated.toJson());
        // Data akan automatically di-update via listener
      }
    } catch (e) {
      print('Error updating penjadwalan: $e');
    }
  }

  Future<void> deletePenjadwalan(String id) async {
    try {
      await _penjadwalanRef.child(id).remove();
      // Data akan automatically di-update via listener
    } catch (e) {
      print('Error deleting penjadwalan: $e');
    }
  }

  Future<void> togglePenjadwalan(String id) async {
    try {
      final index = _penjadwalans.indexWhere((p) => p.id == id);
      if (index != -1) {
        final updated = Penjadwalan(
          id: _penjadwalans[index].id,
          kandangId: _penjadwalans[index].kandangId,
          kandangNama: _penjadwalans[index].kandangNama,
          jam: _penjadwalans[index].jam,
          durasi: _penjadwalans[index].durasi,
          keterangan: _penjadwalans[index].keterangan,
          aktif: !_penjadwalans[index].aktif,
        );

        await _penjadwalanRef.child(id).set(updated.toJson());
        // Data akan automatically di-updated via listener
      }
    } catch (e) {
      print('Error toggling penjadwalan: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
