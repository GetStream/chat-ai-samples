import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// A thin banner shown while the realtime connection is down.
///
/// Without it a dropped connection looks like the assistant misbehaving:
/// replies stay empty and client-tool invocations are missed, since both
/// arrive as channel events. Takes no space while connected.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return StreamConnectionStatusBuilder(
      statusBuilder: (context, status) {
        final banner = switch (status) {
          ConnectionStatus.connected => null,
          ConnectionStatus.connecting => (
              message: 'Reconnecting…',
              background: colors.secondaryContainer,
              foreground: colors.onSecondaryContainer,
            ),
          ConnectionStatus.disconnected => (
              message: 'Offline — new messages and AI actions may not arrive',
              background: colors.errorContainer,
              foreground: colors.onErrorContainer,
            ),
        };

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: switch (banner) {
            null => const SizedBox(width: double.infinity),
            final banner => Container(
                width: double.infinity,
                color: banner.background,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (status == ConnectionStatus.connecting) ...[
                      SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: banner.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        banner.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: banner.foreground, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          },
        );
      },
    );
  }
}
