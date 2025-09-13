#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { CloudKit } = require('@apple/cloudkit');

// Configuration
const CONFIG = {
    // CloudKit Configuration
    containerIdentifier: 'iCloud.com.naveengandra.cheffy',
    environment: 'development', // or 'production'
    
    // Migration settings
    batchSize: 50, // Upload in batches to avoid rate limiting
    maxRetries: 3,
    retryDelay: 1000, // milliseconds
    
    // File paths
    recipesDir: 'Cheffy/Resources/recipes',
    outputDir: 'CloudKit/migrated',
    
    // Schema version
    schemaVersion: 1
};

// CloudKit client setup
const cloudKit = new CloudKit({
    containerIdentifier: CONFIG.containerIdentifier,
    environment: CONFIG.environment,
    // Add your CloudKit credentials here
    // apiToken: 'your-api-token',
    // privateKey: 'your-private-key'
});

// Utility functions
const utils = {
    // Convert cooking time category to minutes
    convertCookingTime(category) {
        const timeMap = {
            'under 5 min': 5,
            'under 10 min': 10,
            'under 15 min': 15,
            'under 20 min': 20,
            'under 25 min': 25,
            'under 30 min': 30,
            'under 40 min': 40,
            'under 45 min': 45,
            'under 50 min': 50,
            'under 1 hour': 60,
            'under 1.5 hours': 90,
            'under 2 hours': 120,
            'any time': 180
        };
        return timeMap[category.toLowerCase()] || 45;
    },
    
    // Convert dietary restrictions to standardized tags
    convertDietaryTags(dietType, restrictions = []) {
        const tags = new Set();
        
        // Add diet type tags
        switch (dietType.toLowerCase()) {
            case 'vegetarian':
                tags.add('Vegetarian');
                break;
            case 'vegan':
                tags.add('Vegan');
                tags.add('Vegetarian'); // Vegan implies vegetarian
                break;
            case 'non-vegetarian':
                tags.add('Non-Vegetarian');
                break;
        }
        
        // Add restriction tags
        restrictions.forEach(restriction => {
            switch (restriction.toLowerCase()) {
                case 'contains_dairy':
                    tags.add('Dairy-Free');
                    break;
                case 'contains_nuts':
                    tags.add('Nut-Free');
                    break;
                case 'contains_gluten':
                    tags.add('Gluten-Free');
                    break;
                case 'contains_eggs':
                    tags.add('Egg-Free');
                    break;
                case 'contains_soy':
                    tags.add('Soy-Free');
                    break;
                default:
                    tags.add(restriction.charAt(0).toUpperCase() + restriction.slice(1));
            }
        });
        
        return Array.from(tags);
    },
    
    // Generate unique ID for recipe
    generateRecipeId(recipeName, cuisine) {
        const slug = recipeName
            .toLowerCase()
            .replace(/[^a-z0-9\s-]/g, '')
            .replace(/\s+/g, '-')
            .substring(0, 50);
        return `${cuisine.toLowerCase()}-${slug}-${Date.now()}`;
    },
    
    // Convert cooking instructions to steps array
    convertInstructionsToSteps(instructions) {
        if (!instructions || typeof instructions !== 'string') {
            return ['No cooking instructions available'];
        }
        
        // Split by common delimiters and clean up
        const steps = instructions
            .split(/[.!?]\s*(?=[A-Z])/) // Split by sentence endings followed by capital letter
            .map(step => step.trim())
            .filter(step => step.length > 0)
            .map((step, index) => `${index + 1}. ${step}`);
        
        return steps.length > 0 ? steps : [instructions];
    },
    
    // Validate recipe data
    validateRecipe(recipe) {
        const errors = [];
        
        // Check required fields
        const requiredFields = ['recipe_name', 'cuisine', 'meal_type', 'ingredients'];
        requiredFields.forEach(field => {
            if (!recipe[field]) {
                errors.push(`Missing required field: ${field}`);
            }
        });
        
        // Validate ingredients
        if (recipe.ingredients && (!Array.isArray(recipe.ingredients) || recipe.ingredients.length === 0)) {
            errors.push('Ingredients list is empty or invalid');
        }
        
        // Validate cooking instructions
        if (!recipe.cooking_instructions || recipe.cooking_instructions.trim().length === 0) {
            errors.push('Cooking instructions are empty');
        }
        
        return {
            isValid: errors.length === 0,
            errors
        };
    }
};

