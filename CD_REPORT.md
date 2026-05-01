# Continuous Deployment (CD) Pipeline Report
**Intelligent Room Booking System**
**Generated:** May 1, 2026

---

## Executive Summary

The Continuous Deployment pipeline automates the release process by building Docker container images and pushing them to Docker Hub registry. The CD pipeline is triggered exclusively on semantic version tags, enabling a clear separation between development code (CI) and production releases (CD).

**Key Metrics:**
- **Trigger:** Git tags only (`dev-v*`, `stg-v*`, `prod-v*`)
- **Registry:** Docker Hub (`docker.io`)
- **Environments:** 3 (Development, Staging, Production)
- **Deployment Time:** ~2-3 minutes per release
- **Status:** ✅ Active and Operational

---

## 1. CD Pipeline Architecture

**Workflow File:** `.github/workflows/cd.yml`

### Overview

```
Git Repository
    │
    ├─ Regular Commits
    │  └─→ CI Pipeline (tests)
    │     └─→ No deployment
    │
    └─ Version Tag
       (dev-v1.0.0 | stg-v1.0.0 | prod-v1.0.0)
       └─→ CD Pipeline
           ├─ Parse tag
           ├─ Build Docker image
           ├─ Push to registry
           └─ Create summary
```

### Key Difference from CI

| Aspect | CI | CD |
|--------|----|----|
| Trigger | Push to branches, PRs | Git tags only |
| What Runs | Tests, linting, coverage | Docker build, registry push |
| Who Can Trigger | Any push/PR | Tag push (typically release lead) |
| Frequency | Every commit | Per release (manual) |
| Duration | 5 minutes | 2-3 minutes |
| Failure Impact | Blocks merge | Blocks deployment |

---

## 2. Trigger Mechanism: Git Tags

### Tag-Based Triggering

```yaml
on:
  push:
    tags:
      - 'dev-v*'
      - 'stg-v*'
      - 'prod-v*'
```

**Workflow triggers ONLY when:**
1. You push a git tag matching the patterns
2. Tag matches one of three environment prefixes
3. Commit associated with tag is valid

**Examples:**

✅ **Triggers CD:**
- `dev-v1.0.0` → Development environment
- `stg-v2.1.5` → Staging environment
- `prod-v3.0.0-rc1` → Production environment

❌ **Does NOT trigger CD:**
- `v1.0.0` (missing prefix)
- `release-1.0.0` (wrong prefix)
- Regular commit (no tag)
- PR (CI runs, not CD)

### Creating a Release Tag

**In Git:**
```bash
# Development release
git tag dev-v1.0.0
git push origin dev-v1.0.0

# Staging release
git tag stg-v1.0.0
git push origin stg-v1.0.0

# Production release
git tag prod-v1.0.0
git push origin prod-v1.0.0
```

**Via GitHub UI:**
1. Go to Releases page
2. Click "Create a new release"
3. Tag version: `dev-v1.0.0` (must match pattern)
4. Target: `develop` or `master` branch
5. Release title and notes (optional)
6. Click "Publish release"

---

## 3. CD Pipeline Job: Build and Push

### Job Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| Job Name | `build-and-push` | Single monolithic job |
| Runner | `ubuntu-22.04` | Latest stable Ubuntu |
| Parallelization | Single job | Sequential execution |

### Environment Variables

```yaml
env:
  REGISTRY: ${{ secrets.DOCKER_USERNAME }}/intelligent_room_booking
```

**Dynamic Registry Name:**
- Uses GitHub secret `DOCKER_USERNAME`
- Registry format: `{USERNAME}/intelligent_room_booking`
- Example: `john_doe/intelligent_room_booking`

**Required GitHub Secrets:**

```
DOCKER_USERNAME    # Docker Hub username
DOCKER_PASSWORD    # Docker Hub authentication token or password
```

**How to Set Up Secrets:**

1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add `DOCKER_USERNAME` with your Docker Hub username
4. Add `DOCKER_PASSWORD` with your Docker Hub token
   - Generate token at: https://hub.docker.com/settings/security

---

## 4. Pipeline Steps (Sequential)

### Step 1: Checkout Repository

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
```

- **Purpose:** Clone repository at the tag commit
- **Duration:** ~5-10 seconds
- **Failure Impact:** ❌ BLOCKING - Pipeline stops
- **What's Checked Out:** Source code needed for Docker build

---

### Step 2: Set Up Docker Buildx

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
```

