import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: dotenv.env['APIKEY_WINDOW_WEB']!,
    appId: dotenv.env['APP_ID']!,
    messagingSenderId: dotenv.env['MESS_SENDER_ID']!,
    projectId: dotenv.env['PROJECT_ID']!,
    authDomain: dotenv.env['AUTHDOMAIN'],
    databaseURL: dotenv.env['DATABASEURL'],
    storageBucket: dotenv.env['STORAGE_BUCKET'],
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: dotenv.env['APIKEY_ANDROID']!,
    appId: dotenv.env['APP_ID']!,
    messagingSenderId: dotenv.env['MESS_SENDER_ID']!,
    projectId: dotenv.env['PROJECT_ID']!,
    databaseURL: dotenv.env['DATABASEURL'],
    storageBucket: dotenv.env['STORAGE_BUCKET'],
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: dotenv.env['APIKEY_IOS_MACOS']!,
    appId: dotenv.env['APP_ID']!,
    messagingSenderId: dotenv.env['MESS_SENDER_ID']!,
    projectId: dotenv.env['PROJECT_ID']!,
    databaseURL: dotenv.env['DATABASEURL'],
    storageBucket: dotenv.env['STORAGE_BUCKET'],
    iosBundleId: dotenv.env['IOS_BUNDLE'],
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: dotenv.env['APIKEY_IOS_MACOS']!,
    appId: dotenv.env['APP_ID']!,
    messagingSenderId: dotenv.env['MESS_SENDER_ID']!,
    projectId: dotenv.env['PROJECT_ID']!,
    databaseURL: dotenv.env['DATABASEURL'],
    storageBucket: dotenv.env['STORAGE_BUCKET'],
    iosBundleId: dotenv.env['IOS_BUNDLE'],
  );

  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: dotenv.env['APIKEY_WINDOW_WEB']!,
    appId: dotenv.env['APP_ID']!,
    messagingSenderId: dotenv.env['MESS_SENDER_ID']!,
    projectId: dotenv.env['PROJECT_ID']!,
    authDomain: dotenv.env['AUTHDOMAIN'],
    databaseURL: dotenv.env['DATABASEURL'],
    storageBucket: dotenv.env['STORAGE_BUCKET'],
  );
}
