import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:flutter/material.dart';

Future<void> handleStarMessage({
  required BuildContext context,
  required ChatEngineService unifiedChatService,
  required String chatId,
  required bool isCurrentlyStarred,
}) async {
  final isOnline = unifiedChatService.isOnline;
  final isSocketConnected = unifiedChatService.isConnectedToServer;
  if (!isOnline || !isSocketConnected) {
    AppSnackbar.showOfflineWarning(
      context,
      "You're offline. Check your connection",
    );
    return;
  }

  final ok = isCurrentlyStarred
      ? await unifiedChatService.unstarMessage(chatId: chatId)
      : await unifiedChatService.starMessage(chatId: chatId);

  if (!context.mounted) return;

  if (!ok) {
    await AppSnackbar.showError(
      context,
      isCurrentlyStarred
          ? 'Failed to unstar message'
          : 'Failed to star message',
    );
    return;
  }

  await AppSnackbar.show(
    context,
    isCurrentlyStarred ? 'Message unstarred' : 'Message starred',
  );
}
