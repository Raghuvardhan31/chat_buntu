# Video Thumbnail Upload Guide - Stories & Chat Messages

## ✅ Server Updated

The server now supports video thumbnails for:

1. **Story uploads** - `/api/stories/upload`
2. **Chat messages** - `/api/chats/upload-file` ← **NEW**

---

## API Changes

### For Stories

```
POST /api/stories/upload

FormData:
  - media: video.mp4 (required)
  - thumbnail: thumb.jpg (optional)
```

### For Chat Messages (NEW)

```
POST /api/chats/upload-file

FormData:
  - file: video.mp4 (required)
  - thumbnail: thumb.jpg (optional)  ← ADDED
```

**Response includes `thumbnailUrl`:**

```json
{
  "messageType": "video",
  "fileUrl": "chat/userId/file-123.mp4",
  "thumbnailUrl": "chat/userId/thumb-123.jpg",  ← NEW
  "mimeType": "video/mp4"
}
```

---

## Flutter Implementation

### Complete Example for Chat Video Upload

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class ChatVideoUploader {
  final String apiBaseUrl;
  final String authToken;

  ChatVideoUploader({
    required this.apiBaseUrl,
    required this.authToken,
  });

  /// Extract thumbnail from video
  Future<File?> extractThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: '${tempDir.path}/$fileName',
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
        timeMs: 500,
      );

      return thumbnailPath != null ? File(thumbnailPath) : null;
    } catch (e) {
      print('Thumbnail error: $e');
      return null;
    }
  }

  /// Upload video for chat message
  Future<Map<String, dynamic>?> uploadChatVideo(File videoFile) async {
    try {
      // Extract thumbnail
      final thumbnailFile = await extractThumbnail(videoFile.path);

      // Prepare request
      final uri = Uri.parse('$apiBaseUrl/api/chats/upload-file');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $authToken';

      // Add video file
      request.files.add(
        await http.MultipartFile.fromPath('file', videoFile.path),
      );

      // Add thumbnail if available
      if (thumbnailFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('thumbnail', thumbnailFile.path),
        );
      }

      // Send
      final response = await http.Response.fromStream(await request.send());

      // Cleanup
      if (thumbnailFile != null) await thumbnailFile.delete();

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  /// Upload video for story
  Future<Map<String, dynamic>?> uploadStory(File videoFile) async {
    try {
      final thumbnailFile = await extractThumbnail(videoFile.path);

      final uri = Uri.parse('$apiBaseUrl/api/stories/upload');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $authToken';

      // Note: field name is 'media' for stories
      request.files.add(
        await http.MultipartFile.fromPath('media', videoFile.path),
      );

      if (thumbnailFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('thumbnail', thumbnailFile.path),
        );
      }

      final response = await http.Response.fromStream(await request.send());

      if (thumbnailFile != null) await thumbnailFile.delete();

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Story upload error: $e');
      return null;
    }
  }
}
```

### Usage Example

```dart
// Initialize uploader
final uploader = ChatVideoUploader(
  apiBaseUrl: 'https://your-api.com',
  authToken: yourAuthToken,
);

// For chat messages
final chatResult = await uploader.uploadChatVideo(videoFile);
if (chatResult != null) {
  print('Video URL: ${chatResult['fileUrl']}');
  print('Thumbnail URL: ${chatResult['thumbnailUrl']}'); // NEW

  // Send message with video
  sendChatMessage(
    fileUrl: chatResult['fileUrl'],
    thumbnailUrl: chatResult['thumbnailUrl'],
    messageType: 'video',
  );
}

// For stories
final storyResult = await uploader.uploadStory(videoFile);
if (storyResult != null) {
  print('Story uploaded with thumbnail');
}
```

---

## What This Solves

### Before

- ❌ Videos in chat had no thumbnails
- ❌ Story videos had no thumbnails
- ❌ Poor user experience (black placeholder)

### After

- ✅ Chat videos show thumbnail preview
- ✅ Story videos show thumbnail preview
- ✅ Better user experience
- ✅ No server-side FFmpeg needed

---

## Quick Summary for Mobile Developers

**3 Simple Changes:**

1. **Extract thumbnail from video** (use `video_thumbnail` package)
2. **Add one extra field to upload:**
   - Chat: Add `thumbnail` field to `/api/chats/upload-file`
   - Story: Add `thumbnail` field to `/api/stories/upload`
3. **Use `thumbnailUrl` from response** to display preview

That's it! Server handles everything else automatically.

---

## Required Packages

```yaml
dependencies:
  image_picker: ^1.0.4 # Pick video
  video_thumbnail: ^0.5.3 # Extract thumbnail
  path_provider: ^2.1.1 # Temp directory
  http: ^1.1.0 # Upload
```

---

## Testing

### Test Chat Video Upload

```bash
curl -X POST https://your-api.com/api/chats/upload-file \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@/path/to/video.mp4" \
  -F "thumbnail=@/path/to/thumb.jpg"
```

### Test Story Upload

```bash
curl -X POST https://your-api.com/api/stories/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "media=@/path/to/video.mp4" \
  -F "thumbnail=@/path/to/thumb.jpg"
```
