#!/bin/bash

# ML Training Dashboard Startup Script
# This script can be run from anywhere and will start the dashboard

# Get the directory where this script is located (dashboard project root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DASHBOARD_DIR="$SCRIPT_DIR"

echo "🚀 Starting ML Training Dashboard..."
echo "📁 Dashboard location: $DASHBOARD_DIR"

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to cleanup background processes
cleanup() {
    echo ""
    echo "🛑 Stopping dashboard servers..."
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null
        echo "   ✅ Backend stopped"
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null
        echo "   ✅ Frontend stopped"
    fi
    echo "👋 Dashboard stopped!"
    exit 0
}

# Trap Ctrl+C to cleanup properly
trap cleanup INT TERM

# Check if dashboard directory exists
if [ ! -d "$DASHBOARD_DIR" ]; then
    echo "❌ Error: Dashboard directory not found at $DASHBOARD_DIR"
    exit 1
fi

# Check if required directories exist
if [ ! -d "$DASHBOARD_DIR/backend" ] || [ ! -d "$DASHBOARD_DIR/frontend" ]; then
    echo "❌ Error: Backend or frontend directory not found"
    echo "   Make sure you're running this from the dashboard project root"
    exit 1
fi

# Check for port conflicts
if check_port 8000; then
    echo "⚠️  Warning: Port 8000 is already in use (backend)"
    echo "   Kill the process using port 8000 or the dashboard may not work properly"
fi

if check_port 3000; then
    echo "⚠️  Warning: Port 3000 is already in use (frontend)"
    echo "   Kill the process using port 3000 or the dashboard may not work properly"
fi

# Change to dashboard directory
cd "$DASHBOARD_DIR"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    echo "📥 Installing Python dependencies..."
    pip install fastapi uvicorn[standard] python-multipart websockets watchdog python-dotenv aiofiles
else
    source venv/bin/activate
fi

# Check if frontend dependencies are installed
if [ ! -d "frontend/node_modules" ]; then
    echo "📦 Installing frontend dependencies..."
    cd frontend
    npm install
    cd ..
fi

echo ""
echo "🔧 Starting backend server..."
cd backend
python main.py &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo "⏳ Waiting for backend to initialize..."
sleep 3

# Check if backend started successfully
if ! check_port 8000; then
    echo "❌ Error: Backend failed to start on port 8000"
    cleanup
    exit 1
fi

echo "✅ Backend started successfully"
echo ""
echo "🎨 Starting frontend server..."
cd frontend
npm run dev &
FRONTEND_PID=$!
cd ..

# Wait for frontend to start
echo "⏳ Waiting for frontend to initialize..."
sleep 5

# Check if frontend started successfully
if ! check_port 3000; then
    echo "❌ Error: Frontend failed to start on port 3000"
    cleanup
    exit 1
fi

echo ""
echo "🎉 Dashboard started successfully!"
echo ""
echo "📊 Frontend:  http://localhost:3000"
echo "🔧 Backend:   http://localhost:8000"
echo "📖 API Docs:  http://localhost:8000/docs"
echo ""
echo "💡 The dashboard will automatically scan for training runs in your ML projects"
echo "🔄 Click 'Refresh' in the dashboard to update the runs list"
echo ""
echo "⌨️  Press Ctrl+C to stop the dashboard"
echo ""

# Try to open the dashboard in the default browser (optional)
if command -v xdg-open > /dev/null 2>&1; then
    echo "🌐 Opening dashboard in your default browser..."
    xdg-open http://localhost:3000 >/dev/null 2>&1 &
elif command -v open > /dev/null 2>&1; then
    echo "🌐 Opening dashboard in your default browser..."
    open http://localhost:3000 >/dev/null 2>&1 &
fi

# Keep the script running and wait for both processes
wait