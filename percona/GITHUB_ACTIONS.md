# GitHub Actions Integration

## Current Setup

Your existing GitHub Actions workflow ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml:1)) builds Docker images for `apache` and `fpm` directories on pull requests. 

**The Percona setup will NOT interfere with this workflow** because:

1. ✅ Percona is in a separate `percona/` directory
2. ✅ The CI workflow only builds `apache` and `fpm` images
3. ✅ Percona images are built locally for deployment, not pushed to Docker Hub
4. ✅ The main [`docker-compose.yml`](../docker-compose.yml:1) changes are deployment-specific

## What Changed in Your Repo

### Files That Won't Affect CI
- ✅ `percona/` directory - completely separate, ignored by existing CI
- ✅ [`docker-compose.yml`](../docker-compose.yml:1) - only used for deployment, not CI
- ✅ All Percona scripts and configs - deployment-only

### Files That CI Still Builds
- ✅ `apache/` - still builds as before
- ✅ `fpm/` - still builds as before
- ✅ `beta-apache/`, `beta-fpm/` - not affected

## How It Works in Production

### Development/CI Flow (Unchanged)
```
Pull Request → GitHub Actions → Build apache/fpm → Test → Merge
```

### Deployment Flow (New)
```
Deploy Server:
1. Start Percona stack:   cd percona && docker-compose -f docker-compose.percona.yml up -d
2. Start Mautic stack:    cd .. && docker-compose up -d
3. Both stacks communicate via mautic-db-network
```

## Optional: Add Percona Build Testing to CI

If you want to test that the Percona image builds correctly in CI, you have two options:

### Option 1: Add to Existing CI Workflow

Update [`.github/workflows/ci.yml`](../.github/workflows/ci.yml:10) to include Percona:

```yaml
strategy:
  matrix:
    image: [apache, fpm, percona]
steps:
  - name: Build ${{ matrix.image }} image
    uses: docker/build-push-action@v2
    with:
      context: ${{ matrix.image }}
      file: ${{ matrix.image == 'percona' && 'percona/Dockerfile.percona' || format('{0}/Dockerfile', matrix.image) }}
      push: false
```

### Option 2: Create Separate Percona CI Workflow

Create a new workflow specifically for Percona testing (recommended).

## Recommendation

**Keep CI as-is** for these reasons:

1. **Separation of Concerns**: Mautic image builds are separate from database builds
2. **Faster CI**: Not building Percona saves CI time
3. **Different Purposes**: 
   - Mautic images → pushed to Docker Hub
   - Percona image → built locally for deployment only
4. **Less Complexity**: Simpler CI workflow

## If You Need Percona CI Testing

Only add Percona to CI if you:
- Frequently modify Percona configuration
- Want to ensure Percona builds before deployment
- Need to test analysis scripts in CI

For most use cases, testing Percona locally before deployment is sufficient.

## Local Testing Before Deployment

Instead of CI, test Percona locally:

```bash
# Test build
cd percona
docker-compose -f docker-compose.percona.yml build

# Test startup
docker-compose -f docker-compose.percona.yml up

# Test scripts
docker exec percona-db /opt/analysis/analyze-slow-queries.sh

# Cleanup
docker-compose -f docker-compose.percona.yml down
```

## Git Workflow

### What to Commit
✅ All files in `percona/` directory (except `.env.percona.local`)
✅ Modified [`docker-compose.yml`](../docker-compose.yml:1)
✅ Documentation files

### What NOT to Commit (Already in .gitignore)
❌ `percona/.env.percona.local` (contains passwords)
❌ `percona/logs/` (log files)
❌ `*.sql` backup files

### Example Git Commands

```bash
# Stage Percona files
git add percona/

# Stage modified docker-compose.yml
git add docker-compose.yml

# Commit
git commit -m "Add Percona slow query analysis setup"

# Push
git push origin main
```

## Deployment Workflow

### 1. Development/Testing
```bash
# Developer makes changes
git checkout -b feature/percona-setup

# Test locally
cd percona
docker-compose -f docker-compose.percona.yml up -d

# Commit and push
git add .
git commit -m "Add Percona setup"
git push origin feature/percona-setup

# Create PR → CI runs (builds apache/fpm only)
```

### 2. Production Deployment
```bash
# On production server
git pull origin main

# Configure environment
cd percona
cp .env.percona .env.percona.local
nano .env.percona.local  # Set production credentials

# Deploy
docker-compose -f docker-compose.percona.yml up -d
cd ..
docker-compose up -d
```

## CI/CD Pipeline Considerations

If using a CI/CD pipeline for deployment, add these steps:

```yaml
# Example GitHub Actions deployment workflow
deploy:
  runs-on: ubuntu-latest
  steps:
    - name: Deploy Percona
      run: |
        ssh ${{ secrets.DEPLOY_HOST }} << 'EOF'
          cd /path/to/project/percona
          docker-compose -f docker-compose.percona.yml pull  # if using pre-built images
          docker-compose -f docker-compose.percona.yml up -d
        EOF
    
    - name: Deploy Mautic
      run: |
        ssh ${{ secrets.DEPLOY_HOST }} << 'EOF'
          cd /path/to/project
          docker-compose up -d
        EOF
```

## Summary

### Current State ✅
- Existing CI builds apache/fpm images
- Percona is separate and doesn't interfere
- No changes needed to CI workflow

### Recommended Approach ✅
- Keep CI as-is
- Test Percona locally before deployment
- Deploy Percona manually or via deployment pipeline

### If You Want CI Testing 🔧
- Add Percona to matrix in existing CI, OR
- Create separate workflow for Percona

The Percona setup is designed to be deployment-focused and won't impact your existing CI/CD pipeline unless you explicitly want it to.
