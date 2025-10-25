#!/bin/bash

# ecCodes Installer for Herbie on Raspberry Pi
set -e

echo "Installing ecCodes library for Herbie..."

# Phase 1: Install system dependencies
echo "=== PHASE 1: Installing system dependencies ==="
sudo apt update
sudo apt install -y --no-install-recommends \
    cmake build-essential gfortran \
    libaec-dev zlib1g-dev libssl-dev \
    libpng-dev libjpeg-dev \
    python3-dev python3-pip

# Phase 2: Install ecCodes from package manager (preferred)
echo "=== PHASE 2: Installing ecCodes from packages ==="
if sudo apt install -y libeccodes-dev eccodes-tools; then
    echo "ecCodes installed via package manager"
else
    echo "Package installation failed, compiling from source..."
    
    # Phase 3: Compile ecCodes from source
    echo "=== PHASE 3: Compiling ecCodes from source ==="
    ECCODES_DIR="$HOME/eccodes_build"
    mkdir -p "$ECCODES_DIR"
    cd "$ECCODES_DIR"
    
    # Download ecCodes source
    wget https://confluence.ecmwf.int/download/attachments/45757960/eccodes-2.30.2-Source.tar.gz
    tar -xzf eccodes-2.30.2-Source.tar.gz
    cd eccodes-2.30.2-Source
    
    # Create build directory
    mkdir build
    cd build
    
    # Configure and compile
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_BUILD_TYPE=Release \
          -DENABLE_FORTRAN=OFF \
          -DENABLE_NETCDF=OFF \
          -DENABLE_PYTHON=OFF \
          -DENABLE_JPG=ON \
          -DENABLE_PNG=ON \
          -DENABLE_AEC=ON \
          ..
    
    make -j$(nproc)
    sudo make install
    
    # Update library cache
    sudo ldconfig
fi

# Phase 4: Verify ecCodes installation
echo "=== PHASE 4: Verifying ecCodes installation ==="

# Test system installation
if command -v codes_info >/dev/null 2>&1; then
    echo "✓ ecCodes tools installed: $(command -v codes_info)"
    codes_info || true
else
    echo "ecCodes tools not found in PATH"
fi

# Test library presence
if ldconfig -p | grep -q libeccodes; then
    echo "libeccodes library found in system"
else
    echo "libeccodes library not found by ldconfig"
fi

# Phase 5: Reinstall Python bindings in Herbie environment
echo "=== PHASE 5: Reinstalling Python ecCodes bindings ==="
source ~/.herbie_env/bin/activate

# Force reinstall the Python eccodes package
pip uninstall -y eccodes gribapi python-eccodes 2>/dev/null || true
pip install --no-cache-dir eccodes
# OR try the alternative package
# pip install --no-cache-dir python-eccodes

# Phase 6: Test the installation
echo "=== PHASE 6: Testing Herbie installation ==="
python -c "import eccodes; print('ecCodes Python bindings work!')" || {
    echo "ecCodes Python import failed, trying cfgrib fallback..."
}

# Test Herbie
herbie --help && echo "✓ Herbie installed successfully!" || {
    echo "Herbie still has issues"
    echo "Trying alternative installation method..."
    
    # Install Herbie without ecCodes dependency
    pip uninstall -y herbie-data 2>/dev/null || true
    pip install herbie-data --no-deps
    pip install cfgrib xarray pandas numpy
}

echo ""
echo "=== ecCodes Installation Complete ==="
echo "If Herbie still doesn't work, try these diagnostics:"
echo "1. Test ecCodes: codes_info"
echo "2. Test Python: python -c 'import eccodes'"
echo "3. Check library: ldconfig -p | grep eccodes"