- **Purpose:** Configure Docker for advanced build features
- **Features Enabled:**
  - Multi-platform builds (ARM, AMD, etc.)
  - BuildKit caching for faster builds
  - Inline build cache
  - Image layer optimization
- **Duration:** ~10-15 seconds
- **Failure Impact:** ❌ BLOCKING
- **Why:** Buildx provides better build performance and capabilities than default Docker

---

### Step 3: Log In to Docker Registry

```yaml
- name: Log in to Docker Registry
  uses: docker/login-action@v3
  with:
    registry: docker.io
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
```

- **Purpose:** Authenticate with Docker Hub
- **Registry:** `docker.io` (Docker Hub)
- **Credentials:** From GitHub secrets
- **Duration:** ~3-5 seconds
- **Failure Impact:** ❌ BLOCKING
- **Security:** Credentials never logged; temporary auth token used

---

### Step 4: Extract Version and Tag

```yaml
- name: Extract Version and Tag
  id: extract
  shell: bash
  run: |
    TAG=${GITHUB_REF#refs/tags/}
    echo "Full Tag: $TAG"

    if [[ "$TAG" == dev-v* ]]; then
      VERSION=${TAG#dev-v}
      echo "VERSION=$VERSION" >> $GITHUB_OUTPUT
      echo "ENV=dev" >> $GITHUB_OUTPUT
    elif [[ "$TAG" == stg-v* ]]; then
      VERSION=${TAG#stg-v}
      echo "VERSION=$VERSION" >> $GITHUB_OUTPUT
      echo "ENV=stg" >> $GITHUB_OUTPUT
    elif [[ "$TAG" == prod-v* ]]; then
      VERSION=${TAG#prod-v}
      echo "VERSION=$VERSION" >> $GITHUB_OUTPUT
      echo "ENV=prod" >> $GITHUB_OUTPUT
    else
      echo "Invalid tag format"
      exit 1
    fi
```

**What This Does:**

1. **Extract full tag** from git reference
   - Input: `refs/tags/prod-v1.2.3`
   - Output: `prod-v1.2.3`

2. **Parse tag format**
   - Matches against three patterns: `dev-v*`, `stg-v*`, `prod-v*`
   - Extracts environment prefix (dev, stg, prod)
   - Extracts version number (1.2.3)

3. **Set output variables** for later steps
   - `steps.extract.outputs.VERSION` → `1.2.3`
   - `steps.extract.outputs.ENV` → `dev` | `stg` | `prod`

**Example Processing:**

| Input Tag | VERSION | ENV |
|-----------|---------|-----|
| `dev-v1.0.0` | `1.0.0` | `dev` |
| `stg-v2.1.5` | `2.1.5` | `stg` |
| `prod-v3.0.0-rc1` | `3.0.0-rc1` | `prod` |

- **Duration:** ~2-3 seconds
- **Failure Impact:** ❌ BLOCKING
- **Error:** If tag doesn't match any pattern, pipeline exits with error code 1

---

### Step 5: Build and Push Docker Images

```yaml
- name: Build and Push Docker Images
  shell: bash
  run: |
    DEPLOY_ENV=${{ steps.extract.outputs.ENV }}
    VERSION=${{ steps.extract.outputs.VERSION }}

    if [[ "$DEPLOY_ENV" == "dev" ]]; then
      docker build -t $REGISTRY:dev-$VERSION .
      docker tag $REGISTRY:dev-$VERSION $REGISTRY:master
      docker push $REGISTRY:dev-$VERSION
      docker push $REGISTRY:master
    elif [[ "$DEPLOY_ENV" == "stg" ]]; then
      docker build -t $REGISTRY:stg-$VERSION .
      docker tag $REGISTRY:stg-$VERSION $REGISTRY:testing
      docker push $REGISTRY:stg-$VERSION
      docker push $REGISTRY:testing
    elif [[ "$DEPLOY_ENV" == "prod" ]]; then
      docker build -t $REGISTRY:prod-$VERSION .
      docker tag $REGISTRY:prod-$VERSION $REGISTRY:production
      docker push $REGISTRY:prod-$VERSION
      docker push $REGISTRY:production
    fi
```

**What This Step Does:**

