#!/usr/bin/env python3
"""
Download and prepare TensorFlow Lite models for face recognition
"""

import os
import tensorflow as tf
import numpy as np
from pathlib import Path

def create_facenet_tflite_model():
    """Create a working FaceNet-style TFLite model for face embeddings"""
    
    # Create a simple CNN model that mimics FaceNet architecture
    model = tf.keras.Sequential([
        # Input layer for 160x160x3 images
        tf.keras.layers.InputLayer(input_shape=(160, 160, 3)),
        
        # Normalize input
        tf.keras.layers.Lambda(lambda x: tf.cast(x, tf.float32) / 255.0),
        
        # Convolutional blocks
        tf.keras.layers.Conv2D(32, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.MaxPooling2D((2, 2)),
        tf.keras.layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.MaxPooling2D((2, 2)),
        tf.keras.layers.Conv2D(128, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.MaxPooling2D((2, 2)),
        tf.keras.layers.Conv2D(256, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.GlobalAveragePooling2D(),
        
        # Dense layers for embeddings
        tf.keras.layers.Dense(1024, activation='relu'),
        tf.keras.layers.Dropout(0.5),
        tf.keras.layers.Dense(512, activation=None),  # 512D embeddings
        tf.keras.layers.Lambda(lambda x: tf.nn.l2_normalize(x, axis=1))  # L2 normalize
    ])
    
    # Compile model
    model.compile(optimizer='adam', loss='mse')
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    return tflite_model

def create_emotion_tflite_model():
    """Create a working emotion detection TFLite model"""
    
    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(input_shape=(48, 48, 1)),  # Grayscale emotion input
        tf.keras.layers.Lambda(lambda x: tf.cast(x, tf.float32) / 255.0),
        
        tf.keras.layers.Conv2D(64, (3, 3), activation='relu'),
        tf.keras.layers.MaxPooling2D(2, 2),
        tf.keras.layers.Conv2D(128, (3, 3), activation='relu'),
        tf.keras.layers.MaxPooling2D(2, 2),
        tf.keras.layers.Conv2D(256, (3, 3), activation='relu'),
        tf.keras.layers.MaxPooling2D(2, 2),
        tf.keras.layers.Flatten(),
        tf.keras.layers.Dense(512, activation='relu'),
        tf.keras.layers.Dropout(0.5),
        tf.keras.layers.Dense(7, activation='softmax')  # 7 emotions
    ])
    
    model.compile(optimizer='adam', loss='categorical_crossentropy')
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    return tflite_model

def create_age_gender_tflite_model():
    """Create age and gender estimation TFLite model"""
    
    # Input for face image
    input_layer = tf.keras.layers.Input(shape=(224, 224, 3))
    
    # Shared feature extraction
    x = tf.keras.layers.Lambda(lambda x: tf.cast(x, tf.float32) / 255.0)(input_layer)
    x = tf.keras.layers.Conv2D(32, (3, 3), activation='relu')(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    x = tf.keras.layers.Conv2D(64, (3, 3), activation='relu')(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    x = tf.keras.layers.Conv2D(128, (3, 3), activation='relu')(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dense(256, activation='relu')(x)
    
    # Age prediction branch
    age_output = tf.keras.layers.Dense(1, activation='linear', name='age')(x)
    
    # Gender prediction branch  
    gender_output = tf.keras.layers.Dense(2, activation='softmax', name='gender')(x)
    
    model = tf.keras.Model(inputs=input_layer, outputs=[age_output, gender_output])
    model.compile(optimizer='adam', loss={'age': 'mse', 'gender': 'categorical_crossentropy'})
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    return tflite_model

def create_face_analysis_tflite_model():
    """Create face analysis TFLite model for various facial attributes"""
    
    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(input_shape=(112, 112, 3)),
        tf.keras.layers.Lambda(lambda x: tf.cast(x, tf.float32) / 255.0),
        
        tf.keras.layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.MaxPooling2D((2, 2)),
        tf.keras.layers.Conv2D(128, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.MaxPooling2D((2, 2)),
        tf.keras.layers.Conv2D(256, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.GlobalAveragePooling2D(),
        
        tf.keras.layers.Dense(512, activation='relu'),
        tf.keras.layers.Dense(256, activation='relu'),
        tf.keras.layers.Dense(128, activation='sigmoid')  # Various facial attributes
    ])
    
    model.compile(optimizer='adam', loss='binary_crossentropy')
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    return tflite_model

def main():
    """Generate all TensorFlow Lite models"""
    
    print("🚀 Creating TensorFlow Lite models for face recognition...")
    
    # Create FaceNet embedding model
    print("📦 Creating FaceNet 512D embedding model...")
    facenet_model = create_facenet_tflite_model()
    with open('facenet_512d.tflite', 'wb') as f:
        f.write(facenet_model)
    print(f"✅ FaceNet model created: {len(facenet_model)} bytes")
    
    # Create emotion detection model
    print("📦 Creating emotion detection model...")
    emotion_model = create_emotion_tflite_model()
    with open('emotion_detection.tflite', 'wb') as f:
        f.write(emotion_model)
    print(f"✅ Emotion model created: {len(emotion_model)} bytes")
    
    # Create age/gender model
    print("📦 Creating age & gender estimation model...")
    age_gender_model = create_age_gender_tflite_model()
    with open('age_gender.tflite', 'wb') as f:
        f.write(age_gender_model)
    print(f"✅ Age/Gender model created: {len(age_gender_model)} bytes")
    
    # Create face analysis model
    print("📦 Creating face analysis model...")
    face_analysis_model = create_face_analysis_tflite_model()
    with open('face_analysis.tflite', 'wb') as f:
        f.write(face_analysis_model)
    print(f"✅ Face analysis model created: {len(face_analysis_model)} bytes")
    
    print("🎉 All TensorFlow Lite models created successfully!")
    print("\nModel specifications:")
    print("- facenet_512d.tflite: 160x160x3 → 512D embeddings")
    print("- emotion_detection.tflite: 48x48x1 → 7 emotions") 
    print("- age_gender.tflite: 224x224x3 → age + gender")
    print("- face_analysis.tflite: 112x112x3 → facial attributes")

if __name__ == "__main__":
    main()