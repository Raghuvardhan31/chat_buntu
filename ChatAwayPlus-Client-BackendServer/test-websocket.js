const io = require('socket.io-client');
const readline = require('readline');

// Configuration
const SERVER_URL = 'http://192.168.1.2:3200'; // Update with your server URL
const TEST_USER_1 = 'd363a719-2522-4a8b-a299-201f82ea52dc';
const TEST_USER_2 = 'a4f81491-7e28-4632-b9a8-d250905459bb';

// Set up readline for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Function to create a test user
function createTestUser(userId) {
  const socket = io(SERVER_URL, {
    transports: ['websocket'],
    autoConnect: true,
    reconnection: false
  });

  socket.on('connect', () => {
    console.log(`[${userId}] Connected to server`);

    // Authenticate
    socket.emit('authenticate', {
      userId: userId,
      token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJiZmFjMjg0My05ZjAyLTRhNjQtYjA1YS02ZjVlNGVjNDdhNjIiLCJtb2JpbGVObyI6Ijk5OTk5OTk5OTIiLCJpYXQiOjE3NTM4Njg1MDUsImV4cCI6MTc1NDQ3MzMwNX0.E3js3u-be7nKzHb2FqMMlHQJcTF5FfRKXO7eoHkgw3w`,
      loadHistory: false
    });
  });

  socket.on('authenticated', (data) => {
    console.log(`[${userId}] Authenticated:`, data);
  });

  socket.on('new-message', (message) => {
    console.log(`\n[${userId}] New message from ${message.senderId}: ${message.message}`);
    showPrompt();
  });

  socket.on('profile-updated', (data) => {
    console.log(`\n[${userId}] 🔔 Profile Updated Event Received:`);
    console.log(`   User ID: ${data.userId}`);
    console.log(`   Updated Fields:`, JSON.stringify(data.updatedFields, null, 2));
    showPrompt();
  });

  socket.on('disconnect', () => {
    console.log(`[${userId}] Disconnected from server`);
  });

  socket.on('connect_error', (error) => {
    console.error(`[${userId}] Connection error:`, error.message);
  });

  return socket;
}

// Function to show command prompt
function showPrompt() {
  rl.question('\nEnter command (1: Send as User1, 2: Send as User2, q: Quit): ', (answer) => {
    if (answer === 'q') {
      console.log('Exiting...');
      process.exit(0);
    } else if (answer === '1') {
      sendMessage(user1, TEST_USER_1, TEST_USER_2);
    } else if (answer === '2') {
      sendMessage(user2, TEST_USER_2, TEST_USER_1);
    } else {
      console.log('Invalid command');
      showPrompt();
    }
  });
}

// Function to send a message
function sendMessage(socket, senderId, receiverId) {
  rl.question(`[${senderId}] Enter message for ${receiverId}: `, (message) => {
    if (message) {
      socket.emit('private-message', {
        senderId: senderId,
        receiverId: receiverId,
        message: message
      });
      console.log(`[${senderId}] Message sent to ${receiverId}`);
    }
    showPrompt();
  });
}

console.log('Starting WebSocket test...');
console.log('Creating test users...');

// Create two test users
const user1 = createTestUser(TEST_USER_1);
const user2 = createTestUser(TEST_USER_2);

// Handle process exit
process.on('SIGINT', () => {
  console.log('\nClosing connections...');
  user1.close();
  user2.close();
  rl.close();
  process.exit(0);
});

console.log('\nTest commands:');
console.log('1 - Send message as User1');
console.log('2 - Send message as User2');
console.log('q - Quit\n');

// Start the prompt
setTimeout(showPrompt, 2000); // Wait for connections to establish