1. **Retrieves extracted values** from previous step
2. **Builds Docker image** using `Dockerfile` in repository root
3. **Tags image** with version-specific tag
4. **Creates alias tag** for environment
5. **Pushes both tags** to Docker Hub registry

**Environment-Specific Behavior:**

#### Development (dev-v1.0.0)

```bash
# Build image
docker build -t john_doe/intelligent_room_booking:dev-1.0.0 .

# Tag alias
docker tag john_doe/intelligent_room_booking:dev-1.0.0 \
           john_doe/intelligent_room_booking:master

# Push both
docker push john_doe/intelligent_room_booking:dev-1.0.0
docker push john_doe/intelligent_room_booking:master
```

**Images Available After:**
- `john_doe/intelligent_room_booking:dev-1.0.0` (versioned)
- `john_doe/intelligent_room_booking:master` (latest dev, always points to most recent)

#### Staging (stg-v2.1.5)

```bash
docker build -t john_doe/intelligent_room_booking:stg-2.1.5 .
docker tag john_doe/intelligent_room_booking:stg-2.1.5 \
           john_doe/intelligent_room_booking:testing
docker push john_doe/intelligent_room_booking:stg-2.1.5
docker push john_doe/intelligent_room_booking:testing
```

**Images Available After:**
- `john_doe/intelligent_room_booking:stg-2.1.5` (versioned)
- `john_doe/intelligent_room_booking:testing` (latest staging)

#### Production (prod-v3.0.0)

```bash
docker build -t john_doe/intelligent_room_booking:prod-3.0.0 .
docker tag john_doe/intelligent_room_booking:prod-3.0.0 \
           john_doe/intelligent_room_booking:production
docker push john_doe/intelligent_room_booking:prod-3.0.0
docker push john_doe/intelligent_room_booking:production
```

**Images Available After:**
- `john_doe/intelligent_room_booking:prod-3.0.0` (versioned)
- `john_doe/intelligent_room_booking:production` (latest production)

**Building Process:**

1. Reads `Dockerfile` from repository root
2. Executes each instruction sequentially
3. Creates image layers from each step
4. Caches layers for faster future builds
5. Final image compressed before push

**Push Process:**

1. Connects to Docker Hub
2. Uploads image layers
3. Registers image with tags
4. Updates tag pointers (master, testing, production)
5. Completes when all data transferred

- **Duration:** 60-120 seconds (depends on image size and changes)
- **Failure Impact:** ❌ BLOCKING
- **Common Failures:**
  - Dockerfile errors during build
  - Registry authentication failed
  - Insufficient disk space
  - Network timeout during push

---

### Step 6: Create Deployment Summary

```yaml
- name: Create deployment summary
  shell: bash
  run: |
    DEPLOY_ENV=${{ steps.extract.outputs.ENV }}
    VERSION=${{ steps.extract.outputs.VERSION }}

    {
      echo "## Docker Image Pushed"
      echo ""
      echo "**Image:** $REGISTRY"
      echo "**Environment:** $DEPLOY_ENV"
      echo "**Version:** $VERSION"
      echo "**Tags:** $DEPLOY_ENV-$VERSION and the environment alias tag"
    } >> $GITHUB_STEP_SUMMARY
```

**What This Does:**

Creates a summary displayed on GitHub workflow run page:

```
## Docker Image Pushed

**Image:** john_doe/intelligent_room_booking
**Environment:** prod
**Version:** 3.0.0
**Tags:** prod-3.0.0 and the environment alias tag (production)
```

- **Duration:** ~1-2 seconds
- **Failure Impact:** ℹ️ INFORMATIONAL (non-blocking)
- **Purpose:** Documentation and visibility
- **Location:** Visible on GitHub Actions workflow run summary page

---

## 5. Docker Build Process

### Dockerfile Analysis

