import time
import socket
import os
import subprocess
import requests

# Default configuration
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")
NODE_NAME = os.getenv("NODE_NAME", socket.gethostname())
INTERVAL = 5

def get_gpu_stats():
    """
    Executes nvidia-smi to fetch GPU stats.
    Returns a dict with utilization, memory_used, and temperature.
    Only supports single GPU for now.
    """
    try:
        # Run nvidia-smi query
        # utilizing --format=csv,noheader,nounits
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,temperature.gpu', '--format=csv,noheader,nounits'],
            capture_output=True, text=True, check=True
        )
        output = result.stdout.strip()
        if not output:
            return None

        # Parse the first GPU (assuming 1 GPU per node for simplicity, or handle multiple)
        # Output example: "45, 1024, 65"
        parts = output.split(',')
        if len(parts) >= 2:
            return {
                "utilization_gpu": int(parts[0].strip()),
                "memory_used": int(parts[1].strip()),
                "temperature": int(parts[2].strip()) if len(parts) > 2 else None
            }
    except Exception as e:
        print(f"Error reading GPU stats: {e}")
        return None

def main():
    print(f"Starting GPU Monitor Agent on {NODE_NAME}, reporting to {BACKEND_URL}")
    while True:
        stats = get_gpu_stats()
        if stats:
            payload = {
                "node_name": NODE_NAME,
                "timestamp": time.time(),
                "utilization_gpu": stats["utilization_gpu"],
                "memory_used": stats["memory_used"],
                "temperature": stats["temperature"]
            }
            try:
                requests.post(f"{BACKEND_URL}/report", json=payload, timeout=2)
                print(f"Reported stats: {payload}")
            except Exception as e:
                print(f"Failed to report to backend: {e}")
        else:
            print("No GPU stats found (or nvidia-smi failed).")

        time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