// Recipe converter
class RecipeConverter {
    static convertToCloudKitRecord(jsonRecipe, cuisineName) {
        const validation = utils.validateRecipe(jsonRecipe);
        if (!validation.isValid) {
            throw new Error(`Invalid recipe: ${validation.errors.join(', ')}`);
        }
        
        const now = new Date();
        const recipeId = utils.generateRecipeId(jsonRecipe.recipe_name, cuisineName);
        
        return {
            recordType: 'Recipe',
            fields: {
                id: { value: recipeId },
                name: { value: jsonRecipe.recipe_name },
                cuisine: { value: cuisineName },
                mealType: { value: jsonRecipe.meal_type },
                dietaryTags: { value: utils.convertDietaryTags(
                    jsonRecipe.diet_type || 'general',
                    jsonRecipe.dietary_restrictions || []
                )},
                dietType: { value: jsonRecipe.diet_type || 'general' },
                calories: { value: jsonRecipe.calories_per_serving || null },
                cookingTimeMinutes: { value: utils.convertCookingTime(
                    jsonRecipe.cooking_time_category || 'Under 30 min'
                )},
                servings: { value: jsonRecipe.servings || 4 },
                difficulty: { value: jsonRecipe.difficulty || 'Medium' },
                region: { value: jsonRecipe.regional_origin || null },
                ingredients: { value: jsonRecipe.ingredients || [] },
                utensils: { value: jsonRecipe.utensils_required || null },
                steps: { value: utils.convertInstructionsToSteps(jsonRecipe.cooking_instructions) },
                chefTips: { value: jsonRecipe.chef_tips || null },
                lunchboxPresentation: { value: jsonRecipe.lunchbox_presentation || null },
                createdAt: { value: now },
                updatedAt: { value: now },
                schemaVersion: { value: CONFIG.schemaVersion },
                
                // Legacy fields for migration compatibility
                originalRecipeName: { value: jsonRecipe.recipe_name },
                originalCookingTimeCategory: { value: jsonRecipe.cooking_time_category || null },
                originalProteins: { value: jsonRecipe.proteins || null },
                originalDietaryRestrictions: { value: jsonRecipe.dietary_restrictions || null }
            }
        };
    }
}

// Migration manager
class RecipeMigrationManager {
    constructor() {
        this.stats = {
            totalProcessed: 0,
            successful: 0,
            failed: 0,
            errors: []
        };
    }
    
    async migrateAllRecipes() {
        console.log('🚀 Starting CloudKit Recipe Migration');
        console.log('=====================================');
        
        try {
            // Ensure output directory exists
            if (!fs.existsSync(CONFIG.outputDir)) {
                fs.mkdirSync(CONFIG.outputDir, { recursive: true });
            }
            
            // Get all JSON files
            const jsonFiles = this.getJsonFiles();
            console.log(`📁 Found ${jsonFiles.length} JSON files to process`);
            
            // Process each file
            for (const filePath of jsonFiles) {
                await this.processJsonFile(filePath);
            }
            
            // Generate migration report
            this.generateReport();
            
        } catch (error) {
            console.error('❌ Migration failed:', error);
            process.exit(1);
        }
    }
    
    getJsonFiles() {
        const files = [];
        const recipesDir = CONFIG.recipesDir;
        
        if (!fs.existsSync(recipesDir)) {
            throw new Error(`Recipes directory not found: ${recipesDir}`);
        }
        
        const items = fs.readdirSync(recipesDir);
        items.forEach(item => {
            if (item.endsWith('.json')) {
                files.push(path.join(recipesDir, item));
            }
        });
        
        return files;
    }
    
