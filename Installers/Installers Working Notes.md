The challenge - everyone I knew who tried to install Herbie had problems, and while reasonably well documented, there was not enough info to really help. Everyone was getting different errors and nothing was working. 
For my own needs, I put together a pair of scripts meant to brute force the install steps to work. This included bypassing some security steps and leveraging a VENV approach on the R-Pi. Once installed, an open terminal can attach the VENV and run. 
Tutorials often use VENV as the virtual environment name; however, I'm using that for a venv with flask and I didn't want to lose that if this didn't work so herbie_env was born


After install running these is a sanity check for success

  source ~/.herbie_env/bin/herbie_activate
  
  # Test ecCodes
  codes_info
  # Test Python import
  python -c "import eccodes; print('ecCodes works!')"
  python -c "import herbie; print('Herbie OK')"
  # Test Herbie
  find-wgrib2  # Uses the alias from activation script
  wgrib2 -version
  herbie --help


If you need to install eccodes and you're lucky, the following will work to get you there, otherwise use the sledgehammer approach script for that as well

  # Activate your environment first
  source ~/.herbie_env/bin/herbie_activate
  # Install ecCodes system library
  sudo apt update
  sudo apt install -y libeccodes-dev eccodes-tools
  # OR if that doesn't work, try the full ecCodes installation:
  sudo apt install -y libeccodes-dev eccodes-extra eccodes-tools python3-eccodes
  # Test if it works now
  herbie --help


If running on a multi-user system (such as one with a root user and a second login for XRDP) you can use the following to see if pathing is an issue, the sledgehammer approach should overcome this (tested for wgrib2  10-25 LH)
  # Check the paths are user-specific
  echo $HOME
  # Output: /home/[remote username]
  ls -la ~/.herbie_env/
  # Should show virtual environment in /home/[remote username]/.herbie_env
  which wgrib2
  # Should show: /usr/local/bin/wgrib2

Terminal should prompt for root/sudo password to run, if sharing with friends or you have users not in the sudoers file, add this to the head of each .sh file
  
  #!/bin/bash
  set -e
  echo "Current user: $USER"
  echo "Home directory: $HOME"
  # Warn if running as root
  if [ "$EUID" -eq 0 ]; then
      echo "WARNING: Running as root! This script should be run as a regular user with sudo privileges."
      read -p "Continue anyway? (y/N) " -n 1 -r
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          exit 1
      fi
  fi
  # Rest of the script continues...


source ~/.herbie_env/bin/herbie_activate
# Should activate environment and show wgrib2 status
