#!/bin/bash

# Recipe Database Management Script for Cheffy
# This script helps organize and manage the comprehensive recipe database

echo "🍳 Cheffy Recipe Database Manager"
echo "=================================="
echo ""

# Create recipes directory if it doesn't exist
mkdir -p Cheffy/Resources/recipes

echo "📊 Current Recipe Database Status:"
echo ""

# Check existing recipe files
if [ -f "Cheffy/Resources/recipes/asian_cuisines.json" ]; then
    echo "✅ Asian Cuisines: Chinese (10 recipes), Japanese (10 recipes)"
else
    echo "❌ Asian Cuisines: Not found"
fi

if [ -f "Cheffy/Resources/recipes/mediterranean_cuisines.json" ]; then
    echo "✅ Mediterranean Cuisines: Italian (10 recipes), Greek (10 recipes)"
else
    echo "❌ Mediterranean Cuisines: Not found"
fi

echo ""
echo "📋 Recipe Database Structure:"
echo "├── Cheffy/Resources/recipes/"
echo "│   ├── asian_cuisines.json (Chinese, Japanese)"
echo "│   ├── mediterranean_cuisines.json (Italian, Greek)"
echo "│   ├── indian_cuisines.json (Coming soon)"
echo "│   ├── mexican_cuisines.json (Coming soon)"
echo "│   ├── french_cuisines.json (Coming soon)"
echo "│   ├── thai_cuisines.json (Coming soon)"
echo "│   ├── korean_cuisines.json (Coming soon)"
echo "│   └── american_cuisines.json (Coming soon)"
echo ""

echo "🎯 Each cuisine file contains:"
echo "   - 10 signature recipes per cuisine"
echo "   - Detailed ingredients lists"
echo "   - Step-by-step cooking instructions"
echo "   - Proper JSON formatting for app integration"
echo ""

echo "🔧 Database Management Options:"
echo "1. Validate JSON format"
echo "2. Count total recipes"
echo "3. List all cuisines"
echo "4. Check for missing files"
echo ""

# Function to validate JSON
validate_json() {
    echo "🔍 Validating JSON format..."
    for file in Cheffy/Resources/recipes/*.json; do
        if [ -f "$file" ]; then
            if python3 -m json.tool "$file" > /dev/null 2>&1; then
                echo "✅ $file - Valid JSON"
            else
                echo "❌ $file - Invalid JSON"
            fi
        fi
    done
}

# Function to count recipes
count_recipes() {
    echo "📊 Counting recipes..."
    total=0
    for file in Cheffy/Resources/recipes/*.json; do
        if [ -f "$file" ]; then
            count=$(python3 -c "import json; data=json.load(open('$file')); print(sum(len(cuisine) for cuisine in data['cuisines'].values()))" 2>/dev/null)
            if [ ! -z "$count" ]; then
                echo "📁 $file: $count recipes"
                total=$((total + count))
            fi
        fi
    done
    echo "📈 Total recipes: $total"
}

# Function to list cuisines
list_cuisines() {
    echo "🌍 Available cuisines:"
    for file in Cheffy/Resources/recipes/*.json; do
        if [ -f "$file" ]; then
            cuisines=$(python3 -c "import json; data=json.load(open('$file')); print(', '.join(data['cuisines'].keys()))" 2>/dev/null)
            if [ ! -z "$cuisines" ]; then
                echo "📁 $file: $cuisines"
            fi
        fi
    done
}

# Function to check missing files
check_missing() {
    echo "🔍 Checking for missing recipe files..."
    expected_files=(
        "asian_cuisines.json"
        "mediterranean_cuisines.json"
        "indian_cuisines.json"
        "mexican_cuisines.json"
        "french_cuisines.json"
        "thai_cuisines.json"
        "korean_cuisines.json"
        "american_cuisines.json"
    )
    
    for file in "${expected_files[@]}"; do
        if [ -f "Cheffy/Resources/recipes/$file" ]; then
            echo "✅ $file - Present"
        else
            echo "❌ $file - Missing"
        fi
    done
}

# Main menu
while true; do
    echo ""
    echo "Select an option (1-4, or 'q' to quit):"
    read -r choice
    
    case $choice in
        1)
            validate_json
            ;;
        2)
            count_recipes
            ;;
        3)
            list_cuisines
            ;;
        4)
            check_missing
            ;;
        q|Q)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please try again."
            ;;
    esac
done 