#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const chalk = require('chalk');

// Schema validation for CloudKit migration
class SchemaValidator {
    constructor() {
        this.errors = [];
        this.warnings = [];
        this.stats = {
            totalFiles: 0,
            totalRecipes: 0,
            validRecipes: 0,
            invalidRecipes: 0
        };
    }
    
    async validateAll() {
        console.log(chalk.blue('🔍 Validating Recipe Schema'));
        console.log('=====================================');
        
        const recipesDir = 'Cheffy/Resources/recipes';
        
        if (!fs.existsSync(recipesDir)) {
            console.error(chalk.red('❌ Recipes directory not found:', recipesDir));
            process.exit(1);
        }
        
        const jsonFiles = this.getJsonFiles(recipesDir);
        console.log(chalk.green(`📁 Found ${jsonFiles.length} JSON files to validate`));
        
        for (const filePath of jsonFiles) {
            await this.validateFile(filePath);
        }
        
        this.generateReport();
    }
    
    getJsonFiles(dir) {
        return fs.readdirSync(dir)
            .filter(file => file.endsWith('.json'))
            .map(file => path.join(dir, file));
    }
    
    async validateFile(filePath) {
        console.log(`\n📄 Validating: ${path.basename(filePath)}`);
        
        try {
            const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
            this.stats.totalFiles++;
            
            if (!data.cuisines) {
                this.addError(filePath, 'Missing "cuisines" key');
                return;
            }
            
            for (const [cuisineName, recipes] of Object.entries(data.cuisines)) {
                if (!Array.isArray(recipes)) {
                    this.addError(filePath, `Invalid recipes array for cuisine: ${cuisineName}`);
                    continue;
                }
                
                for (const recipe of recipes) {
                    this.stats.totalRecipes++;
                    this.validateRecipe(recipe, filePath, cuisineName);
                }
            }
            
        } catch (error) {
            this.addError(filePath, `JSON parse error: ${error.message}`);
        }
    }
    
    validateRecipe(recipe, filePath, cuisineName) {
        const recipeName = recipe.recipe_name || 'Unknown';
        
        // Required fields validation
        const requiredFields = [
            'recipe_name',
            'cuisine', 
            'meal_type',
            'ingredients',
            'cooking_instructions'
        ];
        
        for (const field of requiredFields) {
            if (!recipe[field]) {
                this.addError(filePath, `${cuisineName}/${recipeName}: Missing required field "${field}"`);
                return;
            }
        }
        
        // Field type validation
        this.validateFieldType(recipe, 'recipe_name', 'string', filePath, cuisineName, recipeName);
        this.validateFieldType(recipe, 'cuisine', 'string', filePath, cuisineName, recipeName);
        this.validateFieldType(recipe, 'meal_type', 'string', filePath, cuisineName, recipeName);
        this.validateFieldType(recipe, 'ingredients', 'array', filePath, cuisineName, recipeName);
        this.validateFieldType(recipe, 'cooking_instructions', 'string', filePath, cuisineName, recipeName);
        
        // Meal type validation
        if (recipe.meal_type && !['Kids', 'Regular'].includes(recipe.meal_type)) {
            this.addWarning(filePath, `${cuisineName}/${recipeName}: Invalid meal_type "${recipe.meal_type}"`);
        }
        
        // Ingredients validation
        if (recipe.ingredients && (!Array.isArray(recipe.ingredients) || recipe.ingredients.length === 0)) {
            this.addError(filePath, `${cuisineName}/${recipeName}: Empty or invalid ingredients array`);
        }
        
        // Cooking instructions validation
        if (recipe.cooking_instructions && recipe.cooking_instructions.trim().length === 0) {
            this.addError(filePath, `${cuisineName}/${recipeName}: Empty cooking instructions`);
        }
        
        // Servings validation
        if (recipe.servings && (typeof recipe.servings !== 'number' || recipe.servings <= 0)) {
            this.addError(filePath, `${cuisineName}/${recipeName}: Invalid servings value`);
        }
        
        // Calories validation
        if (recipe.calories_per_serving && (typeof recipe.calories_per_serving !== 'number' || recipe.calories_per_serving < 0)) {
            this.addError(filePath, `${cuisineName}/${recipeName}: Invalid calories value`);
        }
        
        // Cooking time category validation
        if (recipe.cooking_time_category) {
            const validTimeCategories = [
                'Under 5 min', 'Under 10 min', 'Under 15 min', 'Under 20 min',
                'Under 25 min', 'Under 30 min', 'Under 40 min', 'Under 45 min',
                'Under 50 min', 'Under 1 hour', 'Under 1.5 hours', 'Under 2 hours',
                'Any Time'
            ];
            
            if (!validTimeCategories.includes(recipe.cooking_time_category)) {
                this.addWarning(filePath, `${cuisineName}/${recipeName}: Unknown cooking time category "${recipe.cooking_time_category}"`);
            }
        }
        
        // Difficulty validation
        if (recipe.difficulty && !['Easy', 'Medium', 'Hard'].includes(recipe.difficulty)) {
            this.addWarning(filePath, `${cuisineName}/${recipeName}: Unknown difficulty "${recipe.difficulty}"`);
        }
        
        // Dietary restrictions validation
        if (recipe.dietary_restrictions && Array.isArray(recipe.dietary_restrictions)) {
            const validRestrictions = [
                'contains_dairy', 'contains_nuts', 'contains_gluten', 'contains_eggs',
                'contains_soy', 'vegetarian', 'vegan', 'gluten_free', 'dairy_free',
                'nut_free', 'egg_free', 'soy_free'
            ];
            
            for (const restriction of recipe.dietary_restrictions) {
                if (!validRestrictions.includes(restriction)) {
                    this.addWarning(filePath, `${cuisineName}/${recipeName}: Unknown dietary restriction "${restriction}"`);
                }
            }
        }
        
        this.stats.validRecipes++;
    }
    
