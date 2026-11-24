import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/home_layout.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeLayout(history: Text('History'), body: _Counter()),
      ),
    );
  }

  testWidgets('a phone keeps the history in a drawer', (tester) async {
    await pumpAt(tester, 400);

    expect(find.text('History'), findsNothing);
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('a wide screen shows the history next to the conversation', (tester) async {
    await pumpAt(tester, 1000);

    expect(find.text('History'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(tester.state<ScaffoldState>(find.byType(Scaffold)).hasDrawer, isFalse);
  });

  testWidgets('the split view starts exactly at the breakpoint', (tester) async {
    await pumpAt(tester, HomeLayout.splitViewBreakpoint - 1);
    expect(find.text('History'), findsNothing);

    tester.view.physicalSize = const Size(HomeLayout.splitViewBreakpoint, 900);
    await tester.pump();
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('going back to narrow moves the history into the drawer', (tester) async {
    await pumpAt(tester, 1000);
    await tester.tap(find.byType(TextButton));

    tester.view.physicalSize = const Size(400, 900);
    await tester.pump();

    expect(find.text('History'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('the conversation keeps its state across the switch', (tester) async {
    await pumpAt(tester, 400);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    tester.view.physicalSize = const Size(1000, 900);
    await tester.pump();

    expect(find.text('History'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => setState(() => _count++), child: Text('$_count'));
}
