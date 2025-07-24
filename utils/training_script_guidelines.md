# Dashboard-Compatible Training Script Requirements

This document outlines the exact requirements for creating training scripts that work seamlessly with the dashboard system. Follow these guidelines to ensure consistent monitoring, visualization, and management across all ML experiments.

## 📋 Quick Checklist

- [ ] Import `dashboard_logger` module
- [ ] Use `initialize_training()` for setup
- [ ] Follow standardized logging patterns
- [ ] Save outputs to correct directories
- [ ] Handle errors properly
- [ ] Return appropriate exit codes

## 🏗️ Basic Script Structure

Every dashboard-compatible training script must follow this structure:

```python
#!/usr/bin/env python3
"""
Your Model Training Script - Dashboard Compatible
"""

from dashboard_logger import initialize_training

def train_your_model():
    """Main training function"""
    
    # 1. Initialize with dashboard logger (handles everything)
    config, run_id, output_dir, logger, dirs, timer = initialize_training(
        required_config_keys=['data_dir', 'num_epochs', 'batch_size']  # Specify required keys
    )
    
    # 2. Extract config parameters
    epochs = config['num_epochs']
    batch_size = config['batch_size']
    learning_rate = config.get('learning_rate', 0.001)  # Use .get() for optional params
    
    # 3. Log training metadata
    logger.log_metadata(
        model_type="YourModelName",
        total_epochs=epochs,
        device=device
    )
    
    # 4. Start training timer
    timer.start_training()
    
    # 5. Your training loop
    for epoch in range(1, epochs + 1):
        timer.start_epoch(epoch)
        
        # Training step logging
        for batch_idx, batch in enumerate(train_loader):
            # ... your training code ...
            
            logger.log_training_step(
                epoch=epoch,
                step=batch_idx,
                loss=current_loss,
                accuracy=current_accuracy  # Add any metrics you want
            )
        
        # Epoch completion logging
        epoch_time = timer.end_epoch(epoch)
        logger.log_epoch(
            epoch=epoch,
            avg_loss=epoch_avg_loss,
            avg_accuracy=epoch_avg_accuracy,
            epoch_time=epoch_time
        )
        
        # Save plots periodically
        if epoch % 5 == 0:
            logger.save_loss_plot({'train_loss': train_losses, 'val_loss': val_losses})
        
        # Save checkpoints
        if epoch % 10 == 0:
            checkpoint_path = dirs['checkpoints'] / f'model_epoch_{epoch}.pth'
            save_checkpoint(model, checkpoint_path)
            logger.log_checkpoint(checkpoint_path, epoch)
    
    # 6. Training completion
    timer.end_training()
    logger.log_completion()
    
    return 0  # Success

def main():
    """Entry point with error handling"""
    try:
        return train_your_model()
    except Exception as e:
        print(f"ERROR | Training failed: {str(e)}")
        return 1

if __name__ == "__main__":
    exit(main())
```

## 🔧 Required Imports

Always include these imports at the top of your script:

```python
from dashboard_logger import initialize_training
# Your model-specific imports below
```

## ⚙️ Configuration Requirements

### Required Config Keys
Your `config.json` must include these minimum keys:
```json
{
  "data_dir": "path/to/data",
  "num_epochs": 100,
  "batch_size": 32
}
```

### Recommended Config Structure
```json
{
  "data_dir": "processed_data",
  "num_epochs": 100,
  "batch_size": 32,
  "learning_rate": 0.001,
  
  "experiment_info": {
    "description": "Brief description of experiment",
    "model_type": "YourModelType",
    "notes": "Any additional notes"
  },
  
  "model_config": {
    "hidden_size": 256,
    "num_layers": 3
  },
  
  "training_config": {
    "save_frequency": 10,
    "eval_frequency": 5,
    "device": "auto"
  }
}
```

## 📊 Logging Requirements

### 1. Metadata Logging (Required)
Log essential information about your training run:

```python
logger.log_metadata(
    model_type="YourModelName",       # Required
    total_epochs=epochs,              # Required
    device=device,                    # Required
    dataset_size=len(dataset),        # Recommended
    model_parameters=count_params(),  # Recommended
    # Add any other relevant metadata
)
```

