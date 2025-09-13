#!/bin/bash

# CloudKit Migration Runner
# This script will run the CloudKit migration to upload all JSON recipes

echo "🚀 Starting CloudKit Migration"
echo "============================="

# Check if we're in the right directory
if [ ! -f "Cheffy.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the Cheffy project root directory"
    exit 1
fi

# Check if CloudKit files exist
if [ ! -f "CloudKit/SimpleMigration.swift" ]; then
    echo "❌ Error: CloudKit migration files not found"
    exit 1
fi

echo "📁 Found CloudKit migration files"

# Build and run the migration
echo "🔨 Building migration script..."

# Create a simple Swift package for the migration
mkdir -p CloudKitMigration
cd CloudKitMigration

cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CloudKitMigration",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CloudKitMigration",
            dependencies: [],
            path: "Sources"
        )
    ]
)
EOF

mkdir -p Sources
cp ../CloudKit/SimpleMigration.swift Sources/main.swift

echo "🚀 Running CloudKit migration..."
echo "This will upload all your JSON recipes to CloudKit"
echo ""

# Run the migration
swift run

echo ""
echo "✅ Migration script completed!"
echo "Check the output above for results."
