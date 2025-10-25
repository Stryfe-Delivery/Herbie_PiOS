#!/bin/bash
# make executable and run from term
# the default repo works but HERBIE throws a warning due to version #
# this forces an update using multiple failovers to ensure you have the newest version

# Store the original user and venv path
ORIGINAL_USER=$(whoami)
VENV_PATH="/home/remote/Documents/Herbie/venv2"

# Function to check ecCodes version in different contexts and return both version and path
check_eccodes_version() {
    local version="0.0.0"
    local path="not found"
    
    # Check system-wide installation first
    if command -v grib_info &> /dev/null; then
        version=$(grib_info --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
        path=$(which grib_info)
        echo "$version|$path"
        return 0
    fi
    
    # Check in the virtual environment
    if [ -f "$VENV_PATH/bin/activate" ]; then
        # Source the virtual environment and check for grib_info
        local venv_check=$(bash -c "source '$VENV_PATH/bin/activate' 2>/dev/null && which grib_info 2>/dev/null")
        if [ -n "$venv_check" ]; then
            version=$(bash -c "source '$VENV_PATH/bin/activate' && grib_info --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo '0.0.0'")
            path="$venv_check (in VENV)"
            echo "$version|$path"
            return 0
        fi
    fi
    
    # Check if Python can import gribapi and get version
    if [ -f "$VENV_PATH/bin/activate" ]; then
        local python_version=$(bash -c "source '$VENV_PATH/bin/activate' 2>/dev/null && python -c 'import gribapi; print(gribapi.__version__)' 2>/dev/null" || echo "0.0.0")
        if [ "$python_version" != "0.0.0" ] && [ "$python_version" != "" ]; then
            version="$python_version"
            path="Python gribapi package in VENV"
            echo "$version|$path"
            return 0
        fi
    fi
    
    echo "0.0.0|not found"
}

# Function to compare versions - returns 0 (success) if first version >= second version
version_compare() {
    [ "$1" = "$2" ] && return 0
    local IFS=.
    local i ver1=($1) ver2=($2)
    # Fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            # Fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    return 0
}

# Check current version
echo "Checking ecCodes version..."
VERSION_INFO=$(check_eccodes_version)
CURRENT_VERSION=$(echo "$VERSION_INFO" | cut -d'|' -f1)
DETECTION_PATH=$(echo "$VERSION_INFO" | cut -d'|' -f2)

echo "Detected ecCodes version: $CURRENT_VERSION"
echo "Found at: $DETECTION_PATH"

# Check if version is sufficient - FIXED LOGIC
if version_compare "$CURRENT_VERSION" "2.39.0"; then
    echo "ecCodes version is already 2.39.0 or higher. No update needed."
    exit 0
else
    echo "ecCodes version $CURRENT_VERSION is less than 2.39.0. Update required."
fi

# Check if running as root, if not re-run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires elevated privileges. Restarting with sudo..."
    exec sudo "$0" "$@"
fi

set -e  # Exit on any error

echo "Updating ecCodes to version 2.39.0 or higher..."

# Function to update version info after each step
update_version_info() {
    VERSION_INFO=$(check_eccodes_version)
    CURRENT_VERSION=$(echo "$VERSION_INFO" | cut -d'|' -f1)
    DETECTION_PATH=$(echo "$VERSION_INFO" | cut -d'|' -f2)
    echo "Current version: $CURRENT_VERSION (found at: $DETECTION_PATH)"
}

# Option 1: Update via package manager
echo ""
echo "Attempting Option 1: Updating via package manager..."

# Update package lists but don't fail if there are issues
apt update || echo "Warning: apt update had some issues, but continuing..."

# Check if eccodes package exists before trying to install it
if apt-cache show eccodes &> /dev/null; then
    echo "eccodes package found in repositories, attempting installation..."
    if apt install -y eccodes libeccodes-dev; then
        update_version_info
        if version_compare "$CURRENT_VERSION" "2.39.0"; then
            echo "Successfully updated via package manager"
            
            # Reinstall Python package in the virtual environment
            echo ""
            echo "Reinstalling Python gribapi package in the virtual environment..."
            if [ -f "$VENV_PATH/bin/activate" ]; then
                bash -c "
                    source '$VENV_PATH/bin/activate'
                    echo 'Uninstalling old gribapi package...'
                    pip uninstall -y gribapi
                    echo 'Installing new gribapi package...'
                    pip install gribapi
                    echo 'Python package reinstalled in virtual environment'
                "
            fi
            exit 0
        else
            echo "Package manager version is still insufficient. Trying Option 2..."
        fi
    else
        echo "Failed to install eccodes via package manager. Trying Option 2..."
    fi
else
    echo "eccodes package not found in repositories. Trying Option 2..."
fi

# Option 2: Install from ECMWF repository
echo ""
echo "Attempting Option 2: Installing from ECMWF repository..."

# Remove existing version if it exists
apt remove -y eccodes libeccodes-dev 2>/dev/null || echo "No existing eccodes package to remove"

# Add ECMWF repository using the new method (without apt-key)
if ! grep -q "software.ecmwf.int" /etc/apt/sources.list; then
    echo "Adding ECMWF repository..."
    echo "deb https://software.ecmwf.int/ubuntu/ bionic main" >> /etc/apt/sources.list
    
    # New method for adding GPG key (without apt-key)
    echo "Adding ECMWF GPG key using new method..."
    mkdir -p /etc/apt/keyrings
    wget -q -O - https://software.ecmwf.int/apt/ecmwf-trusty.gpg | gpg --dearmor -o /etc/apt/keyrings/ecmwf.gpg
    echo "deb [signed-by=/etc/apt/keyrings/ecmwf.gpg] https://software.ecmwf.int/ubuntu/ bionic main" > /etc/apt/sources.list.d/ecmwf.list
fi

apt update

# Check if ECMWF repository provides the packages
if apt-cache show eccodes &> /dev/null; then
    apt install -y eccodes libeccodes-dev
    
    update_version_info
    if version_compare "$CURRENT_VERSION" "2.39.0"; then
        echo "Successfully updated via ECMWF repository"
        
        # Reinstall Python package in the virtual environment
        echo ""
        echo "Reinstalling Python gribapi package in the virtual environment..."
        if [ -f "$VENV_PATH/bin/activate" ]; then
            bash -c "
                source '$VENV_PATH/bin/activate'
                echo 'Uninstalling old gribapi package...'
                pip uninstall -y gribapi
                echo 'Installing new gribapi package...'
                pip install gribapi
                echo 'Python package reinstalled in virtual environment'
            "
        fi
        exit 0
    else
        echo "ECMWF repository version is still insufficient. Trying Option 3..."
    fi
else
    echo "eccodes package not found in ECMWF repository either. Trying Option 3..."
fi

# Option 3: Build from source
echo ""
echo "Attempting Option 3: Building from source..."

# Install build dependencies
echo "Installing build dependencies..."
apt update
apt install -y build-essential cmake libaec-dev zlib1g-dev libssl-dev python3-dev wget tar gnupg  # Added gnupg for gpg command

# Download and build ecCodes 2.39.0
cd /tmp
echo "Downloading ecCodes source..."
wget -q https://confluence.ecmwf.int/download/attachments/45757960/eccodes-2.39.0-Source.tar.gz
tar -xzf eccodes-2.39.0-Source.tar.gz
cd eccodes-2.39.0-Source

mkdir build && cd build
echo "Configuring and building ecCodes (this may take a while)..."
cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)