### 2. Training Step Logging (Required)
Log metrics during training (automatically filtered to avoid spam):

```python
logger.log_training_step(
    epoch=epoch,
    step=batch_idx,
    loss=loss_value,                  # Required
    # Add any other per-step metrics:
    accuracy=accuracy,
    learning_rate=current_lr,
    gradient_norm=grad_norm
)
```

### 3. Epoch Logging (Required)
Log epoch-level summaries:

```python
logger.log_epoch(
    epoch=epoch,
    avg_loss=avg_loss,               # Required
    avg_accuracy=avg_accuracy,       # Recommended
    epoch_time=epoch_duration,       # Recommended
    val_loss=val_loss,              # If validation exists
    val_accuracy=val_accuracy       # If validation exists
)
```

## 📈 Plot Requirements

### Automatic Loss Plots
Use the built-in loss plotting function:

```python
# Simple loss plot
logger.save_loss_plot({'train_loss': train_losses, 'val_loss': val_losses})

# Multiple metrics
logger.save_loss_plot({
    'train_loss': train_losses,
    'val_loss': val_losses,
    'train_accuracy': train_acc,
    'val_accuracy': val_acc
})
```

### Custom Plots
For model-specific visualizations:

```python
import matplotlib.pyplot as plt

fig, ax = plt.subplots(1, 1, figsize=(10, 6))
ax.plot(epochs, custom_metric)
ax.set_title('Custom Metric Over Time')
# ... customize your plot ...

logger.save_custom_plot(fig, 'custom_metric_plot', 'Custom Metric Visualization')
```

## 📁 Output Directory Structure

The `initialize_training()` function creates this structure automatically:

```
output_dir/
├── config.json          # Copy of training config (auto-created)
├── metrics.json         # Training metrics (auto-created)
├── checkpoints/         # Model checkpoints
├── plots/              # Training plots
│   ├── loss_curves.png
│   └── custom_plots.png
├── samples/            # Generated samples (if applicable)
├── logs/               # Additional logs
└── model/              # Final model
    └── final_model.pth
```

Access directories in your code:
```python
checkpoint_path = dirs['checkpoints'] / 'model.pth'
sample_path = dirs['samples'] / 'generated.png'
plot_path = dirs['plots'] / 'custom.png'
```

## ⏱️ Timing Requirements

Use the built-in timer for consistent time tracking:

```python
# Start overall training timer
timer.start_training()

# For each epoch
timer.start_epoch(epoch)
# ... training code ...
epoch_time = timer.end_epoch(epoch)

# End training
total_time = timer.end_training()
```

## 🚨 Error Handling

Always handle errors properly:

```python
def main():
    try:
        return train_your_model()
    except KeyboardInterrupt:
        print("ERROR | Training interrupted by user")
        return 1
    except FileNotFoundError as e:
        print(f"ERROR | Required file not found: {e}")
        return 1
    except Exception as e:
        print(f"ERROR | Training failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return 1
```

## 📝 Console Output Format

Your script will automatically output in this standardized format:

```
LOGGER_INIT | Run ID: experiment_001 | Output: ./runs/experiment_001
CONFIG_LOADED | config.json
SETUP | Training directories created
SYSTEM_INFO | {"platform": "Linux", "pytorch_version": "2.0.1", ...}
METADATA | {"model_type": "MyModel", "total_epochs": 100}
DEVICE | Using: cuda
TRAINING_START | Started at 2024-01-15 14:30:22
TRAIN_STEP | Epoch: 1 | Step: 10 | loss: 0.5432 | accuracy: 0.8765
EPOCH_END | Epoch: 1 | avg_loss: 0.4567 | avg_accuracy: 0.8901 | epoch_time: 45.67
PLOT_SAVED | Loss curves saved to ./runs/experiment_001/plots
CHECKPOINT | Epoch: 10 | Saved: ./runs/experiment_001/checkpoints/model_epoch_010.pth
TRAINING_COMPLETE | Run ID: experiment_001
```

## 🔍 Validation Checklist

Before submitting your training script, verify:

