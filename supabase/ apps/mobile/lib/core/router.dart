import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/bookings/booking_flow_screen.dart';
import '../features/bookings/my_bookings_screen.dart';
import '../features/home/venues_home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/staff/staff_screen.dart';
import '../features/venues/presentation/venue_detail_screen.dart';
import '../l10n/generated/app_localizations.dart';

const _tabs = ['/', '/bookings', '/notifications', '/profile'];

final routerProvider = Provider<GoRouter>((ref) {
  // The router is built once; sign-in/out only asks it to re-run redirect.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(authControllerProvider);
      final path = state.uri.path;
      final needsAuth = path == '/bookings' || path == '/notifications' || path == '/staff' || path.endsWith('/book');
      if (needsAuth && user == null) {
        return '/sign-in?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (path == '/sign-in' && user != null) return state.uri.queryParameters['from'] ?? '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => _Shell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const VenuesHomeScreen()),
          GoRoute(path: '/bookings', builder: (_, __) => const MyBookingsScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/venue/:id', builder: (_, state) => VenueDetailScreen(venueId: state.pathParameters['id']!)),
      GoRoute(
        path: '/venue/:id/book',
        builder: (_, state) => BookingFlowScreen(
          venueId: state.pathParameters['id']!,
          initialTableId: state.uri.queryParameters['table'],
        ),
      ),
      GoRoute(path: '/sign-in', builder: (_, state) => SignInScreen(from: state.uri.queryParameters['from'])),
      GoRoute(path: '/staff', builder: (_, __) => const StaffScreen()),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final index = _tabs.contains(location) ? _tabs.indexOf(location) : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.nightlife_outlined), selectedIcon: const Icon(Icons.nightlife), label: l.navVenues),
          NavigationDestination(icon: const Icon(Icons.event_seat_outlined), selectedIcon: const Icon(Icons.event_seat), label: l.navBookings),
          NavigationDestination(icon: const Icon(Icons.notifications_none), selectedIcon: const Icon(Icons.notifications), label: l.navAlerts),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.navProfile),
        ],
      ),
    );
  }
}
