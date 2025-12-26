#!/bin/bash
# Native llama.cpp build script (no Nix)
# Uses system libraries for proper GPU support

set -e

# Add CUDA to PATH if it exists
if [ -d "/opt/cuda/bin" ]; then
    export PATH="/opt/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/opt/cuda/lib64:$LD_LIBRARY_PATH"
fi

LLAMA_SRC="/tmp/llama.cpp"
LLAMA_BIN="$LLAMA_SRC/build/bin/llama-server"
INSTALL_DIR="$HOME/.local/bin"

echo "=== Building llama.cpp natively (system libraries) ==="
echo ""

# Check for required tools
echo "Checking dependencies..."
for cmd in git cmake make gcc g++ nvcc; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Missing: $cmd"
        echo "Install with: sudo pacman -S base-devel cmake git cuda vulkan-headers vulkan-tools"
        exit 1
    fi
done

# Check for CUDA-compatible GCC
GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)
echo "Detected GCC version: $GCC_VERSION"

if [ "$GCC_VERSION" -ge 14 ]; then
    echo "⚠ GCC $GCC_VERSION is too new for CUDA 12.9 (max GCC 13)"
    echo "Checking for compatible GCC..."

    # Try to find gcc-13 or gcc-12
    CUDA_GCC=""
    for ver in 13 12; do
        if command -v gcc-$ver &> /dev/null; then
            CUDA_GCC="gcc-$ver"
            CUDA_GXX="g++-$ver"
            echo "✓ Found compatible: $CUDA_GCC"
            export CC=$CUDA_GCC
            export CXX=$CUDA_GXX
            export CUDAHOSTCXX=$CUDA_GXX
            break
        fi
    done

    if [ -z "$CUDA_GCC" ]; then
        echo "❌ No compatible GCC found for CUDA"
        echo "Install with: sudo pacman -S gcc13"
        echo "Or from AUR: yay -S gcc13"
        exit 1
    fi
fi

echo "✓ All dependencies found"
echo ""

# Clone or update llama.cpp
if [ ! -d "$LLAMA_SRC" ]; then
    echo "Cloning llama.cpp..."
    git clone https://github.com/ggerganov/llama.cpp "$LLAMA_SRC"
else
    echo "llama.cpp already cloned"
fi

cd "$LLAMA_SRC"

# Clean previous build
echo "Cleaning previous build..."
rm -rf build
mkdir -p build
cd build

# Configure with CMake
echo ""
echo "Configuring with CMake..."
echo "  CUDA: ON (Nvidia GPU acceleration)"
echo "  Vulkan: ON (Intel GPU + dual GPU support)"
echo ""

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DLLAMA_CURL=ON

# Build
echo ""
echo "Building llama-server (this will take a few minutes)..."
make -j$(nproc) llama-server

# Test GPU detection
echo ""
echo "Testing GPU detection..."
if [ -f "$LLAMA_BIN" ]; then
    echo "✓ llama-server built successfully"
    echo ""
    echo "Detected compute devices:"
    $LLAMA_BIN --list-devices || echo "Warning: Could not list devices"
else
    echo "❌ Build failed - binary not found"
    exit 1
fi

echo ""
echo "✓ Build complete!"
echo "Binary location: $LLAMA_BIN"
echo ""
echo "Next step: make install"
