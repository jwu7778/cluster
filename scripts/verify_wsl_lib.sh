#!/bin/bash
echo "=== Verifying WSL Library Mount ==="
if [ -f "/usr/lib/wsl/lib/libnvidia-ml.so.1" ]; then
    echo "SUCCESS: libnvidia-ml.so.1 found in /usr/lib/wsl/lib"
else
    echo "ERROR: libnvidia-ml.so.1 NOT found in /usr/lib/wsl/lib"
    echo "Listing /usr/lib/wsl/lib:"
    ls -F /usr/lib/wsl/lib
fi
