import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xo_arena_neon_clash/screens/intro_screen.dart';

void main() {
  testWidgets('Intro screen renders XO Arena branding',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IntroScreen(
          startupRouteFuture: Future<String>.value('/login'),
          startupRouteBuilder: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('LOGIN')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('XO ARENA'), findsOneWidget);
    expect(find.text('PREMIUM CYBER BATTLES'), findsOneWidget);
  });
}
