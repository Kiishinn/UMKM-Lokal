import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // Import Firebase App Check
import 'package:provider/provider.dart';
import 'package:umkmproject/bottom_navbar.dart';
import 'package:umkmproject/firebase_options.dart';
import 'package:umkmproject/screens/home_screen.dart';
import 'package:umkmproject/screens/login_screen.dart';
import 'package:umkmproject/screens/posting_screen.dart';
import 'package:umkmproject/screens/signup_screen.dart';
import 'package:umkmproject/theme_provider.dart';  // Import ThemeProvider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Initialize Firebase App Check with Debug Token
    FirebaseAppCheck firebaseAppCheck = FirebaseAppCheck.instance;
    await firebaseAppCheck.activate();
    await firebaseAppCheck.setTokenAutoRefreshEnabled(true); // Enable token auto-refresh
    
    // Run the app
    runApp(
      ChangeNotifierProvider(create: (_) => ThemeProvider(), child: MyApp()),
    );
  } catch (e) {
    runApp(
      ChangeNotifierProvider(create: (_) => ThemeProvider(), child: MyAppError(error: e.toString())),
    );
    print("Error initializing Firebase: $e");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Umkm Lokal',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/LoginScreen',
      routes: {
        '/LoginScreen': (context) => LoginScreen(),
        '/SignupScreen': (context) => SignupScreen(),
        '/HomeScreen': (context) => HomeScreen(),
        '/BottomNavBar': (context) => BottomNavBar(),
        '/PostingScreen': (context) => PostingScreen(),
      },
    );
  }
}

class MyAppError extends StatelessWidget {
  final String error;

  MyAppError({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Error'),
        ),
        body: Center(
          child: Text('Error initializing Firebase: $error'),
        ),
      ),
    );
  }
}