### ✅ **File Structure**
- [ ] Script imports `dashboard_logger`
- [ ] Uses `initialize_training()` for setup
- [ ] Follows the basic structure template

### ✅ **Configuration**
- [ ] Accepts `--config`, `--run-id`, `--output-dir` arguments
- [ ] Loads configuration from JSON file
- [ ] Validates required configuration keys

### ✅ **Logging**
- [ ] Logs metadata with `logger.log_metadata()`
- [ ] Logs training steps with `logger.log_training_step()`
- [ ] Logs epoch summaries with `logger.log_epoch()`
- [ ] Uses `logger.log_completion()` at the end

### ✅ **Outputs**
- [ ] Saves plots using `logger.save_loss_plot()`
- [ ] Saves checkpoints to `dirs['checkpoints']`
- [ ] Saves final model to `dirs['model']`
- [ ] Creates `metrics.json` automatically

### ✅ **Error Handling**
- [ ] Wraps main training in try-catch
- [ ] Returns 0 for success, 1 for failure
- [ ] Prints errors with "ERROR |" prefix

### ✅ **Testing**
- [ ] Test with minimal config (2 epochs)
- [ ] Verify output directory structure
- [ ] Check `metrics.json` format
- [ ] Confirm plots are generated

## 🎯 Common Patterns

### For Different Model Types

**Classification:**
```python
logger.log_training_step(epoch=epoch, step=step, loss=loss, accuracy=acc, f1_score=f1)
logger.log_epoch(epoch=epoch, avg_loss=avg_loss, avg_accuracy=avg_acc, val_accuracy=val_acc)
```

**Regression:**
```python
logger.log_training_step(epoch=epoch, step=step, loss=loss, mse=mse, mae=mae)
logger.log_epoch(epoch=epoch, avg_loss=avg_loss, avg_mse=avg_mse, val_mse=val_mse)
```

**GANs:**
```python
logger.log_training_step(epoch=epoch, step=step, g_loss=g_loss, d_loss=d_loss)
logger.log_epoch(epoch=epoch, avg_g_loss=avg_g_loss, avg_d_loss=avg_d_loss, fid_score=fid)
```

### For Different Data Types

**Images:**
```python
# Save sample images
if epoch % sample_freq == 0:
    save_samples(model, dirs['samples'] / f'epoch_{epoch}.png')
```

**Text:**
```python
# Save generated text samples
if epoch % sample_freq == 0:
    with open(dirs['samples'] / f'epoch_{epoch}.txt', 'w') as f:
        f.write(generated_text)
```

## 🚀 Quick Start Template

Copy this template for new training scripts:

```python
#!/usr/bin/env python3
"""
[MODEL_NAME] Training Script - Dashboard Compatible
"""

from dashboard_logger import initialize_training
# Add your imports here

def train_model():
    # Initialize dashboard
    config, run_id, output_dir, logger, dirs, timer = initialize_training(
        required_config_keys=['data_dir', 'num_epochs', 'batch_size']
    )
    
    # Extract config
    epochs = config['num_epochs']
    # ... other config params
    
    # Log metadata
    logger.log_metadata(model_type="[MODEL_NAME]", total_epochs=epochs)
    
    # Start training
    timer.start_training()
    
    # Your training loop here
    for epoch in range(1, epochs + 1):
        timer.start_epoch(epoch)
        
        # Training step
        for batch_idx, batch in enumerate(train_loader):
            # ... training code ...
            logger.log_training_step(epoch=epoch, step=batch_idx, loss=loss)
        
        # Epoch end
        epoch_time = timer.end_epoch(epoch)
        logger.log_epoch(epoch=epoch, avg_loss=avg_loss, epoch_time=epoch_time)
    
    # Complete training
    timer.end_training()
    logger.log_completion()
    return 0

def main():
    try:
        return train_model()
    except Exception as e:
        print(f"ERROR | Training failed: {str(e)}")
        return 1

if __name__ == "__main__":
    exit(main())
```

By following these requirements, your training scripts will work seamlessly with the dashboard system, providing consistent monitoring, visualization, and management across all your ML experiments.
