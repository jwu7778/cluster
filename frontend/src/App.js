import React from 'react';
import Dashboard from './Dashboard';

function App() {
  return (
    <div className="App min-h-screen bg-gray-100 p-8">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-gray-800">Distributed GPU Monitor</h1>
      </header>
      <main>
        <Dashboard />
      </main>
    </div>
  );
}

export default App;
