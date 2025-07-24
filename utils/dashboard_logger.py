"""
Dashboard Logger Module
Reusable utilities for dashboard-compatible training scripts
"""

import json
import time
import argparse
import os
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

class DashboardLogger:
    
    def __init__(self, output_dir, run_id):
        self.output_dir = Path(output_dir)
        self.run_id = run_id
        self.metrics_file = self.output_dir / "metrics.json"
        self.plots_dir = self.output_dir / "plots"
        
        self.metrics = {
            "training_metrics": [],
            "validation_metrics": [],
            "metadata": {"run_id": run_id}
        }
        
        self.plots_dir.mkdir(parents=True, exist_ok=True)
        print(f"LOGGER_INIT | Run ID: {run_id} | Output: {output_dir}")
        
    def log_metadata(self, **kwargs):
        self.metrics["metadata"].update(kwargs)
        self._save_metrics()
        print(f"METADATA | {json.dumps(kwargs, indent=None)}")
        
    def log_training_step(self, epoch, step, **metrics):
        entry = {
            "epoch": epoch,
            "step": step,
            "timestamp": time.time(),
            **metrics
        }
        self.metrics["training_metrics"].append(entry)
        
        if step % 10 == 0:
            metrics_str = " | ".join([f"{k}: {v:.4f}" for k, v in metrics.items()])
            print(f"TRAIN_STEP | Epoch: {epoch} | Step: {step} | {metrics_str}")
        
    def log_epoch(self, epoch, **metrics):
        entry = {
            "epoch": epoch,
            "timestamp": time.time(),
            **metrics
        }
        self.metrics["validation_metrics"].append(entry)
        
        metrics_str = " | ".join([f"{k}: {v:.4f}" for k, v in metrics.items()])
        print(f"EPOCH_END | Epoch: {epoch} | {metrics_str}")
        
        self._save_metrics()
        
    def _save_metrics(self):
        with open(self.metrics_file, 'w') as f:
            json.dump(self.metrics, f, indent=2)
    
    def save_loss_plot(self, losses_dict, epoch=None):
        if not losses_dict or not any(losses_dict.values()):
            return
            
        fig, ax = plt.subplots(1, 1, figsize=(10, 6))
        
        epochs = range(1, len(list(losses_dict.values())[0]) + 1)
        
        for loss_name, loss_values in losses_dict.items():
            if loss_values:
                ax.plot(epochs, loss_values, label=loss_name.replace('_', ' ').title(), linewidth=2)
        
        ax.set_title('Training Loss Curves')
        ax.set_xlabel('Epoch')
        ax.set_ylabel('Loss')
        ax.legend()
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        
        if epoch:
            plt.savefig(self.plots_dir / f'loss_curves_epoch_{epoch}.png', dpi=150, bbox_inches='tight')
        plt.savefig(self.plots_dir / 'loss_curves.png', dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"PLOT_SAVED | Loss curves saved to {self.plots_dir}")
    
    def save_custom_plot(self, fig, filename, title="Custom Plot"):
        plot_path = self.plots_dir / f"{filename}.png"
        fig.savefig(plot_path, dpi=150, bbox_inches='tight')
        plt.close(fig)
        print(f"PLOT_SAVED | {title} saved to {plot_path}")
    
    def log_checkpoint(self, checkpoint_path, epoch):
        print(f"CHECKPOINT | Epoch: {epoch} | Saved: {checkpoint_path}")
    
    def log_error(self, error_msg):
        print(f"ERROR | {error_msg}")
    
    def log_completion(self):
        print(f"TRAINING_COMPLETE | Run ID: {self.run_id}")
        print(f"FINAL_METRICS | Saved to: {self.metrics_file}")
        print(f"FINAL_PLOTS | Saved to: {self.plots_dir}")

def setup_training_directories(output_dir):
    output_path = Path(output_dir)
    directories = [
        output_path / 'checkpoints',
        output_path / 'plots', 
        output_path / 'samples',
        output_path / 'logs',
        output_path / 'model'
    ]
    
    for directory in directories:
        directory.mkdir(parents=True, exist_ok=True)
    
    print(f"SETUP | Training directories created in {output_dir}")
    return {
        'checkpoints': output_path / 'checkpoints',
        'plots': output_path / 'plots',
        'samples': output_path / 'samples', 
        'logs': output_path / 'logs',
        'model': output_path / 'model'
    }

def load_config(config_path):
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    print(f"CONFIG_LOADED | {config_path}")
    print(f"CONFIG | {json.dumps(config, indent=2)}")
    
    return config

def save_config_copy(config, output_dir):
    config_path = Path(output_dir) / "config.json"
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"CONFIG_SAVED | Copy saved to {config_path}")

def create_standard_parser():
    parser = argparse.ArgumentParser(description='Dashboard Compatible Training Script')
    
    parser.add_argument('--config', type=str, required=True,
                       help='Path to configuration JSON file')
    parser.add_argument('--run-id', type=str, required=True,
                       help='Unique run identifier')
    parser.add_argument('--output-dir', type=str, required=True,
                       help='Output directory for this run')
    
    return parser

def validate_training_setup(config, required_keys=None):
    if required_keys:
        missing_keys = [key for key in required_keys if key not in config]
        if missing_keys:
            raise ValueError(f"Missing required config keys: {missing_keys}")
    
    if 'data_dir' in config:
        data_dir = config['data_dir']
        if not os.path.exists(data_dir):
            raise ValueError(f"Data directory not found: {data_dir}")
        print(f"DATA_VALIDATED | Directory: {data_dir}")
    
    print("VALIDATION | Training setup validated successfully")
    return True

def log_system_info():
    import torch
    import platform
    
    info = {
        "platform": platform.platform(),
        "python_version": platform.python_version(),
        "pytorch_version": torch.__version__,
        "cuda_available": torch.cuda.is_available(),
    }
    
    if torch.cuda.is_available():
        info["cuda_version"] = torch.version.cuda
        info["gpu_count"] = torch.cuda.device_count()
        info["gpu_name"] = torch.cuda.get_device_name(0)
    
    print(f"SYSTEM_INFO | {json.dumps(info, indent=None)}")
    return info

class TrainingTimer:
    
    def __init__(self):
        self.start_time = None
        self.epoch_start = None
    
    def start_training(self):
        self.start_time = time.time()
        print(f"TRAINING_START | Started at {time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    def start_epoch(self, epoch):
        self.epoch_start = time.time()
    
    def end_epoch(self, epoch):
        if self.epoch_start is None:
            return 0
        
        duration = time.time() - self.epoch_start
        print(f"EPOCH_TIME | Epoch {epoch} took {duration:.2f} seconds")
        return duration
    
    def end_training(self):
        if self.start_time is None:
            return 0
            
        total_time = time.time() - self.start_time
        hours = int(total_time // 3600)
        minutes = int((total_time % 3600) // 60)
        seconds = int(total_time % 60)
        
        print(f"TRAINING_TIME | Total training time: {hours}h {minutes}m {seconds}s")
        return total_time

def initialize_training(required_config_keys=None):
    parser = create_standard_parser()
    args = parser.parse_args()
    
    config = load_config(args.config)
    validate_training_setup(config, required_config_keys)
    
    dirs = setup_training_directories(args.output_dir)
    save_config_copy(config, args.output_dir)
    
    logger = DashboardLogger(args.output_dir, args.run_id)
    
    system_info = log_system_info()
    logger.log_metadata(**system_info)
    
    timer = TrainingTimer()
    
    return config, args.run_id, args.output_dir, logger, dirs, timer