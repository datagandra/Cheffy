#!/usr/bin/env python3
"""
Premium Michelin-inspired App Icon Generator for Cheffy-AI
Creates a sophisticated, luxury app icon with chef hat and AI elements
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

def create_gradient_background(size, start_color, end_color):
    """Create a smooth gradient background"""
    image = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(image)
    
    for y in range(size):
        # Calculate gradient ratio
        ratio = y / size
        # Interpolate between start and end colors
        r = int(start_color[0] * (1 - ratio) + end_color[0] * ratio)
        g = int(start_color[1] * (1 - ratio) + end_color[1] * ratio)
        b = int(start_color[2] * (1 - ratio) + end_color[2] * ratio)
        
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    
    return image

def create_chef_hat(size):
    """Create a minimal, elegant chef hat with metallic gradient"""
    # Create a transparent image
    hat_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(hat_image)
    
    # Hat dimensions (scaled to icon size)
    hat_width = int(size * 0.6)
    hat_height = int(size * 0.4)
    hat_x = (size - hat_width) // 2
    hat_y = int(size * 0.2)
    
    # Create hat base (cylinder part)
    base_height = int(hat_height * 0.4)
    base_y = hat_y + hat_height - base_height
    
    # Draw hat base with metallic gradient
    for i in range(base_height):
        # Metallic gradient from white to silver
        ratio = i / base_height
        r = int(255 * (1 - ratio * 0.3))
        g = int(255 * (1 - ratio * 0.3))
        b = int(255 * (1 - ratio * 0.3))
        
        y_pos = base_y + i
        draw.rectangle([hat_x, y_pos, hat_x + hat_width, y_pos + 1], 
                      fill=(r, g, b, 255))
    
    # Draw hat top (pleated part)
    top_height = int(hat_height * 0.6)
    top_y = hat_y
    
    # Create pleated effect with subtle lines
    for i in range(top_height):
        ratio = i / top_height
        # Slightly darker for depth
        r = int(240 * (1 - ratio * 0.2))
        g = int(240 * (1 - ratio * 0.2))
        b = int(240 * (1 - ratio * 0.2))
        
        y_pos = top_y + i
        draw.rectangle([hat_x, y_pos, hat_x + hat_width, y_pos + 1], 
                      fill=(r, g, b, 255))
    
    # Add subtle pleat lines
    for i in range(3):
        x_pos = hat_x + (hat_width // 4) * (i + 1)
        draw.line([x_pos, top_y, x_pos, top_y + top_height], 
                 fill=(220, 220, 220, 100), width=1)
    
    return hat_image

def create_ai_elements(size):
    """Create subtle AI neural nodes and pixel sparks"""
    ai_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ai_image)
    
    # Neural nodes (small glowing circles)
    node_positions = [
        (size * 0.3, size * 0.3),  # Top left
        (size * 0.7, size * 0.25), # Top right
        (size * 0.25, size * 0.7), # Bottom left
        (size * 0.75, size * 0.75), # Bottom right
        (size * 0.5, size * 0.15),  # Top center
    ]
    
    # Draw glowing nodes
    for x, y in node_positions:
        # Outer glow
        for radius in range(8, 0, -1):
            alpha = int(30 * (1 - radius / 8))
            color = (100, 200, 255, alpha)  # Blue glow
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], 
                        fill=color)
        
        # Core node
        draw.ellipse([x - 3, y - 3, x + 3, y + 3], 
                    fill=(150, 220, 255, 200))
    
    # Pixel sparks (small squares)
    spark_positions = [
        (size * 0.2, size * 0.4),
        (size * 0.8, size * 0.35),
        (size * 0.15, size * 0.8),
        (size * 0.85, size * 0.85),
    ]
    
    for x, y in spark_positions:
        # Spark with glow
        for size_spark in range(4, 0, -1):
            alpha = int(60 * (1 - size_spark / 4))
            color = (255, 255, 100, alpha)  # Golden spark
            draw.rectangle([x - size_spark, y - size_spark, 
                          x + size_spark, y + size_spark], 
                         fill=color)
    
    return ai_image

def create_premium_app_icon(size=1024):
    """Create the complete premium app icon"""
    # Deep navy to warm gold gradient background
    navy_color = (15, 25, 45)      # Deep navy
    gold_color = (180, 140, 80)    # Warm gold
    
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
    final_image = final_image.filter(ImageFilter.GaussianBlur(radius=1))
    
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
    output_dir = 'Cheffy/Resources/AppIcons'
    os.makedirs(output_dir, exist_ok=True)
    
    print("🎨 Generating premium Michelin-inspired app icons...")
    
    for filename, size in sizes.items():
        print(f"Creating {filename} ({size}x{size})...")
        icon = create_premium_app_icon(size)
        icon.save(os.path.join(output_dir, filename), 'PNG', optimize=True)
    
    print("✅ All app icons generated successfully!")
    print("📱 Icons saved to: Cheffy/Resources/AppIcons/")

if __name__ == "__main__":
    generate_all_icon_sizes()