The `Dockerfile` in the repository root defines how the application is containerized:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "room_booking_system.wsgi:application", "--bind", "0.0.0.0:8000"]
```

**Key Build Steps:**

1. **Base Image:** `python:3.11-slim` (lightweight Python 3.11)
2. **Working Directory:** `/app` inside container
3. **Dependencies:** Install from `requirements.txt`
4. **Source Code:** Copy all application files
5. **Static Files:** Collect Django static files
6. **Expose:** Port 8000 for HTTP
7. **Entrypoint:** Run Gunicorn WSGI server

**Build Optimization:**

- `--no-cache-dir` → Reduces image size
- `--noinput` → Non-interactive static file collection
- Layers are cached for faster rebuilds
- Only changed layers are rebuilt on subsequent deployments

### Image Size

Typical image size: 300-500 MB
- Base Python image: ~150 MB
- Dependencies: ~100-200 MB
- Application code: ~10-50 MB

---

## 6. Docker Registry Management

### Registry Organization

**Docker Hub Repository:** `john_doe/intelligent_room_booking`

### Image Naming Convention

```
{REGISTRY}:{TAG}
john_doe/intelligent_room_booking:dev-1.0.0
                    │                   │
                    └─ Repository ──────┘
                                 └─ Image tag
```

### Tags Structure

| Tag Pattern | Purpose | Updated When | Usage |
|------------|---------|--------------|-------|
| `dev-*` | Development versioned release | `dev-v` tag pushed | Dev deployments |
| `master` | Latest development release | Every `dev-v` tag | CI/CD systems, default dev |
| `stg-*` | Staging versioned release | `stg-v` tag pushed | Staging deployments |
| `testing` | Latest staging release | Every `stg-v` tag | CI/CD systems, default stg |
| `prod-*` | Production versioned release | `prod-v` tag pushed | Production deployments |
| `production` | Latest production release | Every `prod-v` tag | CI/CD systems, default prod |

### Pulling Images

```bash
# Pull specific version
docker pull john_doe/intelligent_room_booking:prod-1.0.0

# Pull latest production
docker pull john_doe/intelligent_room_booking:production

# Pull latest staging
docker pull john_doe/intelligent_room_booking:testing

# Pull latest development
docker pull john_doe/intelligent_room_booking:master
```

### Multi-Environment Support

```
Single Repository (john_doe/intelligent_room_booking)
│
├─ Development Versions
│  ├─ dev-0.9.0
│  ├─ dev-1.0.0
│  ├─ dev-1.1.0
│  └─ master (points to dev-1.1.0)
│
├─ Staging Versions
│  ├─ stg-0.8.0
│  ├─ stg-1.0.0
│  └─ testing (points to stg-1.0.0)
│
└─ Production Versions
   ├─ prod-0.7.0
   ├─ prod-1.0.0
   └─ production (points to prod-1.0.0)
```

All environments use the same repository but different tags.

---

## 7. Deployment Workflows by Environment

### Development Deployment

**Trigger:**
```bash
git tag dev-v1.0.0
git push origin dev-v1.0.0
```

**What Happens:**

```
CD Pipeline Triggered
    ↓
Extract: ENV=dev, VERSION=1.0.0
    ↓
Build: docker build -t john_doe/intelligent_room_booking:dev-1.0.0 .
    ↓
Tag: docker tag ... intelligent_room_booking:master
    ↓
Push:
  ├─ Push john_doe/intelligent_room_booking:dev-1.0.0
  └─ Push john_doe/intelligent_room_booking:master (updated)
    ↓
Deploy to Dev Environment:
  - Pull image: intelligent_room_booking:master
  - Start container
  - Run migrations
  - Health check
```

**Timeline:**
1. Tag is pushed
2. CD pipeline starts (~10 seconds)
3. Image builds (~60-90 seconds)
4. Image pushed to registry (~20-40 seconds)
5. Dev server can pull and deploy (~2-5 minutes after pipeline completion)

**Rollback:**
```bash
# If new version has issues, deploy previous version
docker pull john_doe/intelligent_room_booking:dev-0.9.0
docker run ... intelligent_room_booking:dev-0.9.0

