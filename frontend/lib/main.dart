import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'models/profile_model.dart';
import 'models/map_state_model.dart';
import 'models/friends_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(
          create: (context) => FriendsModel(context.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => ProfileModel(context.read<ApiService>()),
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
      title: 'KaQuiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}
