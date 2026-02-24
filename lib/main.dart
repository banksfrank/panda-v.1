import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/nav.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/services/discovery_service.dart';
import 'package:panda_dating_app/services/match_service.dart';
import 'package:panda_dating_app/services/chat_service.dart';
import 'package:panda_dating_app/services/event_service.dart';
import 'package:panda_dating_app/services/live_room_service.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());

    return Material(
      color: PandaColors.bgPrimary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(details.exceptionAsString()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    await SupabaseBootstrap.initialize();
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint(stack.toString());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DiscoveryService()),
        ChangeNotifierProvider(create: (_) => MatchService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => EventService()),
        ChangeNotifierProvider(create: (_) => LiveRoomService()),
      ],
      child: MaterialApp.router(
        title: 'Panda Dating App',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
