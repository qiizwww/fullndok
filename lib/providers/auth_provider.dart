import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _firebaseAuth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> signup(String email, String password, String name) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update user profile with name
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();

      _user = _firebaseAuth.currentUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan tak terduga. Coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = _firebaseAuth.currentUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan tak terduga. Coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      _isLoading = true;
      await _firebaseAuth.signOut();
      _user = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error logging out';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firebaseAuth.sendPasswordResetEmail(email: email);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan tak terduga. Coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'invalid-email':
        return 'Email tidak valid.';
      case 'user-disabled':
        return 'Akun telah dinonaktifkan.';
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
        return 'Password salah.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'operation-not-allowed':
        return 'Metode autentikasi ini tidak diizinkan. Aktifkan Email/Password di Firebase Console.';
      case 'network-request-failed':
        return 'Gagal tersambung ke jaringan. Periksa koneksi internet Anda.';
      case 'app-not-authorized':
      case 'invalid-api-key':
        return 'Konfigurasi Firebase tidak benar. Periksa konfigurasi `google-services.json` / `FirebaseOptions`.';
      default:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
