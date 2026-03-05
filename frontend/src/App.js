import React, { useState, useEffect } from 'react';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

function App() {
  const [nodes, setNodes] = useState([]);

  useEffect(() => {
    const fetchStatus = async () => {
      try {
        const response = await fetch(`${API_BASE_URL}/status`);
        const data = await response.json();

        // Backend now returns an array of nodes, so we set it directly.
        console.log("Fetched data from API:", data);
        const newData = Array.isArray(data) ? data : [data];
        console.log("Setting nodes to:", newData);
        setNodes(newData);
      } catch (error) {
        console.error("Error fetching status:", error);
      }
    };

    fetchStatus();
    const interval = setInterval(fetchStatus, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="bg-gray-100 min-h-screen p-8">
      <h1 className="text-3xl font-bold mb-8 text-center text-blue-600">GPU Cluster Monitor</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {nodes.map((node, index) => (
          <div key={index} className="bg-white rounded-lg shadow-md p-6">
            <h2 className="text-xl font-semibold mb-4 text-gray-800">{node.node || 'Unknown Node'}</h2>

            {node.gpus && node.gpus.length > 0 ? (
              node.gpus.map((gpu, gIndex) => (
                <div key={gIndex} className="mb-4 p-4 border rounded bg-gray-50">
                  <div className="flex justify-between items-center mb-2">
                    <span className="font-bold text-sm text-gray-600">GPU {gpu.index}: {gpu.name}</span>
                    <span className={`px-2 py-1 rounded text-xs text-white ${gpu.temperature > 80 ? 'bg-red-500' : 'bg-green-500'}`}>
                      {gpu.temperature}°C
                    </span>
                  </div>

                  <div className="mb-2">
                    <div className="flex justify-between text-xs mb-1">
                      <span>Usage</span>
                      <span>{gpu.utilization}%</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2.5">
                      <div className="bg-blue-600 h-2.5 rounded-full" style={{ width: `${gpu.utilization}%` }}></div>
                    </div>
                  </div>

                  <div>
                    <div className="flex justify-between text-xs mb-1">
                      <span>Memory</span>
                      <span>{gpu.memory_used} MiB</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2.5">
                       {/* Assuming 24GB VRAM for now, would be better to get total from API */}
                      <div className="bg-purple-600 h-2.5 rounded-full" style={{ width: `${(gpu.memory_used / 24576) * 100}%` }}></div>
                    </div>
                  </div>
                </div>
              ))
            ) : (
              <p className="text-gray-500 italic">No GPUs detected on this node.</p>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

export default App;
