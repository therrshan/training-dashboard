# ML Training Dashboard

A web-based dashboard for monitoring and managing machine learning training experiments with real-time visualization of metrics, plots, and generated samples.

## Features

- 🔍 **Auto-discovery** - Automatically finds training runs across multiple ML projects
- 📊 **Live Visualization** - View training plots, loss curves, and generated samples
- 📈 **Metrics Tracking** - Monitor training progress with detailed metrics
- 🎯 **Multi-Project** - Manage experiments from different ML projects in one place
- 🖥️ **Clean Interface** - Simple, responsive web interface

## Quick Start

### 1. Setup
```bash
git clone https://www.github.com/therrshan/training-dashboard
cd training-dashboard
chmod +x start.sh
```

### 2. Start Dashboard
```bash
./start.sh
```

### 3. Access
- **Dashboard**: http://localhost:3000
- **API**: http://localhost:8000

## Training Script Integration

Your training scripts must use the `dashboard_logger` module. See `utils/dashboard_logger.py` for the logger implementation and `utils/training_script_guidelines.md` for detailed integration instructions.

Basic usage:

```python
from dashboard_logger import initialize_training

def train_model():
    config, run_id, output_dir, logger, dirs, timer = initialize_training()
    
    for epoch in range(epochs):
        # Training code...
        logger.log_training_step(epoch=epoch, step=step, loss=loss)
        logger.log_epoch(epoch=epoch, avg_loss=avg_loss)
        logger.save_loss_plot({'train_loss': losses})
```

## File Structure

The dashboard expects this output structure from your training scripts:
```
runs/your_run_id/
├── config.json      # Training configuration
├── metrics.json     # Training metrics (auto-generated)
├── plots/           # Training plots and visualizations
│   ├── loss_curves.png
│   └── custom_plot.png
└── samples/         # Generated samples (if applicable)
    ├── epoch_001.png
    └── latest_samples.png
```

## Configuration

**Default Setup (No Configuration Needed):**
If you clone this dashboard into a folder containing your ML projects, it will automatically discover training runs:
```
your-workspace/
├── training-dashboard/    # This project
├── model-1/
│   └── runs/                # Auto-discovered ✅
├── model-2/
│   └── runs/                # Auto-discovered ✅
└── model-n/
    └── runs/                # Auto-discovered ✅
```

**Custom Locations:**
If your projects are in different locations, edit `TRAINING_RUNS_PATHS` in `backend/main.py`:
```python
TRAINING_RUNS_PATHS = [
    "./runs",                           
    "../*/runs",                        
    "/home/user/ml-projects/*/runs",    
    "../../research/*/runs",            
]
```

The start script will automatically install dependencies.