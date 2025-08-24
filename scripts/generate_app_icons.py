#!/usr/bin/env python3
"""
Generate app icons from logo.png for all platforms
"""

from PIL import Image
import os
import sys

def create_icon(input_path, output_path, size, background_color=(255, 255, 255, 255)):
    """Create an icon with the specified size"""
    try:
        # Open the logo image
        with Image.open(input_path) as img:
            # Convert to RGBA if not already
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Create a new image with the target size and background
            new_img = Image.new('RGBA', (size, size), background_color)
            
            # Calculate scaling to fit the logo within the square
            # Maintain aspect ratio and center the logo
            img_ratio = img.width / img.height
            target_ratio = 1.0
            
            if img_ratio > target_ratio:
                # Image is wider than tall
                new_width = size
                new_height = int(size / img_ratio)
            else:
                # Image is taller than wide
                new_height = size
                new_width = int(size * img_ratio)
            
            # Resize the logo
            resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            
            # Calculate position to center the logo
            x = (size - new_width) // 2
            y = (size - new_height) // 2
            
            # Paste the resized logo onto the background
            new_img.paste(resized_img, (x, y), resized_img)
            
            # Save the icon
            new_img.save(output_path, 'PNG')
            print(f"Created: {output_path} ({size}x{size})")
            
    except Exception as e:
        print(f"Error creating {output_path}: {e}")

def main():
    # Path to the logo
    logo_path = "assets/images/logo.png"
    
    if not os.path.exists(logo_path):
        print(f"Logo not found at {logo_path}")
        sys.exit(1)
    
    # Android icon sizes
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192
    }
    
    # Web icon sizes
    web_sizes = {
        'Icon-192': 192,
        'Icon-512': 512,
        'Icon-maskable-192': 192,
        'Icon-maskable-512': 512
    }
    
    # iOS icon sizes (if needed)
    ios_sizes = {
        'AppIcon-20': 20,
        'AppIcon-29': 29,
        'AppIcon-40': 40,
        'AppIcon-60': 60,
        'AppIcon-76': 76,
        'AppIcon-83.5': 83.5,
        'AppIcon-1024': 1024
    }
    
    print("Generating Android app icons...")
    for folder, size in android_sizes.items():
        output_dir = f"android/app/src/main/res/{folder}"
        os.makedirs(output_dir, exist_ok=True)
        output_path = f"{output_dir}/ic_launcher.png"
        create_icon(logo_path, output_path, size)
    
    print("\nGenerating Web app icons...")
    for filename, size in web_sizes.items():
        output_path = f"web/icons/{filename}.png"
        create_icon(logo_path, output_path, size)
    
    print("\nGenerating iOS app icons...")
    ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(ios_dir, exist_ok=True)
    
    for filename, size in ios_sizes.items():
        # iOS icons need to be exact pixel sizes
        if size == 83.5:
            # 83.5 needs to be 167 for @2x
            actual_size = 167
        else:
            actual_size = size
        
        output_path = f"{ios_dir}/{filename}.png"
        create_icon(logo_path, output_path, actual_size)
    
    print("\nApp icons generated successfully!")
    print("Note: You may need to clean and rebuild your project for changes to take effect.")

if __name__ == "__main__":
    main()
