import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/kandang_provider.dart';
import 'providers/panen_provider.dart';
import 'providers/penjadwalan_provider.dart';
import 'providers/riwayat_provider.dart';
// import 'services/panen_scheduler.dart';  // TODO: Enable after scheduler fixed
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Realtime DB persistence tidak didukung di semua platform (terutama web).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  }

  // Initialize background scheduler untuk panen otomatis
  // TODO: Enable setelah scheduler stabil
  // await PanenScheduler.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => KandangProvider()),
        ChangeNotifierProvider(create: (_) => PanenProvider()),
        ChangeNotifierProvider(create: (_) => PenjadwalanProvider()),
        ChangeNotifierProvider(create: (_) => TelurProvider()),
      ],
      child: MaterialApp(
        title: 'TelurKu',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF4D03F),
            brightness: Brightness.light,
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/landing': (context) => const LandingPage(),
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignupPage(),
          '/home': (context) => const AuthWrapper(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isLoggedIn) {
          final userId = authProvider.user?.uid;
          if (userId == null) {
            return const LandingPage();
          }
          return HomeBootstrap(userId: userId);
        }

        return const LandingPage();
      },
    );
  }
}

class HomeBootstrap extends StatefulWidget {
  final String userId;

  const HomeBootstrap({super.key, required this.userId});

  @override
  State<HomeBootstrap> createState() => _HomeBootstrapState();
}

class _HomeBootstrapState extends State<HomeBootstrap> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeData();
  }

  Future<void> _initializeData() async {
    final penjadwalanProvider = context.read<PenjadwalanProvider>();
    final kandangProvider = context.read<KandangProvider>();
    final panenProvider = context.read<PanenProvider>();

    await penjadwalanProvider.initializeWithUser(widget.userId);
    await kandangProvider.initializeWithUser(widget.userId);
    await panenProvider.loadTodaySnapshots();
    await panenProvider.restorePanenHistoryFromFirebase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gagal memuat data awal. Coba buka ulang aplikasi.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initFuture = _initializeData();
                        });
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const HomePage();
      },
    );
  }
}
