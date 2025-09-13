#!/bin/bash
# Startup time measurement and optimization script

echo "🚀 Starting optimized Steel Browser..."
start_time=$(date +%s%N)

# Function to measure time
measure_time() {
    current_time=$(date +%s%N)
    elapsed=$((($current_time - $start_time) / 1000000))
    echo "⏱️  $1: ${elapsed}ms"
    start_time=$current_time
}

echo "📦 Starting container..."
docker compose up -d

measure_time "Container startup"

echo "🔍 Waiting for services to be ready..."

# Wait for debug proxy to be ready
until nc -z localhost 9223 2>/dev/null; do
    sleep 0.1
done
measure_time "Debug proxy ready"

# Wait for Neko web interface
until curl -s http://localhost:8080 >/dev/null 2>&1; do
    sleep 0.1
done
measure_time "Neko web interface ready"

# Wait for Chrome DevTools to respond
until curl -s http://localhost:9223/json >/dev/null 2>&1; do
    sleep 0.1
done
measure_time "Chrome DevTools ready"

total_time=$(date +%s%N)
total_elapsed=$((($total_time - $start_time) / 1000000))

echo "✅ All services ready!"
echo "🎯 Total startup time: ${total_elapsed}ms"

# Optional: Test connection
echo "🌐 Testing connection..."
response=$(curl -s http://localhost:9223/json | jq -r '.[0].webSocketDebuggerUrl' 2>/dev/null)
if [ ! -z "$response" ]; then
    echo "✅ DevTools connection available"
else
    echo "⚠️  DevTools connection test failed"
fi
