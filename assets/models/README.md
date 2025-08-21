# Face Recognition Models

This directory contains TensorFlow Lite models for face recognition.

## Required Models

### 1. FaceNet Model (Recommended)
- **File**: `face_recognition_model.tflite`
- **Input**: 160x160x3 (RGB image)
- **Output**: 512D embedding vector
- **Download**: Can be converted from FaceNet TensorFlow model

### 2. Alternative Models
- **MobileFaceNet**: Lightweight, optimized for mobile
- **ArcFace**: High accuracy face recognition
- **InsightFace**: Open source face analysis

## How to Add Models

### Option 1: Download Pre-converted Models
```bash
# Download FaceNet TensorFlow Lite model (example URLs)
# Note: Replace with actual model URLs from official sources
curl -o assets/models/face_recognition_model.tflite \
  https://storage.googleapis.com/mediapipe-models/face_embedder/mobilenet_v2/float32/1/mobilenet_v2.tflite
```

### Option 2: Convert from TensorFlow
```python
# Convert FaceNet model to TensorFlow Lite
import tensorflow as tf

# Load pre-trained FaceNet model
model = tf.keras.models.load_model('facenet_keras.h5')

# Convert to TensorFlow Lite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

# Save the model
with open('assets/models/face_recognition_model.tflite', 'wb') as f:
    f.write(tflite_model)
```

### Option 3: Use Google's MediaPipe Models
MediaPipe provides pre-trained face embedding models that work well:
- Download from: https://developers.google.com/mediapipe/solutions/vision/face_embedder

## Model Performance Comparison

| Model | Size | Accuracy | Speed | Memory |
|-------|------|----------|-------|--------|
| FaceNet | ~25MB | High | Medium | High |
| MobileFaceNet | ~5MB | Medium | Fast | Low |
| MediaPipe FaceEmbedder | ~10MB | High | Fast | Medium |

## Testing Models

The app will fallback to simulated embeddings if no model is found, allowing you to test the integration before adding the actual model.

## Security Notes

- Models should be verified from trusted sources
- Consider model obfuscation for production apps
- Embeddings are stored locally using SHA-256 integrity checks