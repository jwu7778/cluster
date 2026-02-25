#!/bin/bash

LOG_FILE="logs_nvidia_crash.txt"

echo "Finding crashing NVIDIA Device Plugin pods..."
POD=$(kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "No NVIDIA Device Plugin pods found."
    exit 1
fi

echo "Inspecting pod: $POD" | tee "$LOG_FILE"
echo "--------------------------------------------------" | tee -a "$LOG_FILE"

echo "### Pod Description ###" | tee -a "$LOG_FILE"
kubectl describe pod "$POD" -n kube-system >> "$LOG_FILE" 2>&1
echo "--------------------------------------------------" | tee -a "$LOG_FILE"

echo "### Pod Logs (Current) ###" | tee -a "$LOG_FILE"
kubectl logs "$POD" -n kube-system >> "$LOG_FILE" 2>&1
echo "--------------------------------------------------" | tee -a "$LOG_FILE"

echo "### Pod Logs (Previous Instance - if crashed) ###" | tee -a "$LOG_FILE"
kubectl logs "$POD" -n kube-system --previous >> "$LOG_FILE" 2>&1
echo "--------------------------------------------------" | tee -a "$LOG_FILE"

echo "Logs saved to $LOG_FILE. Please verify the output or provide it for analysis."
