import 'package:chataway_plus/core/connectivity/root_scaffold_messager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool _isBannerShown = false;

  @override
  Widget build(BuildContext context) {
    // Watch the stream provider but don't rebuild UI content (we only need the change)
    final asyncOnline = ref.watch(internetStatusStreamProvider);

    // When the provider emits, schedule a post-frame callback to handle banner display.
    asyncOnline.whenData((isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleConnectivityChange(isOnline);
      });
    });

    // This widget intentionally returns nothing visible; it just listens.
    return const SizedBox.shrink();
  }

  void _handleConnectivityChange(bool isOnline) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    if (!isOnline && !_isBannerShown) {
      _isBannerShown = true;

      messenger.showMaterialBanner(
        MaterialBanner(
          content: const Text(
            'you are offline.please connect to the internet.',
          ),
          leading: const Icon(Icons.wifi_off),
          backgroundColor: Colors.orange.shade50,
          actions: [
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                _isBannerShown = false;
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (isOnline && _isBannerShown) {
      messenger.hideCurrentMaterialBanner();
      _isBannerShown = false;

      // Optional: quick feedback when coming back online
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Back online'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }
}
