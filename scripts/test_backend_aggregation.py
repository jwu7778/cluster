import requests
import json
import time

# Mock Backend URL (assuming local testing for now)
BACKEND_URL = "http://localhost:8000"

# Mock Data for different nodes
nodes = [
    {
        "node": "worker-1",
        "gpus": [
            {"index": "0", "name": "NVIDIA RTX 3090", "utilization": 80, "memory_used": 12000, "temperature": 75}
        ],
        "gpu_count": 1
    },
    {
        "node": "worker-2",
        "gpus": [
            {"index": "0", "name": "NVIDIA A100", "utilization": 45, "memory_used": 20000, "temperature": 60},
            {"index": "1", "name": "NVIDIA A100", "utilization": 10, "memory_used": 4000, "temperature": 55}
        ],
        "gpu_count": 2
    }
]

def test_reporting():
    print(f"Testing reporting to {BACKEND_URL}...")

    # 1. Check initial status (should be empty or local only)
    try:
        r = requests.get(f"{BACKEND_URL}/status")
        print(f"Initial Status Code: {r.status_code}")
        print(f"Initial Data: {json.dumps(r.json(), indent=2)}")
    except requests.exceptions.ConnectionError:
        print("Backend not running? Please start it with: uvicorn backend.main:app --port 8000")
        return

    # 2. Report data for each mock node
    for node_data in nodes:
        print(f"\nReporting for {node_data['node']}...")
        r = requests.post(f"{BACKEND_URL}/report", json=node_data)
        print(f"Report Response: {r.status_code} - {r.json()}")

    # 3. Check status again (should now include reports)
    print("\nFetching updated status...")
    r = requests.get(f"{BACKEND_URL}/status")
    data = r.json()
    print(f"Updated Data: {json.dumps(data, indent=2)}")

    # Validation
    if len(data) >= 2:
        print("\nSUCCESS: Backend is aggregating reports correctly.")
    else:
        print("\nFAILURE: Backend did not return expected number of nodes.")

if __name__ == "__main__":
    test_reporting()
