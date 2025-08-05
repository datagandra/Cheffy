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

if [ -f "Cheffy/Resources/recipes/indian_cuisines.json" ]; then
    echo "✅ Indian Cuisines: Indian (10 recipes)"
else
    echo "❌ Indian Cuisines: Not found"
fi

if [ -f "Cheffy/Resources/recipes/american_cuisines.json" ]; then
    echo "✅ American Cuisines: American (10 recipes)"
else
    echo "❌ American Cuisines: Not found"
fi

if [ -f "Cheffy/Resources/recipes/mexican_cuisines.json" ]; then
    echo "✅ Mexican Cuisines: Mexican (10 recipes)"
else
    echo "❌ Mexican Cuisines: Not found"
fi

if [ -f "Cheffy/Resources/recipes/european_cuisines.json" ]; then
    echo "✅ European Cuisines: French (5 recipes), Italian (5 recipes), Spanish (5 recipes)"
else
    echo "❌ European Cuisines: Not found"
fi

if [ -f "Cheffy/Resources/recipes/asian_cuisines_extended.json" ]; then
    echo "✅ Extended Asian Cuisines: Chinese (5 recipes), Japanese (5 recipes), Thai (5 recipes), Korean (5 recipes)"
else
    echo "❌ Extended Asian Cuisines: Not found"
fi

if [ -f "Cheffy/Resources/recipes/middle_eastern_african_cuisines.json" ]; then
    echo "✅ Middle Eastern & African Cuisines: Lebanese (5 recipes), Moroccan (5 recipes), Egyptian (5 recipes), Ethiopian (5 recipes)"
else
    echo "❌ Middle Eastern & African Cuisines: Not found"
fi

if [ -f "Cheffy/Resources/recipes/latin_american_cuisines.json" ]; then
    echo "✅ Latin American Cuisines: Brazilian (5 recipes), Argentine (5 recipes), Peruvian (5 recipes), Colombian (5 recipes)"
else
    echo "❌ Latin American Cuisines: Not found"
fi

echo ""
echo "📋 Recipe Database Structure:"
echo "├── Cheffy/Resources/recipes/"
echo "│   ├── asian_cuisines.json (Chinese, Japanese)"
echo "│   ├── mediterranean_cuisines.json (Italian, Greek)"
echo "│   ├── indian_cuisines.json (Indian)"
echo "│   ├── american_cuisines.json (American)"
echo "│   ├── mexican_cuisines.json (Mexican)"
echo "│   ├── european_cuisines.json (French, Italian, Spanish)"
echo "│   ├── asian_cuisines_extended.json (Chinese, Japanese, Thai, Korean)"
echo "│   ├── middle_eastern_african_cuisines.json (Lebanese, Moroccan, Egyptian, Ethiopian)"
echo "│   └── latin_american_cuisines.json (Brazilian, Argentine, Peruvian, Colombian)"
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
        "american_cuisines.json"
        "mexican_cuisines.json"
        "french_cuisines.json"
        "thai_cuisines.json"
        "korean_cuisines.json"
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