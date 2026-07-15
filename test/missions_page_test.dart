import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xo_arena_neon_clash/screens/missions/missions_page.dart';
import 'package:xo_arena_neon_clash/screens/missions/mission_widgets.dart';
import 'package:xo_arena_neon_clash/services/mission_service.dart';

/// Renders the Missions page end-to-end (English fallback l10n, no Firebase).
/// A RenderFlex overflow would fail this test, so it also guards layout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MissionsPage renders daily then weekly cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MissionService.instance.resetForTest();
    await MissionService.instance.init();

    await tester.pumpWidget(const MaterialApp(home: MissionsPage()));
    await tester.pump();

    // Daily tab: mission cards present, badge builds. The header title is now
    // localized (English fallback locale here) instead of a hardcoded Arabic
    // string, so it must read 'MISSIONS'.
    expect(find.byType(MissionCard), findsWidgets);
    expect(find.text('MISSIONS'), findsOneWidget);

    // Switch to the weekly tab; it should render tiered cards.
    await tester.tap(find.text('WEEKLY'));
    await tester.pump();
    expect(find.byType(WeeklyMissionCard), findsWidgets);
  });

  testWidgets('MissionBadge hides at 0 and shows a count', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MissionBadge(count: 0)))));
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MissionBadge(count: 3)))));
    expect(find.text('3'), findsOneWidget);
  });
}
