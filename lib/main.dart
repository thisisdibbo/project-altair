import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/core.dart';
import 'data/repositories/photo_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final options = DefaultFirebaseOptions.currentPlatform;
  final configured = !options.projectId.startsWith('demo-');
  Object? startupError;
  try {
    await Firebase.initializeApp(options: options);
    if (AppConfig.useEmulators) {
      const host = AppConfig.emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
    Photos.reader = PhotoRepository(FirebaseFirestore.instance).read;
  } catch (error) {
    startupError = error;
  }

  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: AltairApp(
        backendReady:
            startupError == null && (configured || AppConfig.useEmulators),
        startupError: startupError,
      ),
    ),
  );
}
