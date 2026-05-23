import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/trips/screens/home_screen.dart';
import '../../features/trips/screens/trip_form_screen.dart';
import '../../features/trips/screens/trip_detail_screen.dart';
import '../../features/itinerary/screens/stop_form_screen.dart';
import '../../features/expenses/screens/expense_form_screen.dart';
import '../../features/maps/screens/trip_map_screen.dart';
import '../../features/maps/screens/ride_tracking_screen.dart';
import '../../features/maps/screens/trip_replay_screen.dart';
import '../../features/maps/screens/offline_map_screen.dart';
import '../../features/maps/screens/region_picker_screen.dart';
import '../../features/statistics/screens/statistics_screen.dart';
import '../../features/settings/settings_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/trip/new',
        builder: (context, state) => const TripFormScreen(),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TripDetailScreen(tripId: id);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TripFormScreen(tripId: id);
            },
          ),
          GoRoute(
            path: 'stop/new',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StopFormScreen(tripId: id);
            },
          ),
          GoRoute(
            path: 'stop/:stopId',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final stopId = state.pathParameters['stopId']!;
              return StopFormScreen(tripId: id, stopId: stopId);
            },
          ),
          GoRoute(
            path: 'expense/new',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ExpenseFormScreen(tripId: id);
            },
          ),
          GoRoute(
            path: 'expense/:expenseId',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final expenseId = state.pathParameters['expenseId']!;
              return ExpenseFormScreen(tripId: id, expenseId: expenseId);
            },
          ),
          GoRoute(
            path: 'map',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TripMapScreen(tripId: id);
            },
          ),
          GoRoute(
            path: 'replay',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TripReplayScreen(tripId: id);
            },
          ),
          GoRoute(
            path: 'ride',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final append =
                  state.uri.queryParameters['append'] == 'true';
              return RideTrackingScreen(
                tripId: id,
                appendMode: append,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/offline-maps',
        builder: (context, state) => const OfflineMapScreen(),
        routes: [
          GoRoute(
            path: 'download',
            builder: (context, state) => const RegionPickerScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
