#!/usr/bin/env python3
"""
Enhanced App Icon Generator for Cheffy-AI
Creates a more prominent Michelin-inspired app icon
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

def create_gradient_background(size, start_color, end_color):
    """Create a smooth gradient background"""
    image = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(image)
    
    for y in range(size):
        ratio = y / size
        r = int(start_color[0] * (1 - ratio) + end_color[0] * ratio)
        g = int(start_color[1] * (1 - ratio) + end_color[1] * ratio)
        b = int(start_color[2] * (1 - ratio) + end_color[2] * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    
    return image

def create_chef_hat(size):
    """Create a more prominent chef hat"""
    hat_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(hat_image)
    
    # Hat dimensions - make it more prominent
    hat_width = int(size * 0.7)
    hat_height = int(size * 0.5)
    hat_x = (size - hat_width) // 2
    hat_y = int(size * 0.15)
    
    # Create hat base (cylinder part)
    base_height = int(hat_height * 0.4)
    base_y = hat_y + hat_height - base_height
    
    # Draw hat base with metallic gradient
    for i in range(base_height):
        ratio = i / base_height
        r = int(255 * (1 - ratio * 0.2))
        g = int(255 * (1 - ratio * 0.2))
        b = int(255 * (1 - ratio * 0.2))
        
        y_pos = base_y + i
        draw.rectangle([hat_x, y_pos, hat_x + hat_width, y_pos + 1], 
                      fill=(r, g, b, 255))
    
    # Draw hat top (pleated part) - make it more prominent
    top_height = int(hat_height * 0.6)
    top_y = hat_y
    
    for i in range(top_height):
        ratio = i / top_height
        r = int(250 * (1 - ratio * 0.15))
        g = int(250 * (1 - ratio * 0.15))
        b = int(250 * (1 - ratio * 0.15))
        
        y_pos = top_y + i
        draw.rectangle([hat_x, y_pos, hat_x + hat_width, y_pos + 1], 
                      fill=(r, g, b, 255))
    
    # Add more prominent pleat lines
    for i in range(4):
        x_pos = hat_x + (hat_width // 5) * (i + 1)
        draw.line([x_pos, top_y, x_pos, top_y + top_height], 
                 fill=(200, 200, 200, 150), width=2)
    
    return hat_image

def create_ai_elements(size):
    """Create more prominent AI elements"""
    ai_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ai_image)
    
    # Neural nodes - make them more prominent
    node_positions = [
        (size * 0.25, size * 0.25),  # Top left
        (size * 0.75, size * 0.2),   # Top right
        (size * 0.2, size * 0.75),   # Bottom left
        (size * 0.8, size * 0.8),    # Bottom right
        (size * 0.5, size * 0.1),    # Top center
    ]
    
    # Draw more prominent glowing nodes
    for x, y in node_positions:
        # Outer glow - make it more visible
        for radius in range(12, 0, -1):
            alpha = int(50 * (1 - radius / 12))
            color = (100, 200, 255, alpha)  # Blue glow
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], 
                        fill=color)
        
        # Core node - make it larger
        draw.ellipse([x - 5, y - 5, x + 5, y + 5], 
                    fill=(150, 220, 255, 255))
    
    # Pixel sparks - make them more prominent
    spark_positions = [
        (size * 0.15, size * 0.4),
        (size * 0.85, size * 0.35),
        (size * 0.1, size * 0.85),
        (size * 0.9, size * 0.9),
    ]
    
    for x, y in spark_positions:
        # Spark with more prominent glow
        for size_spark in range(6, 0, -1):
            alpha = int(80 * (1 - size_spark / 6))
            color = (255, 255, 100, alpha)  # Golden spark
            draw.rectangle([x - size_spark, y - size_spark, 
                          x + size_spark, y + size_spark], 
                         fill=color)
    
    return ai_image

def create_premium_app_icon(size=1024):
    """Create the complete premium app icon with more contrast"""
    # More contrasting colors
    navy_color = (10, 20, 40)      # Deeper navy
    gold_color = (200, 160, 100)   # Brighter gold
    
    # Create gradient background
    background = create_gradient_background(size, navy_color, gold_color)
    
    # Create chef hat
    hat = create_chef_hat(size)
    
    # Create AI elements
    ai_elements = create_ai_elements(size)
    
    # Composite all elements
    final_image = background.convert('RGBA')
    final_image = Image.alpha_composite(final_image, hat)
    final_image = Image.alpha_composite(final_image, ai_elements)
    
    # Add subtle glow effect
    final_image = final_image.filter(ImageFilter.GaussianBlur(radius=0.5))
    
    return final_image

def generate_all_icon_sizes():
    """Generate all required iOS app icon sizes"""
    sizes = {
        'AppIcon-20x20.png': 20,
        'AppIcon-29x29.png': 29,
        'AppIcon-40x40.png': 40,
        'AppIcon-58x58.png': 58,
        'AppIcon-60x60.png': 60,
        'AppIcon-76x76.png': 76,
        'AppIcon-80x80.png': 80,
        'AppIcon-87x87.png': 87,
        'AppIcon-120x120.png': 120,
        'AppIcon-152x152.png': 152,
        'AppIcon-167x167.png': 167,
        'AppIcon-180x180.png': 180,
        'AppIcon-1024x1024.png': 1024,
    }
    
    # Create output directory
    output_dir = 'Cheffy/Resources/Assets.xcassets/AppIcon.appiconset'
    os.makedirs(output_dir, exist_ok=True)
    
    print("🎨 Generating enhanced premium Michelin-inspired app icons...")
    
    for filename, size in sizes.items():
        print(f"Creating {filename} ({size}x{size})...")
        icon = create_premium_app_icon(size)
        icon.save(os.path.join(output_dir, filename), 'PNG', optimize=True)
    
    print("✅ Enhanced app icons generated successfully!")
    print("📱 Icons saved to: Cheffy/Resources/Assets.xcassets/AppIcon.appiconset/")

if __name__ == "__main__":
    generate_all_icon_sizes()
