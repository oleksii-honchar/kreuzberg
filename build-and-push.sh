#!/usr/bin/env bash
# build-and-push.sh — Build and push olho-kreuzberg Docker images
#
# Builds the olho-kreuzberg fork (with base_url + VLM_OCR_API_KEY patches)
# and pushes to Docker Hub under the oleksii-honchar namespace.
#
# Usage:
#   ./build-and-push.sh                            # Build + push patches (default)
#   ./build-and-push.sh --variant core             # Build + push core only
#   ./build-and-push.sh --variant full             # Build + push full only
#   ./build-and-push.sh --variant cli              # Build + push CLI only
#   ./build-and-push.sh --variant patches          # Build + push our custom Dockerfile.kreuzberg
#   ./build-and-push.sh --build-only               # Build only, skip push
#   ./build-and-push.sh --push-only                # Push only (assumes images are built)
#   ./build-and-push.sh --tag v4.3.6               # Tag with specific version
#   ./build-and-push.sh --platform linux/arm64     # Single platform (default: all)
#   ./build-and-push.sh --dry-run                  # Dry run (show commands, don't execute)
#   ./build-and-push.sh --no-cache                 # Skip build cache
#
# Prerequisites:
#   - Docker Desktop with buildx (multi-arch)
#   - Logged in to Docker Hub:  docker login
#   - Current branch: patched/main (or any branch with the patches)
#
# Image registry: docker.io/oleksii-honchar/olho-kreuzberg
# Variants:
#   - patches  : Our custom Dockerfile.kreuzberg (with patches, all features)
#   - core     : Upstream docker/Dockerfile.core
#   - full     : Upstream docker/Dockerfile.full
#   - cli      : Upstream docker/Dockerfile.cli

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
REGISTRY="docker.io"
NAMESPACE="tuiteraz"
REPO="kreuzberg"
IMAGE_BASE="${REGISTRY}/${NAMESPACE}/${REPO}"

FORK_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Defaults ───────────────────────────────────────────────────────────────────
BUILD_ONLY=false
PUSH_ONLY=false
DRY_RUN=false
NO_CACHE=false
TAG="latest"
PLATFORM="linux/amd64,linux/arm64"

# Variants to build (space-separated)
VARIANTS=""

# ── Variant → Dockerfile lookup ────────────────────────────────────────────────
get_dockerfile() {
  case "$1" in
    patches) echo "Dockerfile.kreuzberg" ;;
    core)    echo "docker/Dockerfile.core" ;;
    full)    echo "docker/Dockerfile.full" ;;
    cli)     echo "docker/Dockerfile.cli" ;;
    *)       echo "" ;;
  esac
}

# ── Parse flags ────────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --variant)
      VARIANTS="$VARIANTS $2"
      shift 2
      ;;
    --build-only) BUILD_ONLY=true ;;
    --push-only)  PUSH_ONLY=true ;;
    --dry-run)    DRY_RUN=true ;;
    --no-cache)   NO_CACHE=true ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --variant VARIANT    Variant to build: patches, core, full, cli (default: patches)"
      echo "  --build-only         Build only, skip push"
      echo "  --push-only          Push only (assumes images are built locally)"
      echo "  --dry-run            Show commands without executing"
      echo "  --no-cache           Skip build cache"
      echo "  --tag TAG            Tag to use (default: latest)"
      echo "  --platform PLATFORM  Docker platform(s), comma-separated (default: linux/amd64,linux/arm64)"
      echo ""
      echo "Examples:"
      echo "  $0                                              # Build + push patches (default)"
      echo "  $0 --variant patches --tag v4.3.6               # Tag with version"
      echo "  $0 --variant patches --build-only               # Build only"
      echo "  $0 --variant patches --platform linux/arm64     # ARM64 only"
      echo "  $0 --variant patches --dry-run                  # Dry run"
      echo "  $0 --variant core --variant full                # Build core + full"
      echo ""
      echo "Note: Requires docker login to ${REGISTRY}/${NAMESPACE}"
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Default to patches variant if none specified
VARIANTS=$(echo "$VARIANTS" | xargs)
if [ -z "$VARIANTS" ]; then
  VARIANTS="patches"
fi

# ── Pre-flight checks ─────────────────────────────────────────────────────────
echo "=== olho-kreuzberg build-and-push ==="
echo ""

# Check Docker
docker ps >/dev/null 2>&1 || { echo "ERROR: Docker is not running"; exit 1; }

# Check buildx
if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx not available. Install: docker buildx create --use"
  exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git -C "$FORK_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "Current branch:    $CURRENT_BRANCH"
echo "Image base:        ${IMAGE_BASE}"
echo "Tag:               ${TAG}"
echo "Platform:          ${PLATFORM}"
echo "Variants:          ${VARIANTS}"
echo ""

# ── Helper functions ───────────────────────────────────────────────────────────
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would execute: $*"
    return 0
  fi
  "$@"
}

build_image() {
  local variant="$1"
  local dockerfile
  dockerfile=$(get_dockerfile "$variant")

  if [ -z "$dockerfile" ]; then
    echo "ERROR: Unknown variant: $variant (available: patches, core, full, cli)"
    exit 1
  fi

  local image_tag="${IMAGE_BASE}:${variant}-${TAG}"
  local local_tag="olho-kreuzberg:${variant}-${TAG}"

  if [ ! -f "$FORK_DIR/$dockerfile" ]; then
    echo "ERROR: Dockerfile not found: $FORK_DIR/$dockerfile"
    exit 1
  fi

  echo "=== Building: ${variant} (${dockerfile}) ==="
  echo "  Image: ${image_tag}"
  echo "  Local: ${local_tag}"
  echo ""

  local cache_opts
  if [ "$NO_CACHE" = true ]; then
    cache_opts="--no-cache"
  else
    cache_opts=""
  fi

  run_cmd docker buildx build \
    --platform "${PLATFORM}" \
    --build-arg ONNXRUNTIME_VERSION=1.24.2 \
    --tag "${local_tag}" \
    --tag "${image_tag}" \
    --file "$FORK_DIR/$dockerfile" \
    --progress=plain \
    $cache_opts \
    "$FORK_DIR" \
    2>&1

  echo ""
  echo "  ✓ Build complete: ${image_tag}"
  echo ""
}

push_image() {
  local variant="$1"
  local image_tag="${IMAGE_BASE}:${variant}-${TAG}"

  echo "=== Pushing: ${image_tag} ==="

  run_cmd docker push "${image_tag}"

  echo "  ✓ Pushed: ${image_tag}"
  echo ""
}

# ── Build phase ────────────────────────────────────────────────────────────────
if [ "$PUSH_ONLY" = false ]; then
  for variant in $VARIANTS; do
    build_image "$variant"
  done
fi

# ── Push phase ─────────────────────────────────────────────────────────────────
if [ "$BUILD_ONLY" = false ]; then
  echo "=== Push phase ==="
  echo ""

  for variant in $VARIANTS; do
    push_image "$variant"
  done

  # ── Summary ────────────────────────────────────────────────────────────────
  echo ""
  echo "=== Summary ==="
  for variant in $VARIANTS; do
    echo "  ${IMAGE_BASE}:${variant}-${TAG}"
  done
  echo ""
  echo "Run with:"
  for variant in $VARIANTS; do
    echo "  docker run -p 8000:8000 ${IMAGE_BASE}:${variant}-${TAG}"
  done
  echo ""
fi

echo "Done ✓"
