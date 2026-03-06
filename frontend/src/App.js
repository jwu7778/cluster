import React, { useState, useEffect } from 'react';

function App() {
  const [nodes, setNodes] = useState([]);

  useEffect(() => {
    const fetchStatus = async () => {
      try {
        // Changed to use relative /api/status endpoint
        const response = await fetch('/api/status');
        const data = await response.json();

        const newData = Array.isArray(data) ? data : [data];
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

      {nodes.length === 0 ? (
        <div className="text-center text-gray-500 mt-10">
          <p>No nodes reporting data. Is the backend running?</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {nodes.map((node, index) => (
            <div key={index} className="bg-white rounded-lg shadow-md p-6">
              <h2 className="text-xl font-semibold mb-4 text-gray-800 border-b pb-2">{node.node || 'Unknown Node'}</h2>

              {node.gpus && node.gpus.length > 0 ? (
                node.gpus.map((gpu, gIndex) => (
                  <div key={gIndex} className="mb-4 p-4 border rounded bg-gray-50 shadow-sm border-l-4 border-blue-500">
                    <div className="flex justify-between items-center mb-3">
                      <div>
                        <span className="font-bold text-sm text-gray-800 block">GPU {gpu.index}</span>
                        <span className="text-xs text-gray-500">{gpu.name}</span>
                      </div>
                      <span className={`px-2 py-1 rounded-full text-xs font-bold ${gpu.temperature > 80 ? 'bg-red-100 text-red-800' : gpu.temperature > 50 ? 'bg-yellow-100 text-yellow-800' : 'bg-green-100 text-green-800'}`}>
                        {gpu.temperature}°C
                      </span>
                    </div>

                    <div className="space-y-3">
                      <div>
                        <div className="flex justify-between text-xs mb-1 font-medium text-gray-600">
                          <span>Utilization</span>
                          <span>{gpu.utilization}%</span>
                        </div>
                        <div className="w-full bg-gray-200 rounded-full h-2">
                          <div
                            className={`h-2 rounded-full ${gpu.utilization > 80 ? 'bg-red-500' : gpu.utilization > 50 ? 'bg-yellow-400' : 'bg-green-500'}`}
                            style={{ width: `${Math.max(0, Math.min(100, gpu.utilization))}%` }}>
                          </div>
                        </div>
                      </div>

                      <div className="bg-white p-2 rounded border text-center">
                        <span className="block text-[10px] uppercase text-gray-400 font-bold mb-1">Memory Used</span>
                        <span className="text-sm font-bold text-gray-700">{gpu.memory_used} MB</span>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <p className="text-gray-500 italic p-4 bg-gray-50 rounded border border-dashed text-center">No GPUs detected on this node.</p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default App;
