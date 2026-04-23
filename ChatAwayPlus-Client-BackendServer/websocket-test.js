const WebSocket = require('ws');
const readline = require('readline');

const WS_URL = 'ws://192.168.1.19:3200';
const TOKEN = 'YOUR_TEST_TOKEN'; // Replace with a valid JWT token

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('🔌 Connecting to WebSocket server...');
const ws = new WebSocket(WS_URL, {
  perMessageDeflate: false,
  handshakeTimeout: 10000,
  maxPayload: 100 * 1024 * 1024, // 100MB
  headers: {
    'Authorization': `Bearer ${TOKEN}`
  }
});

// Connection opened
ws.on('open', function open() {
  console.log('✅ Connected to WebSocket server');
  promptForInput();
});

// Listen for messages
ws.on('message', function incoming(data) {
  console.log('📨 Received:', data.toString());
});

// Connection closed
ws.on('close', function close(code, reason) {
  console.log(`🔌 Connection closed. Code: ${code}, Reason: ${reason || 'No reason provided'}`);
  process.exit(0);
});

// Error handling
ws.on('error', function error(err) {
  console.error('❌ WebSocket error:', err);
  process.exit(1);
});

// Handle user input
function promptForInput() {
  rl.question('\n> ', (input) => {
    if (input.toLowerCase() === 'exit') {
      ws.close();
      rl.close();
      return;
    }

    // Send the message
    ws.send(JSON.stringify({
      event: 'message',
      data: input
    }));

    // Prompt for next input
    promptForInput();
  });
}

// Handle process termination
process.on('SIGINT', () => {
  console.log('\n👋 Disconnecting...');
  ws.close();
  rl.close();
  process.exit(0);
});