# Or use `master` tag to specific commit
docker pull john_doe/intelligent_room_booking:master  # Before latest push
```

---

### Staging Deployment

**Trigger:**
```bash
git tag stg-v1.0.0
git push origin stg-v1.0.0
```

**Images Created:**
- `john_doe/intelligent_room_booking:stg-1.0.0` (specific version)
- `john_doe/intelligent_room_booking:testing` (latest alias)

**Usage:**
- Testing team pulls `testing` tag for latest
- QA deploys to staging environment
- Pre-production validation
- Integration testing

---

### Production Deployment

**Trigger:**
```bash
git tag prod-v1.0.0
git push origin prod-v1.0.0
```

**Images Created:**
- `john_doe/intelligent_room_booking:prod-1.0.0` (specific version)
- `john_doe/intelligent_room_booking:production` (latest alias)

**Deployment Process:**
1. CD builds and pushes image
2. Production team reviews release notes
3. Manual pull and deployment by ops
4. Blue-green deployment or rolling update
5. Health checks and monitoring
6. If issues, rollback to previous `prod-*` version

**Production Safety:**
- Never auto-deploy to production
- Require explicit pull and deployment
- Keep version history for quick rollbacks
- Tag always points to most recent, but explicit versions remain unchanged

---

## 8. Pass/Fail Criteria

### CD Pipeline Success Criteria

✅ **ALL of the following must complete:**

1. ✅ Checkout repository
2. ✅ Set up Docker Buildx
3. ✅ Authenticate with Docker Hub
4. ✅ Extract version and environment (valid tag format)
5. ✅ Build Docker image (Dockerfile builds without errors)
6. ✅ Push versioned tag (image pushed successfully)
7. ✅ Push environment alias tag (alias tag updated)
8. ✅ Create deployment summary

**Any single failure = Entire CD fails = Image not pushed**

### Failure Scenarios

| Scenario | Cause | Impact | Resolution |
|----------|-------|--------|-----------|
| Invalid tag format | Tag doesn't match pattern | Pipeline stops at extract | Push correct tag: `dev-v1.0.0` |
| Authentication failed | Wrong secrets | Pipeline stops at login | Verify DOCKER_USERNAME and DOCKER_PASSWORD secrets |
| Build failed | Dockerfile error | Pipeline stops at build | Fix Dockerfile, retry (delete tag, recreate) |
| Push failed | Network error, quota | Pipeline stops at push | Retry manually or recreate tag |
| Insufficient space | Disk full on runner | Build fails | Not common, free resources if happens |

---

## 9. Performance Characteristics

### Typical Execution Timeline

```
0:00 - Trigger: Tag pushed to GitHub
  └─→ GitHub detects tag push pattern

0:10 - Checkout Step
  └─→ Repository cloned (5-10 sec)

0:20 - Docker Buildx Setup
  └─→ Build environment prepared (10-15 sec)

0:25 - Docker Registry Login
  └─→ Authentication completed (3-5 sec)

0:28 - Extract Version and Tag
  └─→ Version extracted: 1.0.0, ENV: prod (2-3 sec)

1:30 - Docker Build
  └─→ Image built from Dockerfile (60-90 sec)
  └─→ Layers cached for efficiency

2:00 - Docker Push
  └─→ Image pushed to Docker Hub (30-60 sec)
  └─→ Versioned tag (prod-1.0.0)
  └─→ Alias tag (production)

2:30 - Deployment Summary
  └─→ Summary created (1-2 sec)

2:33 - Pipeline Complete
  └─→ Total: ~2 minutes 33 seconds
```

**Total Execution Time: 2-3 minutes**

### Performance Factors

| Factor | Impact |
|--------|--------|
| Dockerfile size | Larger files = slower build |
| Dependency changes | New installs = slower build |
| Registry network | Latency affects push time |
| Docker Hub load | Congestion = slower push |
| Image caching | Cached layers = faster rebuilds |

---

## 10. Security Considerations

### Secrets Management

**GitHub Secrets Used:**

```
DOCKER_USERNAME    - Docker Hub username (public-safe)
DOCKER_PASSWORD    - Docker Hub token (sensitive, encrypted)
```

**Security Features:**

✅ Secrets never logged in workflow
✅ Secrets encrypted at rest on GitHub
✅ Secrets only accessible to repo collaborators
✅ Secrets sent only over HTTPS
✅ Credentials temporary, not persisted

**Secret Rotation:**

1. Go to GitHub repo → Settings → Secrets
2. Click "DOCKER_PASSWORD"
3. Generate new token on Docker Hub
4. Update secret with new token
5. Old token automatically revoked

### Image Security

**Best Practices:**

1. **Scan images for vulnerabilities:**
   ```bash
   docker scan john_doe/intelligent_room_booking:prod-1.0.0
   ```

2. **Sign images (optional):**
   - Docker Content Trust
   - Notary signatures
   - Admission controllers

3. **Limit registry access:**
   - Private Docker Hub repository (if applicable)
   - Restrict pull permissions
   - Audit log access

4. **Keep base images updated:**
   - Use latest security patches
   - Monitor base image updates
   - Rebuild when base updates available

---

## 11. Common Failures & Troubleshooting

### Failure: "Invalid tag format"

**Symptom:**
```
Invalid tag format
exit code 1
```

**Cause:**
Tag doesn't match any of: `dev-v*`, `stg-v*`, `prod-v*`

**Examples of invalid tags:**
- `v1.0.0` (missing prefix)
- `release-v1.0.0` (wrong prefix)
- `dev-1.0.0` (missing 'v')
- `DEV-v1.0.0` (uppercase)

**Solution:**
```bash
# Delete invalid tag
git tag -d invalid-tag-name
git push origin --delete invalid-tag-name

