#!/bin/bash
set -e

echo "=== Debugging DaemonSet Rollout (v2.0) ==="

# 1. Check if the DaemonSet exists and its status
echo "--- Checking DaemonSet Status ---"
kubectl get daemonset -n kube-system nvidia-device-plugin-daemonset -o wide

# 2. Check if pods are running
echo "--- Checking DaemonSet Pods ---"
PODS=$(kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o name)
if [ -z "$PODS" ]; then
    echo "ERROR: No pods found for DaemonSet 'nvidia-device-plugin-daemonset'."
else
    echo "Found pods: $PODS"
    kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o wide
fi

# 3. Find missing libraries on Master (Ubuntu)
echo "--- Finding NVIDIA Libraries on Master ---"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: debug-nvidia-path
  namespace: kube-system
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: z890-gigabyte-arl997
  tolerations:
  - operator: Exists
  containers:
  - name: finder
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
      - |
        echo "Searching for libnvidia-ml.so.1 on host..."
        # Search specifically in /usr/lib and subdirectories first
        find /host/usr/lib -name libnvidia-ml.so.1 2>/dev/null
        # Fallback to root search if not found (might be slow)
        if [ $? -ne 0 ]; then
          find /host -name libnvidia-ml.so.1 2>/dev/null
        fi
        echo "Done searching."
    volumeMounts:
    - name: host-root
      mountPath: /host
      readOnly: true
  volumes:
  - name: host-root
    hostPath:
      path: /
      type: Directory
EOF

echo "Waiting for library search to complete..."
kubectl wait --for=condition=complete --timeout=60s pod/debug-nvidia-path -n kube-system || echo "Timed out waiting for pod"
kubectl logs debug-nvidia-path -n kube-system || echo "Could not get logs from debug pod"
kubectl delete pod debug-nvidia-path -n kube-system --ignore-not-found

# 4. Check Node Status & Logs
echo "--- Checking Node Status ---"
kubectl get nodes -o wide
kubectl describe nodes | grep -E "Taint|Allocatable|Capacity" -A 5

# 5. Check logs of running/completed/crashed pods
echo "--- Fetching Device Plugin Logs ---"
for pod in $PODS; do
    echo "Logs for Pod: $pod"
    kubectl logs $pod -n kube-system --tail=50 || echo "Cannot fetch logs for $pod"
    echo "-----------------------------------"
done

echo "=== End of Debug Report ==="
