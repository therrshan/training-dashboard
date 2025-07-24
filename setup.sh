#!/bin/bash

# Simple ML Training Dashboard Setup Script
set -e

echo "🚀 Setting up ML Training Dashboard (Simple Version)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python 3 is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Python 3 found: $(python3 --version)${NC}"
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Node.js found: $(node --version)${NC}"
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm is required but not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ npm found: $(npm --version)${NC}"
}

# Create simple project structure
create_structure() {
    echo "📁 Creating project structure..."
    
    # Main directories
    mkdir -p backend
    mkdir -p frontend/src/components
    mkdir -p frontend/public
    mkdir -p runs
    mkdir -p data
    
    echo -e "${GREEN}✅ Project structure created${NC}"
}

# Setup Python environment
setup_python() {
    echo "🐍 Setting up Python backend..."
    
    # Create virtual environment
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        echo -e "${GREEN}✅ Virtual environment created${NC}"
    else
        echo -e "${YELLOW}⚠️  Virtual environment already exists${NC}"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Create simple requirements.txt
    cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6
websockets==12.0
watchdog==3.0.0
python-dotenv==1.0.0
aiofiles==23.2.1
EOF
    
    # Install Python dependencies
    pip install -r requirements.txt
    
    echo -e "${GREEN}✅ Python environment setup complete${NC}"
}

# Setup Node.js environment
setup_node() {
    echo "📦 Setting up React frontend..."
    
    cd frontend
    
    # Create simple package.json
    cat > package.json << 'EOF'
{
  "name": "ml-dashboard-frontend",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "axios": "^1.6.0",
    "chart.js": "^4.4.0",
    "react-chartjs-2": "^5.2.0",
    "lucide-react": "^0.292.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^4.4.0",
    "tailwindcss": "^3.3.0",
    "autoprefixer": "^10.4.14",
    "postcss": "^8.4.24"
  }
}
EOF
    
    # Install Node dependencies
    npm install
    
    # Setup Tailwind CSS
    npx tailwindcss init -p
    
    # Create Vite config
    cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': 'http://localhost:8000',
      '/ws': {
        target: 'ws://localhost:8000',
        ws: true,
      }
    }
  }
})
EOF
    
    cd ..
    echo -e "${GREEN}✅ Node.js environment setup complete${NC}"
}

