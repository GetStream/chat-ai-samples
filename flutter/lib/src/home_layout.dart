import 'package:flutter/material.dart';

/// Puts [history] next to [body] on wide screens, like the iOS sample's
/// `NavigationSplitView`, and in an edge-swipe drawer on phones.
///
/// [body] keeps its state when a resize or rotation switches layouts.
class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key, required this.history, required this.body});

  /// From this width on, [history] is a permanent side panel.
  static const splitViewBreakpoint = 720.0;

  static const sidePanelWidth = 300.0;

  /// The conversation list. Close the drawer with `Scaffold.of(context).closeDrawer()`
  /// when picking a conversation; that does nothing in the side panel.
  final Widget history;

  final Widget body;

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  final _bodyKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final body = KeyedSubtree(key: _bodyKey, child: widget.body);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplit = constraints.maxWidth >= HomeLayout.splitViewBreakpoint;
        return Scaffold(
          drawer: isSplit ? null : Drawer(child: SafeArea(child: widget.history)),
          // The composer is in the body rather than `bottomNavigationBar`,
          // because only the body moves up when the keyboard opens.
          body: SafeArea(
            child: isSplit
                ? Row(
                    children: [
                      SizedBox(width: HomeLayout.sidePanelWidth, child: widget.history),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  )
                : body,
          ),
        );
      },
    );
  }
}
