import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'models.dart';
import 'fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  UserSettings? _settings;
  UserProfile? _profile;
  bool _isLoading = true;

  User? get currentUser => _user;
  UserSettings? get settings => _settings;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  StreamSubscription<User?>? _authSubscription;

  AuthProvider() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _user = firebaseUser;
    if (firebaseUser == null) {
      _settings = null;
      _profile = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await fetchUserData();
      await _registerFcmToken();
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _registerFcmToken() async {
    if (_user == null) return;
    try {
      final token = await FcmService.getToken();
      if (token != null) {
        await updateFCMToken(token);
        // Listen for future token refreshes
        FcmService.listenToTokenRefresh(updateFCMToken);
      }
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  Future<void> fetchUserData() async {
    if (_user == null) return;
    final uid = _user!.uid;

    final profileDoc = await _db.collection('users').doc(uid).collection('profile').doc('info').get();
    if (profileDoc.exists) {
      _profile = UserProfile.fromJson(profileDoc.data()!);
    } else {
      _profile = UserProfile(
        displayName: _user!.displayName ?? _user!.email?.split('@').first ?? 'User',
        email: _user!.email ?? '',
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).collection('profile').doc('info').set(_profile!.toJson());
    }

    final settingsDoc = await _db.collection('users').doc(uid).collection('settings').doc('prefs').get();
    if (settingsDoc.exists) {
      _settings = UserSettings.fromJson(settingsDoc.data()!);
    } else {
      _settings = UserSettings(
        blockedApps: [],
        onboardingComplete: false,
        usagePermissionGranted: false,
      );
      await _db.collection('users').doc(uid).collection('settings').doc('prefs').set(_settings!.toJson());
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(String email, String password, String displayName) async {
    _isLoading = true;
    notifyListeners();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(displayName);

      // Create Firestore doc structure
      final uid = cred.user!.uid;
      _profile = UserProfile(
        displayName: displayName,
        email: email,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).collection('profile').doc('info').set(_profile!.toJson());

      _settings = UserSettings(
        blockedApps: [],
        onboardingComplete: false,
        usagePermissionGranted: false,
      );
      await _db.collection('users').doc(uid).collection('settings').doc('prefs').set(_settings!.toJson());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final googleUser = await GoogleSignIn().signIn();
      final googleAuth = await googleUser?.authentication;
      if (googleAuth != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final cred = await _auth.signInWithCredential(credential);
        
        final uid = cred.user!.uid;
        // Verify profile and settings exist
        final profileDoc = await _db.collection('users').doc(uid).collection('profile').doc('info').get();
        if (!profileDoc.exists) {
          _profile = UserProfile(
            displayName: cred.user!.displayName ?? cred.user!.email?.split('@').first ?? 'User',
            email: cred.user!.email ?? '',
            createdAt: DateTime.now(),
          );
          await _db.collection('users').doc(uid).collection('profile').doc('info').set(_profile!.toJson());
        }

        final settingsDoc = await _db.collection('users').doc(uid).collection('settings').doc('prefs').get();
        if (!settingsDoc.exists) {
          _settings = UserSettings(
            blockedApps: [],
            onboardingComplete: false,
            usagePermissionGranted: false,
          );
          await _db.collection('users').doc(uid).collection('settings').doc('prefs').set(_settings!.toJson());
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(UserSettings settings) async {
    if (_user == null) return;
    _settings = settings;
    notifyListeners();
    await _db
        .collection('users')
        .doc(_user!.uid)
        .collection('settings')
        .doc('prefs')
        .set(settings.toJson());
  }

  Future<void> updateOnboardingComplete(bool complete) async {
    if (_settings == null || _user == null) return;
    final updated = UserSettings(
      blockedApps: _settings!.blockedApps,
      onboardingComplete: complete,
      usagePermissionGranted: _settings!.usagePermissionGranted,
    );
    await updateSettings(updated);
  }

  Future<void> updateFCMToken(String token) async {
    if (_user == null) return;
    await _db
        .collection('users')
        .doc(_user!.uid)
        .collection('profile')
        .doc('info')
        .update({'fcmToken': token});
    if (_profile != null) {
      _profile = UserProfile(
        displayName: _profile!.displayName,
        email: _profile!.email,
        createdAt: _profile!.createdAt,
        fcmToken: token,
      );
      notifyListeners();
    }
  }
}
