#!/bin/bash
# Interactive performance benchmark for llama.cpp models

set -e -o pipefail

# Function to handle errors
error_handler() {
    echo ""
    echo "❌ Error occurred at line $1"
    echo "Checking server status..."
    if [ -f /tmp/llama-server.pid ]; then
        PID=$(cat /tmp/llama-server.pid)
        if ps -p $PID > /dev/null 2>&1; then
            echo "Server is still running (PID: $PID)"
            echo "Last 20 lines of server log:"
            tail -20 /tmp/llama-server.log
        else
            echo "Server crashed! Last 30 lines of log:"
            tail -30 /tmp/llama-server.log
        fi
    else
        echo "No PID file found"
    fi
    exit 1
}

trap 'error_handler $LINENO' ERR

RESULTS_FILE="/tmp/benchmark_results.json"
CPP_FILE="/home/sree/Matrix/localcode/test_benchmark.cpp"

# Initialize results file if it doesn't exist
if [ ! -f "$RESULTS_FILE" ]; then
    echo '{"models": []}' > "$RESULTS_FILE"
fi

echo "=== llama.cpp Model Performance Benchmark ==="
echo "Test file: $CPP_FILE"
echo "Results: $RESULTS_FILE"
echo ""

# Model options
echo "Available models:"
echo "1) Nemotron Mini 4B (Single GPU - CUDA)"
echo "2) Qwen2.5 Coder 7B (Single GPU - CUDA)"
echo "3) Nemotron Nano 30B MoE (Dual GPU - Vulkan) ⚠️"
echo "4) Qwen2.5 Coder 32B (Dual GPU - Vulkan) ⚠️"
echo "5) DeepSeek Coder V2 Lite 16B (Dual GPU - Vulkan) ⚠️"
echo ""
echo "⚠️  = Known Vulkan stability issues - see VULKAN_ISSUES.md"
echo ""
read -p "Select model to benchmark (1-5): " choice

case $choice in
    1)
        MODEL_NAME="Nemotron Mini 4B"
        MAKE_TARGET="use-nemotron"
        GPU_MODE="Single GPU (CUDA - Nvidia RTX 4070)"
        EXPECTED_SPEED="90"
        ;;
    2)
        MODEL_NAME="Qwen2.5 Coder 7B"
        MAKE_TARGET="use-qwen"
        GPU_MODE="Single GPU (CUDA - Nvidia RTX 4070)"
        EXPECTED_SPEED="80"
        ;;
    3)
        MODEL_NAME="Nemotron Nano 30B MoE"
        MAKE_TARGET="use-nemotron-nano"
        GPU_MODE="Dual GPU (Vulkan0+Vulkan1: Intel+Nvidia)"
        EXPECTED_SPEED="35"
        ;;
    4)
        MODEL_NAME="Qwen2.5 Coder 32B"
        MAKE_TARGET="use-qwen32b"
        GPU_MODE="Dual GPU (Vulkan0+Vulkan1: Intel+Nvidia)"
        EXPECTED_SPEED="25"
        ;;
    5)
        MODEL_NAME="DeepSeek Coder V2 Lite 16B"
        MAKE_TARGET="use-deepseek"
        GPU_MODE="Dual GPU (Vulkan0+Vulkan1: Intel+Nvidia)"
        EXPECTED_SPEED="30"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: $MODEL_NAME ($GPU_MODE)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Stop current server (force stop all llama-server processes)
echo "Stopping current server..."

# Kill by PID file if exists
if [ -f /tmp/llama-server.pid ]; then
    PID=$(cat /tmp/llama-server.pid)
    echo "Found PID file: $PID"
    if ps -p $PID > /dev/null 2>&1; then
        echo "Killing PID: $PID"
        kill $PID 2>/dev/null || true
        sleep 2
        # Force kill if still running
        if ps -p $PID > /dev/null 2>&1; then
            echo "Force killing PID: $PID"
            kill -9 $PID 2>/dev/null || true
            sleep 1
        fi
    fi