# Create correct tag
git tag dev-v1.0.0
git push origin dev-v1.0.0
```

---

### Failure: "Authentication failed"

**Symptom:**
```
error: denied: requested access to the resource is denied
```

**Cause:**
1. DOCKER_USERNAME secret not set
2. DOCKER_PASSWORD secret incorrect
3. Credentials expired or revoked

**Solution:**

1. **Verify secrets exist:**
   - Go to Settings → Secrets
   - Check `DOCKER_USERNAME` exists
   - Check `DOCKER_PASSWORD` exists

2. **Update credentials:**
   - Visit https://hub.docker.com/settings/security
   - Generate new access token
   - Copy token to clipboard
   - Update `DOCKER_PASSWORD` secret

3. **Verify Docker Hub account:**
   - Ensure account is active
   - Check account hasn't been locked
   - Verify email is confirmed

---

### Failure: "Dockerfile errors during build"

**Symptom:**
```
failed to build: docker build failed with exit code 1
Step X/Y : RUN pip install -r requirements.txt
ERROR: ...
```

**Cause:**
1. Requirements installation fails
2. Missing files referenced in COPY
3. Invalid RUN commands
4. Port already in use specification

**Solution:**

1. **Test Dockerfile locally:**
   ```bash
   docker build -t test:latest .
   ```

2. **Check for errors:**
   - Python package incompatibilities
   - Missing dependencies
   - Invalid syntax

3. **Fix and commit:**
   ```bash
   # Fix Dockerfile
   git add Dockerfile
   git commit -m "fix: dockerfile"
   git push
   ```

4. **Retry deployment:**
   ```bash
   # Delete old tag
   git tag -d dev-v1.0.0
   git push origin --delete dev-v1.0.0
   
   # Recreate tag
   git tag dev-v1.0.0
   git push origin dev-v1.0.0
   ```

---

### Failure: "Image push timeout"

**Symptom:**
```
error: failed to push image: context deadline exceeded
```

**Cause:**
1. Network timeout during push
2. Docker Hub service slowness
3. Very large image size
4. Poor connectivity

**Solution:**

1. **Check Docker Hub status:**
   - Visit https://www.dockerstatus.com/

2. **Retry deployment:**
   ```bash
   # Wait a few minutes, then retry
   git tag -d dev-v1.0.0
   git push origin --delete dev-v1.0.0
   git tag dev-v1.0.0
   git push origin dev-v1.0.0
   ```

3. **Optimize image:**
   - Check `.dockerignore` ignores unnecessary files
   - Use multi-stage builds
   - Remove debug dependencies

---

## 12. Deployment Guidelines

### Creating a Development Release

```bash
# On develop branch
git checkout develop
git pull origin develop

# Create tag
git tag dev-v1.0.0

# Push tag (triggers CD)
git push origin dev-v1.0.0

# Monitor in GitHub Actions
# Go to Actions tab → CD workflow → Watch progress
```

---

### Creating a Staging Release

```bash
# On staging branch (or release branch)
git checkout staging
git pull origin staging

# Merge from develop (optional)
git merge develop

# Create tag
git tag stg-v1.0.0

# Push
git push origin stg-v1.0.0

# Staging team pulls image
docker pull john_doe/intelligent_room_booking:testing
```

---

### Creating a Production Release

```bash
# On master branch
git checkout master
git pull origin master

# Merge from staging or develop (after approval)
git merge staging

# Create annotated tag (recommended for production)
git tag -a prod-v1.0.0 -m "Production Release 1.0.0: Initial release"

# Push
git push origin prod-v1.0.0

# Monitor deployment
# Ops team pulls and deploys manually
docker pull john_doe/intelligent_room_booking:prod-v1.0.0
docker run ...
```

---

## 13. Rollback Procedures

### Development Rollback

```bash
# Identify previous version
docker images | grep intelligent_room_booking:dev-

