# ChatAway Plus Server

## Video Thumbnails for Stories & Chat Messages

✅ **Now supports video thumbnails for both stories and chat messages!**

📖 **Implementation Guide:** [VIDEO_THUMBNAIL_GUIDE.md](VIDEO_THUMBNAIL_GUIDE.md)

The server accepts video + thumbnail uploads. Mobile app generates thumbnails client-side (no FFmpeg needed on server).

---

curl -X PUT http://192.168.1.19:3200/api/locations/f2d4956f-8df1-4d91-bfcf-a166fb129625 \
 -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI3YjY4MGIyNy1mNzhmLTRjN2EtODFiMS0xNzY2NTZmNzE0ZDIiLCJtb2JpbGVObyI6Ijg5ODk4OTg5ODIiLCJpYXQiOjE3NDkyNzI0NjksImV4cCI6MTc0OTg3NzI2OX0.8dSyJbSD-AwErGeNdMzxsiPjOS0p5tmbqHhEqyAB2Lc" \
 -F "name=Updated Location Name" \
 -F "description=Updated Description" \
 -F "photos=@uploads/profile/chatawaypluspic-1745938297997-923170080.png"
-F "photos=@uploads/profile/chatawaypluspic-1745938297997-923170080.png"
