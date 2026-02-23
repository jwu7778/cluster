import React, { useState, useEffect } from 'react';
import axios from 'axios';

const Dashboard = () => {
  const [nodes, setNodes] = useState({});
  const [loading, setLoading] = useState(true);

  const fetchStatus = async () => {
    try {
      // Assuming the frontend is served via dev server proxy or nginx in prod
      // The proxy in package.json handles /status -> http://localhost:8000/status
      const response = await axios.get('/status');
      setNodes(response.data);
      setLoading(false);
    } catch (error) {
      console.error("Error fetching status:", error);
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {loading && Object.keys(nodes).length === 0 && (
          <div className="col-span-full text-center text-gray-500">Loading node status...</div>
      )}

      {!loading && Object.keys(nodes).length === 0 && (
          <div className="col-span-full text-center py-10 text-gray-500 bg-white rounded shadow">
            No active nodes reporting.
          </div>
      )}

      {Object.values(nodes).map((node) => (
        <div key={node.node_name} className="bg-white shadow rounded-lg p-6 transition hover:shadow-lg">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold text-gray-700">{node.node_name}</h2>
            <span className={`px-2 py-1 text-xs rounded-full ${node.utilization_gpu > 80 ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'}`}>
              {node.utilization_gpu > 80 ? 'High Load' : 'Normal'}
            </span>
          </div>

          <div className="space-y-4">
            <div>
              <div className="flex justify-between mb-1">
                <span className="text-sm font-medium text-gray-600">GPU Utilization</span>
                <span className="text-sm font-medium text-gray-900">{node.utilization_gpu}%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2.5">
                <div
                    className={`h-2.5 rounded-full ${node.utilization_gpu > 80 ? 'bg-red-600' : 'bg-blue-600'}`}
                    style={{ width: `${node.utilization_gpu}%` }}
                ></div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="bg-gray-50 p-3 rounded">
                <p className="text-xs text-gray-500 uppercase">Memory Used</p>
                <p className="text-lg font-bold text-gray-800">{node.memory_used} MB</p>
              </div>
              <div className="bg-gray-50 p-3 rounded">
                <p className="text-xs text-gray-500 uppercase">Temperature</p>
                <p className="text-lg font-bold text-gray-800">
                    {node.temperature !== null ? `${node.temperature}°C` : 'N/A'}
                </p>
              </div>
            </div>

            <div className="text-xs text-gray-400 text-right mt-2">
              Updated: {new Date(node.timestamp * 1000).toLocaleTimeString()}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default Dashboard;
