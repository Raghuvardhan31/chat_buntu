import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

class TestSocketPage extends ConsumerStatefulWidget {
  const TestSocketPage({super.key});

  @override
  ConsumerState<TestSocketPage> createState() => _TestSocketPageState();
}

class _TestSocketPageState extends ConsumerState<TestSocketPage> {
  final ChatEngineService _hybrid = ChatEngineService.instance;
  final TokenSecureStorage _tokenStorage = TokenSecureStorage();

  bool isConnected = false;
  String log = '🧩 Socket test started...\n';

  @override
  void initState() {
    super.initState();
    _connectAndTest();
  }

  Future<void> _connectAndTest() async {
    setState(() => log += '\nConnecting to server...\n');
    final currentUserId = await _tokenStorage.getCurrentUserIdUUID();
    if (currentUserId == null || currentUserId.isEmpty) {
      setState(() {
        log += '❌ Missing currentUserId (login required)\n';
      });
      return;
    }

    final connected = await _hybrid.initialize(currentUserId);
    setState(() {
      isConnected = connected;
      log += connected
          ? '✅ Connected successfully!\n'
          : '❌ Connection failed.\n';
    });

    if (!connected) return;

    // Listen for new messages
    _hybrid.globalNewMessageStream.listen((msg) {
      setState(() {
        log += '📩 Message received: ${msg.message}\n';
      });
    });

    // Listen for message sent confirmations
    _hybrid.messageSentStream.listen((msg) {
      setState(() {
        log += '📤 Message sent confirmed: ${msg.message}\n';
      });
    });

    // Wait 3 seconds and send a test ping
    await Future.delayed(const Duration(seconds: 3));
    setState(() => log += '⚙️ Sending test ping...\n');

    final receiverId = 'receiver_test_456';

    await _hybrid.sendMessage(
      messageText: 'Hello 👋 from Flutter test!',
      receiverId: receiverId,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Socket Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            log,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connectAndTest,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
