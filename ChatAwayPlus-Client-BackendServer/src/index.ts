import express, { Request, Response, NextFunction } from "express"; 
import { createServer } from "http";
import { Server as SocketIOServer } from "socket.io";
import cors from "cors";
import path from "path";
import fs from "fs";

import sequelize from "./db/config/database";
import userRoutes from "./routes/user.routes";
import authRoutes from "./routes/auth.routes";
import statusRoutes from "./routes/status.routes";
import locationRoutes from "./routes/location.routes";
import setupChatRoutes from "./routes/chat.routes";
import setupMobileChatRoutes from "./routes/mobile-chat.routes";
import blockRoutes from "./routes/block.routes";
import emojiUpdateRoutes from "./routes/emoji-update.routes";
import chatPictureLikeRoutes from "./routes/chat-picture-like.routes";
import imageRoutes from "./routes/image.routes";
import testRoutes from "./routes/test.routes";
import messageReactionRoutes from "./routes/message-reaction.routes";
import storyRoutes from "./routes/story.routes";
import callLogRoutes from "./routes/call-log.routes";
import notificationRoutes from "./routes/notification.routes";
import ChatController from "./controllers/chat.controller";
import { config } from "./config";

import { sendSmsRequest } from "./services/sms.service";
import { sendDataMessage } from "./services/fcm.service";
import { associateModels } from './db/models/assosiateModel';

associateModels();

console.log(config.database);
const app = express();
app.use(cors());
const httpServer = createServer(app);

// Configure Socket.IO with CORS and WebSocket transport
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: "*", // In production, replace with your frontend URL
    methods: ["GET", "POST"],
  },
  transports: ["websocket", "polling"], // Enable WebSocket transport
  // Aggressive ping settings to detect dead connections faster
  pingTimeout: 10000, // 10 seconds - Time to wait for pong before considering connection dead
  pingInterval: 5000, // 5 seconds - How often to send ping packets
  connectTimeout: 10000, // 10 seconds - Connection timeout
});

// Handle connection events
io.on("connection", (socket) => {
  console.log("Client connected:", socket.id);

  socket.on("disconnect", () => {
    console.log("Client disconnected:", socket.id);
  });
});

// Initialize chat controller with Socket.IO
export const chatController = new ChatController(io);

// Middleware
app.use(express.json());

// Request logging middleware to debug mobile connectivity
app.use((req, res, next) => {
  console.log("\n" + "📡".repeat(20));
  console.log(`📡 [INCOMING] ${req.method} ${req.url}`);
  console.log(`📡 [HEADERS] ${JSON.stringify(req.headers)}`);
  console.log(`📡 [BODY]    ${JSON.stringify(req.body)}`);
  console.log("📡".repeat(20) + "\n");
  console.log(`📢 [${new Date().toISOString()}] ${req.method} ${req.url}`);
  if (req.method === 'POST') {
    console.log('📦 Body:', JSON.stringify(req.body, null, 2));
  }
  next();
});

// Debug endpoint to test connection from mobile browser
app.get("/ping", (req, res) => {
  res.send("pong - Connection to Backend is working!");
});

// Serve static files from uploads directory
const uploadsPath = path.join(__dirname, "..", "uploads");
app.use("/uploads", express.static(uploadsPath));

// Serve static files from public directory
const publicPath = path.join(__dirname, "..", "public");

app.use(express.static(publicPath));

app.get(/(.+)\.html$/, (req: Request, res: Response) => {
  res.redirect(301, req.params[0]);
});

app.get("/privacy-policy", (req, res) => {
  res.sendFile(path.join(publicPath, "privacy-policy.html"));
});
app.get("/terms-conditions", (req, res) => {
  res.sendFile(path.join(publicPath, "terms-conditions.html"));
});
app.get("/delete-account", (req, res) => {
  res.sendFile(path.join(publicPath, "delete-account.html"));
});
// Health check route
app.get("/health", async (req, res) => {
  try {
    res.status(200).json({
      status: "healthy",
      timestamp: new Date(),
      database: "connected",
    });
  } catch (error) {
    res.status(503).json({
      status: "unhealthy",
      timestamp: new Date(),
      database: "disconnected",
      error: (error as Error).message,
    });
  }
});

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/status", statusRoutes);
app.use("/api/locations", locationRoutes);
app.use("/api/chats", setupChatRoutes(chatController));
app.use("/api/mobile/chat", setupMobileChatRoutes(chatController));
app.use("/api/block", blockRoutes);
app.use("/api/emoji-updates", emojiUpdateRoutes);
app.use("/api/chat-picture-likes", chatPictureLikeRoutes);
app.use("/api/images", imageRoutes);
app.use("/api/reactions", messageReactionRoutes); // Message reactions
app.use("/api/stories", storyRoutes); // Chat Stories feature
app.use("/api/call-logs", callLogRoutes); // Call logs and history
app.use("/api/notifications", notificationRoutes); // In-app notifications
app.use("/api/test", testRoutes); // Test routes for development
app.get("/api/test_sms", function (req, res) {
  sendSmsRequest("+918977191811", "12345");
});
app.get("/api/test_notification", async function (req, res) {
  try {
    const token =
      "fljN8p4yTKKOSLxIT08zD4:APA91bG-f7XuCKxn0iWnO0ZQPpgEhjHn-l9t1ggk-UAIoR_MDRESw29tFHNYJOMcpfG8PzUcwRTj7-tCZQormPPgzbOMNix1vZW38faZEjiummSHgDCfe8Y";
    await sendDataMessage(token, {
      title: "You have a new message",
      body: "Hi how are you 1234",
      senderId: "63aebcb6-27fb-4a55-847d-098f63294ce3",
      chatId: "test123",
      senderFirstName: "Naidu",
      sender_chat_picture: "",
      sender_mobile_number: "8125150264",
    });
    res
      .status(200)
      .json({ success: true, message: "Notification sent successfully" });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

async function startServer() {
  try {
    // Connect to database
    await sequelize.authenticate();
    console.log("Database connection established successfully.");

    await sequelize.sync({ alter: false });

    // Start HTTP server with Socket.IO and Express
    const PORT = Number(process.env.PORT) || 3200;
    httpServer.listen(PORT, "0.0.0.0", () => {
      console.log(`Server is running in ${config.env} mode on port ${PORT}`);
      console.log("WebSocket server is running on 0.0.0.0");
    });
    console.log("Database models synchronized.");
  } catch (error) {
    console.error("Error:", error);
    // Instead of process.exit, we could implement a proper shutdown procedure
    throw error;
  }
}

startServer().catch((error) => {
  console.error("Failed to start server:", error);
  process.exit(1);
});