    validateFieldType(recipe, fieldName, expectedType, filePath, cuisineName, recipeName) {
        const value = recipe[fieldName];
        if (value === undefined || value === null) return;
        
        let actualType;
        if (Array.isArray(value)) {
            actualType = 'array';
        } else {
            actualType = typeof value;
        }
        
        if (actualType !== expectedType) {
            this.addError(filePath, `${cuisineName}/${recipeName}: Field "${fieldName}" should be ${expectedType}, got ${actualType}`);
        }
    }
    
    addError(filePath, message) {
        this.errors.push({ file: path.basename(filePath), message });
        this.stats.invalidRecipes++;
    }
    
    addWarning(filePath, message) {
        this.warnings.push({ file: path.basename(filePath), message });
    }
    
    generateReport() {
        console.log('\n📊 Validation Report');
        console.log('===================');
        
        console.log(chalk.green(`✅ Valid Recipes: ${this.stats.validRecipes}`));
        console.log(chalk.red(`❌ Invalid Recipes: ${this.stats.invalidRecipes}`));
        console.log(chalk.yellow(`⚠️  Warnings: ${this.warnings.length}`));
        console.log(`📁 Files Processed: ${this.stats.totalFiles}`);
        console.log(`📝 Total Recipes: ${this.stats.totalRecipes}`);
        
        const successRate = ((this.stats.validRecipes / this.stats.totalRecipes) * 100).toFixed(1);
        console.log(`📈 Success Rate: ${successRate}%`);
        
        if (this.errors.length > 0) {
            console.log('\n❌ Errors:');
            this.errors.forEach((error, index) => {
                console.log(chalk.red(`${index + 1}. ${error.file}: ${error.message}`));
            });
        }
        
        if (this.warnings.length > 0) {
            console.log('\n⚠️  Warnings:');
            this.warnings.forEach((warning, index) => {
                console.log(chalk.yellow(`${index + 1}. ${warning.file}: ${warning.message}`));
            });
        }
        
        // Save detailed report
        const report = {
            timestamp: new Date().toISOString(),
            stats: this.stats,
            errors: this.errors,
            warnings: this.warnings
        };
        
        const reportFile = 'CloudKit/validation_report.json';
        fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
        console.log(`\n📄 Detailed report saved to: ${reportFile}`);
        
        // Exit with error code if there are validation errors
        if (this.errors.length > 0) {
            process.exit(1);
        }
    }
}

// Main execution
async function main() {
    const validator = new SchemaValidator();
    await validator.validateAll();
}

// Run validation
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { SchemaValidator };