fi

# Kill any remaining llama-server processes
echo "Checking for any remaining llama-server processes..."
pkill -f "llama-server.*11336" 2>/dev/null || true
sleep 1

# Force kill any stragglers
pkill -9 -f "llama-server.*11336" 2>/dev/null || true
sleep 1

# Remove PID file
rm -f /tmp/llama-server.pid

# Verify no process is running
if pgrep -f "llama-server.*11336" > /dev/null 2>&1; then
    echo "❌ Error: llama-server still running after kill attempt"
    pgrep -f "llama-server.*11336"
    exit 1
fi

echo "✓ All llama-server processes stopped"
sleep 1

# Switch model (this also starts the server)
echo "Switching to $MODEL_NAME..."
make "$MAKE_TARGET"
echo ""

# Wait for server to be ready and model to be fully loaded
echo "Waiting for server to be ready and model to load..."
WAIT_COUNT=0
MAX_WAIT=120  # Wait up to 2 minutes for large models

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    HEALTH_RESPONSE=$(curl -s http://localhost:11336/health 2>/dev/null)

    if [ $? -eq 0 ]; then
        # Check if response contains "ok" (model loaded) or error (still loading)
        if echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
            echo "✓ Server is ready and model loaded"
            break
        elif echo "$HEALTH_RESPONSE" | grep -q '"error"'; then
            # Model still loading
            echo -n "."
        fi
    fi

    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))

    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo ""
        echo "❌ Model failed to load within $MAX_WAIT seconds"
        echo "Last response: $HEALTH_RESPONSE"
        echo "Server logs:"
        tail -20 /tmp/llama-server.log
        exit 1
    fi
done
echo ""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Running Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Read C++ file content
CPP_CONTENT=$(cat "$CPP_FILE")

# Warmup run (don't count this)
echo ""
echo "Warmup: Running initial request to warm up caches..."
curl -s http://localhost:11336/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "messages": [{"role": "user", "content": "Hello"}],
        "max_tokens": 10,
        "temperature": 0.3
    }' > /dev/null 2>&1

echo "✓ Warmup complete"
sleep 2

# Test 1: Generate summary
echo ""
echo "Test 1: Generate code summary..."

PROMPT="Analyze this C++ code and provide a brief 2-3 sentence summary of what it does:\n\n\`\`\`cpp\n$CPP_CONTENT\n\`\`\`"

START_TIME=$(date +%s.%N)
echo "Sending request to API..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:11336/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{
        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$PROMPT" | jq -Rs .)}],
        \"max_tokens\": 200,
        \"temperature\": 0.3
    }" 2>&1)
END_TIME=$(date +%s.%N)

# Check HTTP response code
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ API request failed with HTTP $HTTP_CODE"
    echo "Response: $RESPONSE"
    echo "Checking server logs..."
    tail -20 /tmp/llama-server.log
    exit 1
fi

SUMMARY_TIME=$(echo "$END_TIME - $START_TIME" | bc)
SUMMARY_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // 0')
SUMMARY_PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens // 0')
SUMMARY_TPS=$(echo "scale=2; $SUMMARY_TOKENS / $SUMMARY_TIME" | bc)
# Handle both regular and reasoning models
SUMMARY_TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // "Error"')

echo "Summary: $SUMMARY_TEXT"
echo "Prompt tokens: $SUMMARY_PROMPT_TOKENS | Completion tokens: $SUMMARY_TOKENS"
echo "Time: ${SUMMARY_TIME}s | Speed: ${SUMMARY_TPS} tok/s"

# Test 2: Suggest an edit
echo ""
echo "Test 2: Suggest code improvement..."

EDIT_PROMPT="Look at this C++ code. Suggest ONE specific improvement to the handleRequest method to add error handling. Provide only the improved method code:\n\n\`\`\`cpp\n$CPP_CONTENT\n\`\`\`"

