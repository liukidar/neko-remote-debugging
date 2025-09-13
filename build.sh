#!/bin/bash
set -e

# Configuration
IMAGE_NAME="steel-browser-neko"
REGISTRY="your-registry.com"  # Change this to your registry
VERSION=$(date +%Y%m%d-%H%M%S)
LATEST_TAG="latest"

echo "🚀 Building optimized Steel Browser Neko image..."

# Build the optimized image
docker build -f Dockerfile.optimized -t ${IMAGE_NAME}:${VERSION} -t ${IMAGE_NAME}:${LATEST_TAG} .

echo "✅ Build complete: ${IMAGE_NAME}:${VERSION}"

# Optional: Push to registry for even faster deployment
read -p "Push to registry for faster deployment? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ "$REGISTRY" = "your-registry.com" ]; then
        echo "⚠️  Please update REGISTRY variable in build.sh"
        exit 1
    fi
    
    echo "📤 Pushing to registry..."
    docker tag ${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:${VERSION}
    docker tag ${IMAGE_NAME}:${LATEST_TAG} ${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}
    
    docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
    docker push ${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}
    
    echo "✅ Pushed to registry"
    echo "📝 Update docker-compose.yml to use: ${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}"
fi

echo "🎯 Image ready for fast deployment!"
echo "   Local: ${IMAGE_NAME}:${LATEST_TAG}"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   Registry: ${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}"
fi
