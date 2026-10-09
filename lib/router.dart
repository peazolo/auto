import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/alerts.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/dashboard.dart';
import 'screens/diagnose/chat_list.dart';
import 'screens/diagnose/chat_screen.dart';
import 'screens/documents/document_detail.dart';
import 'screens/documents/document_form.dart';
import 'screens/documents/documents_list.dart';
import 'screens/maintenance/maintenance_screen.dart';
import 'screens/maintenance/task_form.dart';
import 'screens/settings.dart';
import 'screens/shell.dart';
import 'screens/vehicles/vehicle_detail.dart';
import 'screens/vehicles/vehicle_form.dart';
import 'screens/vehicles/vehicles_list.dart';

/// Re-runs router redirects when the auth state changes, and opens the
/// "choose a new password" screen when the user arrives from a reset email.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.passwordRecovery) recovering = true;
      notifyListeners();
    });
  }
  late final StreamSubscription<AuthState> _sub;
  bool recovering = false;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _auth = _AuthListenable();
final _rootKey = GlobalKey<NavigatorState>();

const _publicRoutes = {'/welcome', '/login', '/signup', '/forgot-password'};

String? qp(GoRouterState s, String key) => s.uri.queryParameters[key];

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  refreshListenable: _auth,
  redirect: (context, state) {
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    final loc = state.matchedLocation;
    if (_auth.recovering && signedIn) {
      return loc == '/reset-password' ? null : '/reset-password';
    }
    if (!signedIn) return _publicRoutes.contains(loc) ? null : '/welcome';
    if (_publicRoutes.contains(loc)) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
    GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
    GoRoute(
      path: '/reset-password',
      builder: (_, _) => ResetPasswordScreen(onDone: () => _auth.recovering = false),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesScreen(), routes: [
            GoRoute(path: 'new', parentNavigatorKey: _rootKey, builder: (_, s) => VehicleFormScreen(welcome: qp(s, 'welcome') == '1')),
            GoRoute(path: ':id', builder: (_, s) => VehicleDetailScreen(id: s.pathParameters['id']!), routes: [
              GoRoute(path: 'edit', parentNavigatorKey: _rootKey, builder: (_, s) => VehicleFormScreen(id: s.pathParameters['id'])),
            ]),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/maintenance', builder: (_, s) => MaintenanceScreen(vehicleId: qp(s, 'vehicle')), routes: [
            GoRoute(path: 'new', parentNavigatorKey: _rootKey, builder: (_, s) => TaskFormScreen(vehicleId: qp(s, 'vehicle'))),
            GoRoute(path: ':id/edit', parentNavigatorKey: _rootKey, builder: (_, s) => TaskFormScreen(id: s.pathParameters['id'])),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/documents', builder: (_, s) => DocumentsScreen(vehicleId: qp(s, 'vehicle')), routes: [
            GoRoute(path: 'new', parentNavigatorKey: _rootKey, builder: (_, s) => DocumentFormScreen(vehicleId: qp(s, 'vehicle'))),
            GoRoute(path: ':id', builder: (_, s) => DocumentDetailScreen(id: s.pathParameters['id']!), routes: [
              GoRoute(path: 'edit', parentNavigatorKey: _rootKey, builder: (_, s) => DocumentFormScreen(id: s.pathParameters['id'])),
            ]),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/diagnose', builder: (_, _) => const ChatListScreen(), routes: [
            GoRoute(path: 'new', parentNavigatorKey: _rootKey, builder: (_, s) => ChatScreen(vehicleId: qp(s, 'vehicle'))),
            GoRoute(path: ':id', parentNavigatorKey: _rootKey, builder: (_, s) => ChatScreen(chatId: s.pathParameters['id'])),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);
