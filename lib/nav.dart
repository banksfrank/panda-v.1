import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:panda_dating_app/screens/splash_screen.dart';
import 'package:panda_dating_app/screens/auth_screen.dart';
import 'package:panda_dating_app/screens/home_screen.dart';
import 'package:panda_dating_app/screens/onboarding_screen.dart';
import 'package:panda_dating_app/screens/chat_screen.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/screens/events_screen.dart';
import 'package:panda_dating_app/screens/live_rooms_screen.dart';
import 'package:panda_dating_app/screens/live_room_screen.dart';
import 'package:panda_dating_app/screens/admin_seed_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const AuthScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.chat}/:userId',
        name: 'chat',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final extra = state.extra;
          final now = DateTime.now();
          final user = (extra is User)
              ? extra
              : User(
                  id: userId,
                  name: 'Chat',
                  age: 0,
                  bio: '',
                  location: '',
                  city: null,
                  country: null,
                  profession: null,
                  tribe: null,
                  phone: null,
                  dateOfBirth: null,
                  photos: const [],
                  interests: const [],
                  gender: 'Not specified',
                  lookingFor: 'Not specified',
                  createdAt: now,
                  updatedAt: now,
                );
          return MaterialPage(child: ChatScreen(otherUser: user));
        },
      ),
      GoRoute(
        path: AppRoutes.events,
        name: 'events',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const EventsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.liveRooms,
        name: 'liveRooms',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const LiveRoomsScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.liveRoom}/:id',
        name: 'liveRoom',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return MaterialPage(child: LiveRoomScreen(roomId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.adminSeed,
        name: 'adminSeed',
        pageBuilder: (context, state) => const MaterialPage(child: AdminSeedScreen()),
      ),
    ],
  );
}

class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String events = '/events';
  static const String liveRooms = '/live-rooms';
  static const String liveRoom = '/live-room';
  static const String adminSeed = '/admin/seed';
}
