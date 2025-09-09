const cloudinary = require('cloudinary').v2;
const fs = require('fs');
const path = require('path');

// Test Cloudinary connection with your credentials
cloudinary.config({
  cloud_name: 'deqtxoewp',
  api_key: '429458566368881',
  api_secret: '1NPDJVTgxydH8VCOD7w-NLhFVdc'
});

console.log('Testing Cloudinary connection...');

// Create a simple test image data (1x1 pixel PNG)
const testImageBase64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

cloudinary.uploader.upload(testImageBase64, {
  folder: 'eduvision/test',
  public_id: `test_${Date.now()}`,
  resource_type: 'image'
})
.then(result => {
  console.log('✅ Cloudinary connection successful!');
  console.log('Image URL:', result.secure_url);
  console.log('Public ID:', result.public_id);
  console.log('File size:', result.bytes, 'bytes');
})
.catch(error => {
  console.log('❌ Cloudinary connection failed!');
  console.error('Error details:', error);
  if (error.error && error.error.message) {
    console.error('Error message:', error.error.message);
  }
});