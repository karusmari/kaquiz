import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/api_service.dart';
import 'provider/profile_provider.dart';
import 'provider/map_state_provider.dart';
import 'provider/friends_provider.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  runApp(
    MultiProvider( // Provide all our models to the widget tree
      providers: [
        Provider(create: (_) => ApiService()), 
        ChangeNotifierProvider(
          create: (context) => FriendsModel(context.read<ApiService>()), 
        ),
        ChangeNotifierProvider(
          create: (context) => ProfileProvider(context.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => MapStateModel(context.read<ApiService>()),
        ),
      ],
      child: const KaQuizApp(),
    ),
  );
}

class KaQuizApp extends StatelessWidget {
  const KaQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhereUAt?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();

  late final Future<Widget> _initialScreen = _resolveInitialScreen();

  Future<Widget> _resolveInitialScreen() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        return const LoginScreen();
      }

      final profile = await _apiService.getMyProfile();
      if (profile == null) {
        await _storage.delete(key: 'jwt_token');
        return const LoginScreen();
      }

      return MapScreen(initialAvatarUrl: profile['avatar'] as String?);
    } catch (_) {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
