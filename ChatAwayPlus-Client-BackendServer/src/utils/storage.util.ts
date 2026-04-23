import path from 'path';

/**
 * Convert file storage info (S3 URL or Local Path) to API streaming URL
 * Input: Multer file object (can be S3 or Disk)
 * Output: /api/images/stream/[key]
 */
export const formatMediaUrl = (file: any): string => {
  try {
    if (!file) return '';

    // 1. Handle S3 (multer-s3 provides .key or .location)
    if (file.key) {
      return `/api/images/stream/${file.key}`;
    }
    
    if (file.location) {
      const urlParts = file.location.split('.amazonaws.com/');
      if (urlParts.length > 1) {
        return `/api/images/stream/${urlParts[1]}`;
      }
      return file.location; // Return as is if it's already a full URL
    }

    // 2. Handle Local Disk (multer.diskStorage provides .path)
    if (file.path) {
      // Look for 'uploads' in the path to create a relative streaming key
      const parts = file.path.split(/[\\/]uploads[\\/]/);
      if (parts.length > 1) {
        // Convert backslashes to forward slashes for the URL key
        return `/api/images/stream/${parts[1].replace(/\\/g, '/')}`;
      }
      return file.path;
    }

    return '';
  } catch (error) {
    console.error('Error formatting media URL:', error);
    return '';
  }
};