# Deploy previous version
docker pull john_doe/intelligent_room_booking:dev-0.9.0
docker run ... intelligent_room_booking:dev-0.9.0

# Or use latest dev (before new version pushed)
docker pull john_doe/intelligent_room_booking:master
```

---

### Production Rollback

```bash
# Identify previous production version
docker pull john_doe/intelligent_room_booking:prod-0.9.0

# Stop current version
docker stop <current-container>

# Deploy previous version
docker run ... john_doe/intelligent_room_booking:prod-0.9.0

# Verify health checks pass
# Confirm services operational
# Investigate root cause
```

---

## 14. Integration with Deployment Systems

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: room-booking
spec:
  replicas: 3
  selector:
    matchLabels:
      app: room-booking
  template:
    metadata:
      labels:
        app: room-booking
    spec:
      containers:
      - name: app
        image: john_doe/intelligent_room_booking:production  # Auto-updated
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
```

With tag `production` always pointing to latest prod image, Kubernetes can be configured to auto-pull latest.

---

### Docker Compose Deployment

```yaml
version: '3.8'

services:
  web:
    image: john_doe/intelligent_room_booking:production
    ports:
      - "8000:8000"
    environment:
      DJANGO_SETTINGS_MODULE: room_booking_system.settings_production
    depends_on:
      - db
  
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: room_booking_prod
```

---

### Manual Deployment

```bash
#!/bin/bash
# deploy.sh - Manual deployment script

ENVIRONMENT=$1  # dev, stg, or prod
VERSION=$2      # 1.0.0

if [ "$ENVIRONMENT" = "prod" ]; then
  IMAGE="john_doe/intelligent_room_booking:prod-$VERSION"
elif [ "$ENVIRONMENT" = "stg" ]; then
  IMAGE="john_doe/intelligent_room_booking:stg-$VERSION"
else
  IMAGE="john_doe/intelligent_room_booking:dev-$VERSION"
fi

echo "Deploying: $IMAGE"

docker pull $IMAGE
docker stop room_booking_app || true
docker run -d --name room_booking_app \
  -p 8000:8000 \
  $IMAGE

echo "Deployed successfully"
```

---

## 15. Monitoring & Auditing

### GitHub Actions Logs

**View deployment logs:**

1. Go to GitHub repo → Actions tab
2. Click "CD" workflow
3. Click the latest run
4. Expand each step to see details
5. Download logs if needed

**Key Information:**
- Extracted version and environment
- Docker build output
- Push status and layer info
- Deployment summary

### Docker Hub Registry

**Monitor images:**

1. Go to https://hub.docker.com/
2. Login with credentials
3. Navigate to `intelligent_room_booking` repository
4. View all tags
5. See push dates and image details

---

## 16. Versioning Strategy

### Semantic Versioning

Format: `MAJOR.MINOR.PATCH[-PRERELEASE]`

```
1.0.0           - Production release (major version 1)
1.2.5           - Patch release (bug fixes)
2.0.0           - Major release (breaking changes)
1.0.0-rc1       - Release candidate
1.0.0-beta.1    - Beta release
```

### Version Examples

```
dev-v0.1.0      - Development prototype
dev-v1.0.0      - Development stable

stg-v1.0.0      - Staging release (ready for QA)
stg-v1.0.1      - Staging patch (bug fix)

prod-v1.0.0     - Production release
prod-v1.0.1     - Production hot fix
prod-v1.1.0     - Production minor update
prod-v2.0.0     - Production major release
```

### Version Increment Rules

| Scenario | Version Change | Example |
|----------|----------------|---------|
| New feature | Bump MINOR | 1.0.0 → 1.1.0 |
| Bug fix | Bump PATCH | 1.0.0 → 1.0.1 |
| Breaking change | Bump MAJOR | 1.0.0 → 2.0.0 |
| Security fix | Bump PATCH | 1.0.0 → 1.0.1 |

---

## 17. Best Practices

### ✅ DO

- ✅ Create tags from verified commits (after CI passes)
- ✅ Use semantic versioning consistently
- ✅ Create release notes when tagging
- ✅ Delete old/unused tags to reduce clutter
- ✅ Test image locally before pushing
- ✅ Use specific versions for production deployments
- ✅ Keep `production` tag for latest prod (for monitoring)
- ✅ Document release procedures
- ✅ Monitor Docker Hub for image security issues
- ✅ Rotate credentials periodically

