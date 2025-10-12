#!/bin/bash

# Azure Translator Accelerator - Push to GitHub Script
# This script guides you through pushing the repository to GitHub

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Azure Translator Accelerator - GitHub Push Helper            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -f "env.example" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Error: Git is not installed"
    echo "   Install from: https://git-scm.com/downloads"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Check for secrets
echo "🔒 Checking for sensitive files..."
if [ -f ".env" ]; then
    echo "❌ ERROR: .env file found! This contains secrets."
    echo "   Run: rm .env"
    exit 1
fi

if find . -name "*.zip" -o -name "*.tar.gz" -o -name "deployment-*.json" | grep -q .; then
    echo "⚠️  WARNING: Deployment artifacts found"
    echo "   These should be ignored by .gitignore"
fi

echo "✅ No secrets found in root directory"
echo ""

# Initialize git if not already initialized
if [ ! -d ".git" ]; then
    echo "📝 Initializing git repository..."
    git init
    git branch -M main
    echo "✅ Git initialized with 'main' branch"
    echo ""
else
    echo "✅ Git repository already initialized"
    echo ""
fi

# Configure git user if not set
if [ -z "$(git config user.name)" ]; then
    echo "⚙️  Git user not configured"
    echo -n "Enter your name: "
    read username
    git config user.name "$username"
    echo ""
fi

if [ -z "$(git config user.email)" ]; then
    echo -n "Enter your email: "
    read useremail
    git config user.email "$useremail"
    echo ""
fi

echo "✅ Git configured:"
echo "   Name:  $(git config user.name)"
echo "   Email: $(git config user.email)"
echo ""

# Add all files
echo "📦 Staging files for commit..."
git add .

# Show what will be committed
echo ""
echo "📋 Files to be committed:"
git status --short | head -n 20
FILE_COUNT=$(git status --short | wc -l | tr -d ' ')
echo "   ... and $FILE_COUNT files total"
echo ""

# Check for accidentally staged secrets
echo "🔍 Scanning staged files for secrets..."
if git diff --cached | grep -qi "password\|api[_-]key\|secret.*=.*[\"']"; then
    echo "⚠️  WARNING: Possible secrets detected in staged files!"
    echo "   Please review carefully before committing"
    echo ""
    read -p "Continue anyway? (yes/no): " response
    if [ "$response" != "yes" ]; then
        echo "❌ Aborted by user"
        exit 1
    fi
else
    echo "✅ No obvious secrets detected"
fi
echo ""

# Create commit
echo "💾 Creating initial commit..."
git commit -m "Initial commit: Azure AI Translator Solution Accelerator

- Complete FastAPI backend with NMT and LLM translation
- React TypeScript frontend with 5 feature tabs
- Bicep infrastructure templates for Azure deployment
- Batch translation with Azure Storage integration
- Side-by-side NMT vs LLM comparison
- Dictionary lookup with examples
- Comprehensive README with setup guides
- Application Insights integration
- Security best practices (Managed Identity, Key Vault)" || echo "Commit already exists or no changes"

echo ""
echo "✅ Local repository ready!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 NEXT STEPS:"
echo ""
echo "1. Create a new repository on GitHub:"
echo "   → Go to: https://github.com/new"
echo "   → Name: azure-translator-accelerator (or your choice)"
echo "   → Description: Azure AI Translator solution accelerator"
echo "   → Public: ✓"
echo "   → Do NOT initialize with README/gitignore/license"
echo "   → Click 'Create repository'"
echo ""
echo "2. Copy your repository URL (shown on GitHub after creation)"
echo "   Example: https://github.com/yourusername/azure-translator-accelerator.git"
echo ""
read -p "Enter your GitHub repository URL: " repo_url

if [ -z "$repo_url" ]; then
    echo ""
    echo "⚠️  No URL provided. To push manually, run:"
    echo ""
    echo "   git remote add origin <your-repo-url>"
    echo "   git push -u origin main"
    echo ""
    exit 0
fi

# Add remote
echo ""
echo "🔗 Adding GitHub remote..."
git remote remove origin 2>/dev/null || true
git remote add origin "$repo_url"
git remote -v

echo ""
echo "🚀 Pushing to GitHub..."
echo "   This may take a minute..."
echo ""

if git push -u origin main; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                   ✅ SUCCESS!                                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Your repository is now public at:"
    echo "   $repo_url"
    echo ""
    echo "📝 Don't forget to:"
    echo "   1. Add topics: azure, translator, ai, llm, gpt-4o, react, fastapi"
    echo "   2. Add a repository description"
    echo "   3. Update README.md with your actual repo URL"
    echo ""
    echo "🎉 Share your accelerator with the community!"
else
    echo ""
    echo "❌ Push failed. Common issues:"
    echo "   - Authentication: Use Personal Access Token or SSH key"
    echo "   - URL: Verify the repository URL is correct"
    echo ""
    echo "Manual push command:"
    echo "   git push -u origin main"
fi

echo ""
echo "For detailed instructions, see: GIT_SETUP.md"
echo ""

