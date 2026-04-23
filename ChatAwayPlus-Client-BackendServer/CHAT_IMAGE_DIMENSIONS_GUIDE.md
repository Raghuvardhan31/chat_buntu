# Chat Image Dimensions Implementation Guide

## Backend Changes Completed ✅

### 1. Database Schema
- **Migration Created**: `20260104000000-add-image-dimensions-to-chats.ts`
- **Fields Added**:
  - `imageWidth` (INTEGER, nullable)
  - `imageHeight` (INTEGER, nullable)

### 2. Chat Model Updated
- File: `src/db/models/chat.model.ts`
- Added `imageWidth` and `imageHeight` properties and schema fields

### 3. Upload Controller Updated
- File: `src/controllers/chat.controller.ts` → `uploadFileController`
- Now accepts `imageWidth` and `imageHeight` from request body
- Returns dimensions in response for images

## Frontend Implementation Required

### 1. Get Image Dimensions Before Upload

```dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

Future<Size> getImageDimensions(File file) async {
  Completer<Size> completer = Completer();
  Image image = Image.file(file);
  image.image.resolve(ImageConfiguration()).addListener(
    ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      ));
    }),
  );
  return completer.future;
}
```

### 2. Upload Image with Dimensions

```dart
Future<Map<String, dynamic>> uploadChatImage(File imageFile) async {
  // Get image dimensions
  Size dimensions = await getImageDimensions(imageFile);

  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/api/chat/upload-file'),
  );

  request.headers['Authorization'] = 'Bearer $token';
  request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  // Add dimensions to request body
  request.fields['imageWidth'] = dimensions.width.toInt().toString();
  request.fields['imageHeight'] = dimensions.height.toInt().toString();

  var response = await request.send();
  var responseData = await response.stream.bytesToString();

  return json.decode(responseData);
  // Returns: { messageType, fileUrl, mimeType, imageWidth, imageHeight }
}
```

### 3. Send Message with Image Dimensions

```dart
Future<void> sendImageMessage({
  required String receiverId,
  required String fileUrl,
  required String mimeType,
  required int imageWidth,
  required int imageHeight,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/mobile-chat/messages'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'receiverId': receiverId,
      'messageType': 'image',
      'fileUrl': fileUrl,
      'mimeType': mimeType,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to send message');
  }
}
```

### 4. Display Images with Dynamic Aspect Ratio

```dart
Widget buildImageBubble(
  String imageUrl,
  double width,
  double height,
) {
  return Container(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.7,
      maxHeight: 400, // Prevent images from being too tall
    ),
    child: AspectRatio(
      aspectRatio: width / height,
      child: GestureDetector(
        onTap: () => openFullScreenImage(imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
        ),
      ),
    ),
  );
}
```

### 5. Full Screen Image Viewer

```dart
void openFullScreenImage(String imageUrl) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}
```

## Remaining Backend Tasks

### Mobile Chat Controller (`src/controllers/mobile-chat.controller.ts`)

The `sendMessage` method needs to be updated to:
1. Accept `imageWidth` and `imageHeight` from request body
2. Store dimensions in database when creating chat message
3. Include dimensions in WebSocket events

**Required Changes:**

```typescript
// Line 32: Add to destructuring
const { receiverId, message, messageType, fileUrl, mimeType, contactPayload, imageWidth, imageHeight } = req.body;

// Line 81-93: Update Chat.create
const chat = await Chat.create({
  senderId,
  receiverId,
  messageType,
  message: message || null,
  fileUrl: fileUrl || null,
  mimeType: mimeType || null,
  imageWidth: messageType === 'image' && imageWidth ? parseInt(imageWidth) : null,
  imageHeight: messageType === 'image' && imageHeight ? parseInt(imageHeight) : null,
  contactPayload: contactPayload || null,
  messageStatus: 'sent',
  isRead: false,
  deliveryChannel: 'fcm'
});

// Line 103-116: Add to 'message-sent' event
this.chatController.emitToSocket(senderSocketId, 'message-sent', {
  chatId: chatId,
  receiverId,
  messageType: messageType,
  message: message || null,
  fileUrl: fileUrl || null,
  mimeType: mimeType || null,
  imageWidth: chat.dataValues.imageWidth || null,
  imageHeight: chat.dataValues.imageHeight || null,
  contactPayload: contactPayload || null,
  messageStatus: 'sent',
  deliveryChannel: 'fcm',
  receiverDeliveryChannel: null,
  createdAt: chat.dataValues.createdAt,
  reactions: []
});

// Line 121-136: Add to 'new-message' event
this.chatController.emitToSocket(receiverSocketId, 'new-message', {
  chatId: chatId,
  senderId,
  receiverId,
  messageType: messageType,
  message: message || null,
  fileUrl: fileUrl || null,
  mimeType: mimeType || null,
  imageWidth: chat.dataValues.imageWidth || null,
  imageHeight: chat.dataValues.imageHeight || null,
  contactPayload: contactPayload || null,
  messageStatus: 'sent',
  deliveryChannel: 'fcm',
  receiverDeliveryChannel: null,
  createdAt: chat.dataValues.createdAt,
  reactions: []
});
```

## Run Database Migration

```bash
# Development
npm run migrate

# Or manually
npx sequelize-cli db:migrate
```

## Testing

1. Upload an image → verify dimensions are returned
2. Send image message → verify dimensions saved in database
3. Retrieve messages → verify dimensions included in response
4. WebSocket events → verify dimensions sent to both sender and receiver

## Recommended Packages

```yaml
dependencies:
  cached_network_image: ^3.3.0  # Image caching
  photo_view: ^0.14.0           # Full-screen image viewer with zoom
```
