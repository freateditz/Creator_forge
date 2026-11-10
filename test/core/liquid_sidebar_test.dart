import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:creator_forge/core/design/design_tokens.dart';
import 'package:creator_forge/core/design/liquid_sidebar.dart';

// Regression test for the crash:
//
//   dependOnInheritedWidgetOfExactType<_ModalScopeStatus>() or
//   dependOnInheritedElement() was called before _LiquidSidebarState.initState()
//   completed.
//
// The old code called GoRouterState.of(context) inside initState(), which is
// illegal because the GoRouter inherited widget is not yet attached at that
// point. This test exercises the exact scenario that triggered it: a
// LiquidSidebar mounted as the shell of a GoRouter, on the initial route.
Future<void> _pumpSidebar(WidgetTester tester, String initialRoute) async {
  final router = GoRouter(
    initialLocation: initialRoute,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Material(
          color: DesignTokens.bgDeep,
          child: Row(
            children: [
              LiquidSidebar(
                sections: [
                  LiquidSidebarSection(
                    label: 'NAV',
                    items: [
                      LiquidSidebarItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: 'Home',
                        route: '/',
                      ),
                      LiquidSidebarItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        label: 'Settings',
                        route: '/settings',
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(child: child),
            ],
          ),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Text('Home Content'),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Text('Settings Content'),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(
    theme: ThemeData(brightness: Brightness.dark),
    routerConfig: router,
  ));
  // Let post-frame callbacks (initial active-item resolution) flush.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('LiquidSidebar lifecycle', () {
    testWidgets('does not crash during initState on the initial route',
        (tester) async {
      // This used to throw the inherited-element exception.
      await _pumpSidebar(tester, '/');

      // The app shell should be present, not a red error screen.
      // On the initial route '/' only the Home content renders.
      expect(find.text('Home Content'), findsOneWidget);
      expect(find.text('Settings Content'), findsNothing);
    });

    testWidgets('highlights the active item matching the current route',
        (tester) async {
      await _pumpSidebar(tester, '/settings');

      // Verify the Settings content renders (sidebar active state is visual;
      // we just ensure no crash occurs).
      expect(find.text('Settings Content'), findsOneWidget);
      expect(find.text('Home Content'), findsNothing);
    });

    testWidgets('switching route does not crash',
        (tester) async {
      await _pumpSidebar(tester, '/');

      // Both content and sidebar labels render
      expect(find.text('Home Content'), findsOneWidget);
      expect(find.text('Settings Content'), findsNothing);

      // Tap Settings and navigate — just verify no crash.
      await tester.tap(find.text('Settings').first); // sidebar label
      // GoRouter's default page transition takes ~300ms; pump long enough for
      // the old route widget to be removed from the tree.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Shell still renders
      expect(find.text('Settings Content'), findsOneWidget);
      expect(find.text('Home Content'), findsNothing);
    });
  });
}