    async processJsonFile(filePath) {
        console.log(`\n📄 Processing: ${path.basename(filePath)}`);
        
        try {
            const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
            
            if (!data.cuisines) {
                console.log(`⚠️  Skipping ${filePath} - no 'cuisines' key found`);
                return;
            }
            
            const allRecords = [];
            
            // Process each cuisine in the file
            for (const [cuisineName, recipes] of Object.entries(data.cuisines)) {
                console.log(`  🍽️  Processing ${cuisineName}: ${recipes.length} recipes`);
                
                for (const recipe of recipes) {
                    try {
                        const record = RecipeConverter.convertToCloudKitRecord(recipe, cuisineName);
                        allRecords.push(record);
                        this.stats.totalProcessed++;
                    } catch (error) {
                        this.stats.failed++;
                        this.stats.errors.push({
                            file: path.basename(filePath),
                            cuisine: cuisineName,
                            recipe: recipe.recipe_name || 'Unknown',
                            error: error.message
                        });
                        console.log(`    ❌ Failed to convert recipe: ${error.message}`);
                    }
                }
            }
            
            // Upload records in batches
            if (allRecords.length > 0) {
                await this.uploadRecordsInBatches(allRecords, path.basename(filePath));
            }
            
        } catch (error) {
            console.error(`❌ Error processing ${filePath}:`, error);
            this.stats.failed++;
        }
    }
    
    async uploadRecordsInBatches(records, fileName) {
        console.log(`  📤 Uploading ${records.length} records in batches of ${CONFIG.batchSize}`);
        
        for (let i = 0; i < records.length; i += CONFIG.batchSize) {
            const batch = records.slice(i, i + CONFIG.batchSize);
            const batchNumber = Math.floor(i / CONFIG.batchSize) + 1;
            
            try {
                console.log(`    📦 Uploading batch ${batchNumber} (${batch.length} records)`);
                
                // In a real implementation, you would use CloudKit's batch upload API
                // For now, we'll save to local files for testing
                const batchFile = path.join(CONFIG.outputDir, `${fileName}_batch_${batchNumber}.json`);
                fs.writeFileSync(batchFile, JSON.stringify(batch, null, 2));
                
                this.stats.successful += batch.length;
                console.log(`    ✅ Batch ${batchNumber} saved to ${batchFile}`);
                
                // Add delay to avoid rate limiting
                await this.delay(100);
                
            } catch (error) {
                console.error(`    ❌ Failed to upload batch ${batchNumber}:`, error);
                this.stats.failed += batch.length;
            }
        }
    }
    
    async delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    
    generateReport() {
        console.log('\n📊 Migration Report');
        console.log('==================');
        console.log(`Total Processed: ${this.stats.totalProcessed}`);
        console.log(`Successful: ${this.stats.successful}`);
        console.log(`Failed: ${this.stats.failed}`);
        console.log(`Success Rate: ${((this.stats.successful / this.stats.totalProcessed) * 100).toFixed(1)}%`);
        
        if (this.stats.errors.length > 0) {
            console.log('\n❌ Errors:');
            this.stats.errors.forEach((error, index) => {
                console.log(`${index + 1}. ${error.file} - ${error.cuisine} - ${error.recipe}: ${error.error}`);
            });
        }
        
        // Save detailed report
        const reportFile = path.join(CONFIG.outputDir, 'migration_report.json');
        fs.writeFileSync(reportFile, JSON.stringify({
            timestamp: new Date().toISOString(),
            config: CONFIG,
            stats: this.stats
        }, null, 2));
        
        console.log(`\n📄 Detailed report saved to: ${reportFile}`);
    }
}

// Main execution
async function main() {
    const migrationManager = new RecipeMigrationManager();
    await migrationManager.migrateAllRecipes();
}

// Run migration
if (require.main === module) {
    main().catch(console.error);
}

module.exports = {
    RecipeConverter,
    RecipeMigrationManager,
    utils,
    CONFIG
};