# Create basic files
create_basic_files() {
    echo "📝 Creating basic application files..."
    
    # Backend main file
    cat > backend/main.py << 'EOF'
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import json
import os
from pathlib import Path
import asyncio
from typing import List
import sqlite3
from datetime import datetime

app = FastAPI(title="ML Training Dashboard")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple in-memory storage for now
active_runs = {}
websocket_connections = {}

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                pass

manager = ConnectionManager()

@app.get("/")
async def root():
    return {"message": "ML Training Dashboard API"}

@app.get("/api/runs")
async def get_runs():
    """Get all training runs"""
    runs = []
    runs_dir = Path("./runs")
    
    if runs_dir.exists():
        for run_dir in runs_dir.iterdir():
            if run_dir.is_dir():
                config_file = run_dir / "config.json"
                metrics_file = run_dir / "metrics.json"
                
                run_info = {
                    "id": run_dir.name,
                    "status": "completed",
                    "created_at": datetime.fromtimestamp(run_dir.stat().st_ctime).isoformat(),
                }
                
                # Load config if exists
                if config_file.exists():
                    with open(config_file) as f:
                        run_info["config"] = json.load(f)
                
                # Load basic metrics if exists
                if metrics_file.exists():
                    with open(metrics_file) as f:
                        metrics = json.load(f)
                        run_info["metrics_count"] = len(metrics.get("training_metrics", []))
                        run_info["epochs"] = len(metrics.get("validation_metrics", []))
                
                runs.append(run_info)
    
    return {"runs": runs}

@app.get("/api/runs/{run_id}")
async def get_run(run_id: str):
    """Get specific run details"""
    run_dir = Path(f"./runs/{run_id}")
    
    if not run_dir.exists():
        return {"error": "Run not found"}
    
    # Load metrics
    metrics_file = run_dir / "metrics.json"
    metrics = {}
    if metrics_file.exists():
        with open(metrics_file) as f:
            metrics = json.load(f)
    
    # Load config
    config_file = run_dir / "config.json"
    config = {}
    if config_file.exists():
        with open(config_file) as f:
            config = json.load(f)
    
    # Get available plots
    plots_dir = run_dir / "plots"
    plots = []
    if plots_dir.exists():
        plots = [f.name for f in plots_dir.iterdir() if f.suffix == ".png"]
    
    return {
        "id": run_id,
        "config": config,
        "metrics": metrics,
        "plots": plots,
        "status": "completed"
    }

@app.get("/api/files/{run_id}/{file_path:path}")
async def serve_file(run_id: str, file_path: str):
    """Serve files from run directory"""
    from fastapi.responses import FileResponse
    
    file_full_path = Path(f"./runs/{run_id}/{file_path}")
    
    if file_full_path.exists() and file_full_path.is_file():
        return FileResponse(file_full_path)
    
    return {"error": "File not found"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast(f"Echo: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

    # Frontend index.html
    cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>ML Training Dashboard</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

    # Frontend main files
    cat > frontend/src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

    cat > frontend/src/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react'
import axios from 'axios'
import { PlayCircle, Square, BarChart3, Settings } from 'lucide-react'

function App() {
  const [runs, setRuns] = useState([])
  const [selectedRun, setSelectedRun] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchRuns()
  }, [])

  const fetchRuns = async () => {
    try {
      const response = await axios.get('/api/runs')
      setRuns(response.data.runs)
    } catch (error) {
      console.error('Error fetching runs:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchRunDetails = async (runId) => {
    try {
      const response = await axios.get(`/api/runs/${runId}`)
      setSelectedRun(response.data)
    } catch (error) {
      console.error('Error fetching run details:', error)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-xl">Loading...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <h1 className="text-3xl font-bold text-gray-900">
              ML Training Dashboard
            </h1>
            <div className="flex space-x-4">
              <button className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
                <PlayCircle className="inline w-4 h-4 mr-2" />
                New Run
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            
            {/* Runs List */}
            <div className="lg:col-span-1">
              <div className="bg-white shadow rounded-lg">
                <div className="px-4 py-5 sm:p-6">
                  <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                    Training Runs
                  </h3>
                  <div className="space-y-3">
                    {runs.map((run) => (
                      <div
                        key={run.id}
                        className={`p-3 border rounded cursor-pointer hover:bg-gray-50 ${
                          selectedRun?.id === run.id ? 'border-blue-500 bg-blue-50' : 'border-gray-200'
                        }`}
                        onClick={() => fetchRunDetails(run.id)}
                      >
                        <div className="flex justify-between items-center">
                          <span className="font-medium">{run.id}</span>
                          <span className={`px-2 py-1 text-xs rounded ${
                            run.status === 'completed' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                          }`}>
                            {run.status}
                          </span>
                        </div>
                        <div className="text-sm text-gray-500 mt-1">
                          {run.epochs || 0} epochs • {run.metrics_count || 0} metrics
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>

            {/* Run Details */}
            <div className="lg:col-span-2">
              {selectedRun ? (
                <div className="bg-white shadow rounded-lg">
                  <div className="px-4 py-5 sm:p-6">
                    <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                      Run Details: {selectedRun.id}
                    </h3>
                    
                    {/* Config */}
                    <div className="mb-6">
                      <h4 className="text-md font-medium text-gray-900 mb-2">Configuration</h4>
                      <pre className="bg-gray-100 p-3 rounded text-sm overflow-auto">
                        {JSON.stringify(selectedRun.config, null, 2)}
                      </pre>
                    </div>

                    {/* Plots */}
                    {selectedRun.plots && selectedRun.plots.length > 0 && (
                      <div className="mb-6">
                        <h4 className="text-md font-medium text-gray-900 mb-2">Training Plots</h4>
                        <div className="grid grid-cols-1 gap-4">
                          {selectedRun.plots.map((plot) => (
                            <div key={plot} className="border rounded p-2">
                              <img 
                                src={`/api/files/${selectedRun.id}/plots/${plot}`}
                                alt={plot}
                                className="w-full h-auto"
                              />
                              <p className="text-sm text-gray-600 mt-2">{plot}</p>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Metrics Summary */}
                    {selectedRun.metrics.validation_metrics && (
                      <div>
                        <h4 className="text-md font-medium text-gray-900 mb-2">Metrics Summary</h4>
                        <div className="bg-gray-50 p-3 rounded">
                          <p>Total Epochs: {selectedRun.metrics.validation_metrics.length}</p>
                          <p>Training Steps: {selectedRun.metrics.training_metrics?.length || 0}</p>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              ) : (
                <div className="bg-white shadow rounded-lg">
                  <div className="px-4 py-5 sm:p-6 text-center text-gray-500">
                    Select a training run to view details
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

export default App
EOF

    cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF

    # Start script
    cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting ML Training Dashboard..."

# Start backend
echo "📡 Starting backend on http://localhost:8000"
source venv/bin/activate
cd backend
python main.py &
BACKEND_PID=$!
cd ..

# Wait a moment for backend to start
sleep 2

# Start frontend
echo "🎨 Starting frontend on http://localhost:3000"
cd frontend
npm run dev &
FRONTEND_PID=$!
cd ..

echo "✅ Dashboard started!"
echo "🌐 Open http://localhost:3000 in your browser"
echo ""
echo "Press Ctrl+C to stop"

# Cleanup function
cleanup() {
    echo "🛑 Stopping servers..."
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    exit 0
}

trap cleanup INT
wait
EOF

    chmod +x start.sh

    echo -e "${GREEN}✅ Basic application files created${NC}"
}

# Main setup function
main() {
    echo -e "${BLUE}🎯 Simple ML Training Dashboard Setup${NC}"
    echo ""
    
    check_prerequisites
    create_structure
    setup_python
    setup_node
    create_basic_files
    
    echo ""
    echo -e "${GREEN}🎉 Setup complete!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Copy your dashboard_logger.py to this directory"
    echo "2. Start the dashboard: ./start.sh"
    echo "3. Visit http://localhost:3000"
    echo "4. Test with a training script"
    echo ""
    echo -e "${BLUE}Happy training! 🚀${NC}"
}

# Run main function
main "$@"
