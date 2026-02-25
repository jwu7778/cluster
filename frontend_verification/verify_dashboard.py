import time
import subprocess
import os
import signal
from playwright.sync_api import sync_playwright

# 1. Start Backend with Mock Data
backend_process = subprocess.Popen(
    ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"],
    env={**os.environ, "MOCK_GPU": "true"}
)
print(f"Started Backend (PID: {backend_process.pid})")

# 2. Start Frontend (Serve Build)
frontend_process = subprocess.Popen(
    ["python3", "-m", "http.server", "3000", "--directory", "frontend/build"],
    env={**os.environ}
)
print(f"Started Frontend (PID: {frontend_process.pid})")

# Wait for services to start
time.sleep(5)

# Verify Backend Output manually
print("\n--- Verifying Backend Response ---")
subprocess.run(["curl", "-s", "http://localhost:8000/status"])
print("\n----------------------------------\n")

try:
    with sync_playwright() as p:
        print("Launching browser...")
        browser = p.chromium.launch()
        page = browser.new_page()

        # Log browser console messages
        page.on("console", lambda msg: print(f"BROWSER CONSOLE: {msg.text}"))

        print("Navigating to frontend...")
        page.goto("http://localhost:3000")

        print("Waiting for node card...")
        try:
            # Look for the specific mock data
            page.wait_for_selector("text=Mock GPU 1", timeout=10000)
            print("Node card found!")
        except Exception as e:
            print(f"FAILED to find node card: {e}")

        # Take screenshot regardless of success
        screenshot_path = "frontend_verification/dashboard_debug.png"
        page.screenshot(path=screenshot_path)
        print(f"Screenshot saved to {screenshot_path}")

finally:
    # Cleanup
    print("Stopping services...")
    backend_process.terminate()
    frontend_process.terminate()
    backend_process.wait()
    frontend_process.wait()