# Remove any existing ecCodes
apt remove -y eccodes libeccodes-dev 2>/dev/null || echo "No existing eccodes package to remove"

# Install the new version
echo "Installing built version..."
make install
ldconfig

update_version_info
if version_compare "$CURRENT_VERSION" "2.39.0"; then
    echo "Successfully built and installed from source"
else
    echo "Failed to build from source."
    exit 1
fi

echo ""
echo "ecCodes system update completed successfully!"

# Reinstall Python package in the virtual environment
echo ""
echo "Reinstalling Python gribapi package in the virtual environment..."
if [ -f "$VENV_PATH/bin/activate" ]; then
    bash -c "
        source '$VENV_PATH/bin/activate'
        echo 'Uninstalling old gribapi package...'
        pip uninstall -y gribapi
        echo 'Installing new gribapi package...'
        pip install gribapi
        echo '✓ Python package reinstalled in virtual environment'
    "
else
    echo "Virtual environment not found at $VENV_PATH, skipping Python package reinstall"
fi

# Final verification
echo ""
echo "Final verification:"
FINAL_INFO=$(check_eccodes_version)
FINAL_VERSION=$(echo "$FINAL_INFO" | cut -d'|' -f1)
FINAL_PATH=$(echo "$FINAL_INFO" | cut -d'|' -f2)

echo "Final ecCodes version: $FINAL_VERSION"
echo "Final location: $FINAL_PATH"

if version_compare "$FINAL_VERSION" "2.39.0"; then
    echo "Update completed successfully!"
else
    echo "Warning: Version might still be insufficient. Please check manually."
fi
