import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:thai_herbal_app/features/authentication/presentation/login_screen.dart';
import 'package:thai_herbal_app/features/authentication/data/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  testWidgets('Login screen validation', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Try login without entering credentials
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pump();
    
    expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
  });

  testWidgets('Successful login navigation', (WidgetTester tester) async {
    final mockAuth = MockAuthRepository();
    when(mockAuth.login(any, any)).thenAnswer((_) async => true);
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
        child: MaterialApp(
          routes: {
            '/dashboard': (context) => const Scaffold(body: Text('Dashboard')),
          },
          home: LoginScreen(),
        ),
      ),
    );

    // Enter valid credentials
    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
