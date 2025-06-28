import 'package:go_router/go_router.dart';
import 'package:thai_herbal_app/features/authentication/presentation/login_screen.dart';
import 'package:thai_herbal_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:thai_herbal_app/features/gacp_certification/presentation/certification_screen.dart';
import 'package:thai_herbal_app/features/track_and_trace/presentation/track_screen.dart';
import 'package:thai_herbal_app/features/knowledge_graph/presentation/knowledge_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'certification',
            name: 'certification',
            builder: (context, state) => const CertificationScreen(),
          ),
          GoRoute(
            path: 'track/:batchId',
            name: 'track',
            builder: (context, state) {
              final batchId = state.pathParameters['batchId']!;
              return TrackScreen(batchId: batchId);
            },
          ),
          GoRoute(
            path: 'knowledge',
            name: 'knowledge',
            builder: (context, state) => const KnowledgeScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      // Add authentication logic here
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}
