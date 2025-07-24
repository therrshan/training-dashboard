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
import glob

app = FastAPI(title="ML Training Dashboard")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration - where to look for training runs
TRAINING_RUNS_PATHS = [
    "./runs",                    # Local runs directory
    "../*/runs",                 # Sibling project runs
    "../../*/runs",              # Parent directory projects
    "/path/to/your/projects/*/runs",  # Absolute paths
]

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

def find_all_runs():
    """Find all training runs across multiple project directories"""
    all_runs = []
    
    for path_pattern in TRAINING_RUNS_PATHS:
        # Expand glob patterns
        for runs_dir in glob.glob(path_pattern):
            runs_path = Path(runs_dir)
            
            if not runs_path.exists():
                continue
                
            print(f"Scanning for runs in: {runs_path}")
            
            # Look for run directories
            for run_dir in runs_path.iterdir():
                if not run_dir.is_dir():
                    continue
                    
                # Check if this looks like a training run (has config.json or metrics.json)
                config_file = run_dir / "config.json"
                metrics_file = run_dir / "metrics.json"
                
                if not (config_file.exists() or metrics_file.exists()):
                    continue
                
                run_info = {
                    "id": run_dir.name,
                    "path": str(run_dir),
                    "project": runs_path.parent.name if runs_path.parent.name != "." else "local",
                    "status": "completed",  # We'll detect running status later
                    "created_at": datetime.fromtimestamp(run_dir.stat().st_ctime).isoformat(),
                }
                
                # Load config if exists
                if config_file.exists():
                    try:
                        with open(config_file) as f:
                            run_info["config"] = json.load(f)
                    except:
                        run_info["config"] = {}
                
                # Load basic metrics if exists
                if metrics_file.exists():
                    try:
                        with open(metrics_file) as f:
                            metrics = json.load(f)
                            run_info["metrics_count"] = len(metrics.get("training_metrics", []))
                            run_info["epochs"] = len(metrics.get("validation_metrics", []))
                            
                            # Check if run is still active (recent metrics)
                            if metrics.get("validation_metrics"):
                                last_metric = metrics["validation_metrics"][-1]
                                last_time = last_metric.get("timestamp", 0)
                                if datetime.now().timestamp() - last_time < 300:  # 5 minutes
                                    run_info["status"] = "running"
                    except:
                        run_info["metrics_count"] = 0
                        run_info["epochs"] = 0
                
                all_runs.append(run_info)
    
    # Sort by creation time, newest first
    all_runs.sort(key=lambda x: x["created_at"], reverse=True)
    return all_runs

@app.get("/")
async def root():
    return {"message": "ML Training Dashboard API"}

@app.get("/api/runs")
async def get_runs():
    """Get all training runs from all projects"""
    runs = find_all_runs()
    return {"runs": runs}

@app.get("/api/runs/{run_id}")
async def get_run(run_id: str):
    """Get specific run details"""
    # Find the run across all paths
    all_runs = find_all_runs()
    run = next((r for r in all_runs if r["id"] == run_id), None)
    
    if not run:
        return {"error": "Run not found"}
    
    run_dir = Path(run["path"])
    
    # Load metrics
    metrics_file = run_dir / "metrics.json"
    metrics = {}
    if metrics_file.exists():
        try:
            with open(metrics_file) as f:
                metrics = json.load(f)
        except:
            metrics = {}
    
    # Load config
    config_file = run_dir / "config.json"
    config = {}
    if config_file.exists():
        try:
            with open(config_file) as f:
                config = json.load(f)
        except:
            config = {}
    
    # Get available plots - FILTER OUT INTERMEDIATE EPOCH PLOTS
    plots_dir = run_dir / "plots"
    plots = []
    if plots_dir.exists():
        all_plot_files = [f.name for f in plots_dir.iterdir() if f.suffix in [".png", ".jpg", ".jpeg"]]
        
        # Filter logic: exclude files with "epoch_" in the name unless they're the latest
        plots = []
        epoch_plots = {}  # Track epoch plots by base name
        
        for plot_file in all_plot_files:
            # Check if this is an epoch-specific plot
            if "_epoch_" in plot_file:
                continue
            else:
                # Not an epoch plot, include it
                plots.append(plot_file)
        
        # Add only the latest epoch plot for each base name
        for base_name, info in epoch_plots.items():
            plots.append(info["file"])
        
        # Sort plots for consistent ordering
        plots.sort()
    
    # Get available samples - KEEP ALL SAMPLES
    samples_dir = run_dir / "samples"
    samples = []
    if samples_dir.exists():
        samples = [f.name for f in samples_dir.iterdir() if f.suffix in [".png", ".jpg", ".jpeg"]]
        samples.sort()  # Sort for consistent ordering
    
    return {
        "id": run_id,
        "path": run["path"],
        "project": run["project"],
        "config": config,
        "metrics": metrics,
        "plots": plots,
        "samples": samples,
        "status": run["status"]
    }

@app.get("/api/files/{run_id}/{file_path:path}")
async def serve_file(run_id: str, file_path: str):
    """Serve files from run directory"""
    from fastapi.responses import FileResponse
    
    # Find the run to get its path
    all_runs = find_all_runs()
    run = next((r for r in all_runs if r["id"] == run_id), None)
    
    if not run:
        return {"error": "Run not found"}
    
    file_full_path = Path(run["path"]) / file_path
    
    if file_full_path.exists() and file_full_path.is_file():
        return FileResponse(file_full_path)
    
    return {"error": "File not found"}

@app.get("/api/config")
async def get_config():
    """Get dashboard configuration"""
    return {
        "training_paths": TRAINING_RUNS_PATHS,
        "scan_results": [str(Path(p)) for p in TRAINING_RUNS_PATHS if Path(p).exists()]
    }

@app.post("/api/config/paths")
async def add_training_path(path: dict):
    """Add a new path to scan for training runs"""
    new_path = path.get("path")
    if new_path and new_path not in TRAINING_RUNS_PATHS:
        TRAINING_RUNS_PATHS.append(new_path)
        return {"message": f"Added path: {new_path}"}
    return {"error": "Invalid or duplicate path"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Could broadcast run updates here
            await manager.broadcast(f"Update: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    print("🔍 Scanning for training runs in:")
    for path in TRAINING_RUNS_PATHS:
        expanded = glob.glob(path)
        for p in expanded:
            if Path(p).exists():
                print(f"  ✅ {p}")
            else:
                print(f"  ❌ {p} (not found)")
    
    print("\n🚀 Starting ML Training Dashboard API...")
    uvicorn.run(app, host="0.0.0.0", port=8000)