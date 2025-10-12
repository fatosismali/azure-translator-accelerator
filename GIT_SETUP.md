# Git Setup Guide - Push to Public Repository

## ✅ Repository is Clean and Ready!

All sensitive files, deployment artifacts, and temporary files have been removed.

---

## 📝 Pre-Push Checklist

✅ Deployment artifacts removed (*.zip, *.tar.gz, deployment-*.json)  
✅ `.env` file removed (secrets protected)  
✅ Status/log files removed  
✅ `.gitignore` updated with deployment patterns  
✅ README updated with clear setup instructions  
✅ `env.example` present (template for users)  

---

## 🚀 Git Commands - Step by Step

### Step 1: Initialize Git Repository

```bash
cd /Users/bytebiscuit/Desktop/ML/AITranslatorAccelerator-Fatos

# Initialize git
git init

# Verify .gitignore is working
git status
```

**Expected output**: Should NOT show `.env`, `node_modules/`, `__pycache__/`, or any `.zip` files

---

### Step 2: Configure Git (if not already done)

```bash
# Set your name and email
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Optional: Set default branch to 'main'
git config --global init.defaultBranch main
```

---

### Step 3: Add All Files

```bash
# Add all files (respects .gitignore)
git add .

# Review what will be committed
git status

# Check for accidentally added secrets
git diff --cached | grep -i "password\|key\|secret" || echo "✅ No secrets found"
```

**⚠️ IMPORTANT**: If you see any secrets or API keys, STOP and remove them!

---

### Step 4: Create Initial Commit

```bash
# Create the first commit
git commit -m "Initial commit: Azure AI Translator Solution Accelerator

- Complete FastAPI backend with NMT and LLM translation
- React TypeScript frontend with 5 feature tabs
- Bicep infrastructure templates for Azure deployment
- Batch translation with Azure Storage integration
- Side-by-side NMT vs LLM comparison
- Dictionary lookup with examples
- Comprehensive README with setup guides
- Application Insights integration
- Security best practices (Managed Identity, Key Vault)"
```

---

### Step 5: Create GitHub Repository

**Option A: Via GitHub Website** (Recommended)

1. Go to https://github.com/new
2. Repository name: `azure-translator-accelerator` (or your choice)
3. Description: "Production-grade Azure AI Translator solution accelerator with NMT and LLM translation, batch processing, and React UI"
4. **Public** ✅
5. **Do NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"
7. **Copy the repository URL** (e.g., `https://github.com/yourusername/azure-translator-accelerator.git`)

**Option B: Via GitHub CLI** (if you have `gh` installed)

```bash
gh repo create azure-translator-accelerator \
  --public \
  --description "Production-grade Azure AI Translator solution accelerator" \
  --source . \
  --remote origin
```

---

### Step 6: Add Remote and Push

```bash
# Add GitHub as remote (replace with YOUR repository URL)
git remote add origin https://github.com/YOUR_USERNAME/azure-translator-accelerator.git

# Verify remote
git remote -v

# Push to GitHub (first time)
git push -u origin main

# If your branch is named 'master' instead of 'main':
# git branch -M main
# git push -u origin main
```

---

### Step 7: Verify on GitHub

1. Go to your repository: `https://github.com/YOUR_USERNAME/azure-translator-accelerator`
2. Check that:
   - ✅ README.md displays correctly
   - ✅ File structure is complete
   - ✅ No `.env` file is visible
   - ✅ No deployment artifacts (*.zip files)
   - ✅ `env.example` is present

---

## 📚 Post-Push Tasks

### Update README with Correct URLs

Edit README.md and replace placeholder URLs:

```bash
# Find and replace
sed -i '' 's|<your-repo-url>|https://github.com/YOUR_USERNAME/azure-translator-accelerator.git|g' README.md

# Commit the change
git add README.md
git commit -m "docs: update repository URL in README"
git push
```

### Add GitHub Badges (Optional)

Add these to the top of your README.md:

```markdown
[![GitHub](https://img.shields.io/github/license/YOUR_USERNAME/azure-translator-accelerator)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/YOUR_USERNAME/azure-translator-accelerator)](https://github.com/YOUR_USERNAME/azure-translator-accelerator/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/YOUR_USERNAME/azure-translator-accelerator)](https://github.com/YOUR_USERNAME/azure-translator-accelerator/issues)
```

### Enable GitHub Features

1. **GitHub Pages** (Optional):
   - Settings → Pages → Deploy from branch: `main` → `/docs`

2. **Issues**:
   - Should be enabled by default

3. **Discussions** (Optional):
   - Settings → Features → Enable Discussions

4. **Topics** (Recommended):
   - Add topics: `azure`, `translator`, `ai`, `llm`, `gpt-4o`, `react`, `fastapi`, `bicep`

---

## 🔒 Security Best Practices

### Before Making Repository Public

✅ **No secrets in commit history**
```bash
# Search entire git history for secrets
git log -S "sk-" --all  # Search for OpenAI keys
git log -S "password" --all
git log -S "secret" --all
```

✅ **No hardcoded credentials**
```bash
# Search all tracked files
git grep -i "password\|api[_-]key\|secret" -- '*.py' '*.ts' '*.js' '*.json'
```

✅ **Verify .gitignore is working**
```bash
git status --ignored
# Should show .env, node_modules/, etc. as ignored
```

### If You Accidentally Committed Secrets

**DO NOT** just delete the file and commit again! The secret is still in git history.

**Solution 1: Start Fresh** (if no public commits yet)
```bash
# Remove .git directory
rm -rf .git

# Re-initialize
git init
git add .
git commit -m "Initial commit"
```

**Solution 2: Use BFG Repo-Cleaner** (for existing public repos)
```bash
# Install BFG
brew install bfg  # macOS

# Remove secrets from history
bfg --delete-files .env --no-blob-protection
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

---

## 🎯 Quick Reference - Common Commands

```bash
# Check status
git status

# Add new files
git add <file>
git add .  # Add all

# Commit changes
git commit -m "description of changes"

# Push to GitHub
git push

# Pull latest changes
git pull

# Create new branch
git checkout -b feature/new-feature

# Switch branches
git checkout main

# View commit history
git log --oneline

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1
```

---

## 📞 Need Help?

- **Git Basics**: https://git-scm.com/book/en/v2
- **GitHub Docs**: https://docs.github.com/
- **Remove Secrets**: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository

---

## ✨ Your Repository is Ready!

You can now share your repository URL with others:

```
https://github.com/YOUR_USERNAME/azure-translator-accelerator
```

Users can clone and follow the README to set up locally or deploy to Azure! 🚀