START_TIME=$(date +%s.%N)
echo "Sending edit request to API..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:11336/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{
        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$EDIT_PROMPT" | jq -Rs .)}],
        \"max_tokens\": 300,
        \"temperature\": 0.2
    }" 2>&1)
END_TIME=$(date +%s.%N)

# Check HTTP response code
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ API request failed with HTTP $HTTP_CODE"
    echo "Response: $RESPONSE"
    echo "Checking server logs..."
    tail -20 /tmp/llama-server.log
    exit 1
fi

EDIT_TIME=$(echo "$END_TIME - $START_TIME" | bc)
EDIT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // 0')
EDIT_PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens // 0')
EDIT_TPS=$(echo "scale=2; $EDIT_TOKENS / $EDIT_TIME" | bc)
# Handle both regular and reasoning models
EDIT_TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // "Error"' | head -c 150)

echo "Edit suggestion preview: ${EDIT_TEXT}..."
echo "Prompt tokens: $EDIT_PROMPT_TOKENS | Completion tokens: $EDIT_TOKENS"
echo "Time: ${EDIT_TIME}s | Speed: ${EDIT_TPS} tok/s"

# Get GPU memory usage
GPU_MEM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)

# Calculate average speed
AVG_TPS=$(echo "scale=2; ($SUMMARY_TPS + $EDIT_TPS) / 2" | bc)
TOTAL_TIME=$(echo "scale=2; $SUMMARY_TIME + $EDIT_TIME" | bc)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Model: $MODEL_NAME"
echo "Mode: $GPU_MODE"
echo "Average Speed: ${AVG_TPS} tok/s (expected: ~${EXPECTED_SPEED} tok/s)"
echo "Total Time: ${TOTAL_TIME}s"
echo "GPU Memory: ${GPU_MEM} MB"
echo ""

# Create result object
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULT=$(jq -n \
    --arg name "$MODEL_NAME" \
    --arg mode "$GPU_MODE" \
    --arg timestamp "$TIMESTAMP" \
    --arg summary_time "$SUMMARY_TIME" \
    --arg summary_prompt_tokens "$SUMMARY_PROMPT_TOKENS" \
    --arg summary_tokens "$SUMMARY_TOKENS" \
    --arg summary_tps "$SUMMARY_TPS" \
    --arg edit_time "$EDIT_TIME" \
    --arg edit_prompt_tokens "$EDIT_PROMPT_TOKENS" \
    --arg edit_tokens "$EDIT_TOKENS" \
    --arg edit_tps "$EDIT_TPS" \
    --arg avg_tps "$AVG_TPS" \
    --arg total_time "$TOTAL_TIME" \
    --arg gpu_mem "$GPU_MEM" \
    '{
        name: $name,
        mode: $mode,
        timestamp: $timestamp,
        summary: {
            time: $summary_time,
            prompt_tokens: $summary_prompt_tokens,
            completion_tokens: $summary_tokens,
            tps: $summary_tps
        },
        edit: {
            time: $edit_time,
            prompt_tokens: $edit_prompt_tokens,
            completion_tokens: $edit_tokens,
            tps: $edit_tps
        },
        average_tps: $avg_tps,
        total_time: $total_time,
        gpu_memory_mb: $gpu_mem
    }')

# Update or add result to JSON file
# Check if model already exists and remove it
TEMP_FILE="${RESULTS_FILE}.tmp"
jq --arg name "$MODEL_NAME" '.models |= map(select(.name != $name))' "$RESULTS_FILE" > "$TEMP_FILE"
jq --argjson result "$RESULT" '.models += [$result]' "$TEMP_FILE" > "$RESULTS_FILE"
rm "$TEMP_FILE"

echo "✓ Results saved to $RESULTS_FILE"
echo ""
echo "To view all results:"
echo "  jq '.models' $RESULTS_FILE"
echo ""
echo "To compare models:"
echo "  jq -r '.models[] | \"\\(.name): \\(.average_tps) tok/s\"' $RESULTS_FILE"