### ❌ DON'T

- ❌ Push tags to broken commits
- ❌ Manually push images without CI/CD
- ❌ Use `latest` tag (ambiguous)
- ❌ Store secrets in Dockerfile
- ❌ Use hardcoded sensitive data
- ❌ Forget to test before production deployment
- ❌ Overwrite old version tags
- ❌ Deploy directly to production without testing
- ❌ Keep expired Docker credentials
- ❌ Skip backup before major deployments

---

## 18. Optimization Tips

### Faster Builds

1. **Leverage layer caching:**
   ```dockerfile
   # Good: Frequently-changed files last
   FROM python:3.11-slim
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY . .  # Application code (changes often)
   ```

2. **Use .dockerignore:**
   ```
   __pycache__
   *.pyc
   .git
   .venv
   node_modules
   *.log
   ```

3. **Multi-stage builds:**
   ```dockerfile
   FROM python:3.11 as builder
   ...build...
   
   FROM python:3.11-slim
   COPY --from=builder /app /app
   ```

---

### Smaller Images

1. **Use slim base images:** `python:3.11-slim` vs `python:3.11`
2. **Reduce dependencies:** Only include required packages
3. **Clean up:** Run `pip cache purge`, remove build artifacts
4. **Compress:** Use COMPRESS_STATIC_FILES in Django

---

## 19. Disaster Recovery

### If Docker Hub Account Compromised

1. Change password immediately
2. Rotate all access tokens
3. Update GitHub secrets with new token
4. Review push history for unauthorized images
5. Delete malicious images
6. Audit all recent deployments

---

### If Wrong Image Pushed

```bash
# Identify the issue
docker pull john_doe/intelligent_room_booking:prod-1.0.0
docker run ... intelligent_room_booking:prod-1.0.0

# Stop the bad container
docker stop <container-id>

# Deploy known-good previous version
docker pull john_doe/intelligent_room_booking:prod-0.9.0
docker run ... intelligent_room_booking:prod-0.9.0

# Investigate and fix the issue
# Fix code/Dockerfile
# Commit fixes
# Delete bad tag
git tag -d prod-v1.0.0
git push origin --delete prod-v1.0.0

# Re-tag with new version
git tag prod-v1.0.1
git push origin prod-v1.0.1
```

---

## 20. Reference Commands

### Tag Management

```bash
# Create tag
git tag dev-v1.0.0

# Push tag
git push origin dev-v1.0.0

# List local tags
git tag -l

# List remote tags
git ls-remote --tags origin

# Delete local tag
git tag -d dev-v1.0.0

# Delete remote tag
git push origin --delete dev-v1.0.0

# Push all tags
git push origin --tags
```

---

### Docker Image Management

```bash
# View available images
docker images | grep intelligent_room_booking

# Inspect image
docker inspect john_doe/intelligent_room_booking:prod-1.0.0

# View image history
docker history john_doe/intelligent_room_booking:prod-1.0.0

# Remove image
docker rmi john_doe/intelligent_room_booking:prod-1.0.0

# Tag image
docker tag source:tag destination:newtag

# Push image
docker push john_doe/intelligent_room_booking:tag
```

---

## 21. Conclusion

The CD pipeline provides:

✅ **Automated Release Process** - From tag to registry in ~2-3 minutes
✅ **Multi-Environment Support** - Dev, Staging, Production with semantic versioning
✅ **Safe Deployments** - Only version-tagged commits are released
✅ **Clear Versioning** - Semantic versioning ensures clarity
✅ **Artifact Preservation** - All versions maintained for rollback capability
✅ **Simple to Operate** - One command (`git tag && git push`) triggers everything

**Key Strengths:**
- No manual image building
- Consistent tagging strategy
- Environment-specific deployment options
- Quick rollback capability
- Clear version history

**Operational Flow:**
```
Code Fixed & Tested (via CI)
    ↓
Create semantic version tag
    ↓
Push tag to GitHub
    ↓
CD pipeline automatically builds & pushes image
    ↓
Image available in Docker Hub with consistent tags
    ↓
Deploy to desired environment
```

---

**Document Version:** 1.0
**Last Updated:** May 1, 2026
**Maintained By:** DevOps Team
