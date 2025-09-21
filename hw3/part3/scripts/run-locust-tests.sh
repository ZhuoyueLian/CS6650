#!/bin/bash

echo "Locust Load Testing Setup"
echo "========================="

# Check if Go server is running
echo "1. First, start your Go server in another terminal:"
echo "   cd to your server directory"
echo "   go run main.go"
echo "   (Server should be running on http://localhost:8080)"
echo

read -p "Press Enter when your Go server is running..."

# Check if server is accessible
echo "2. Testing server connectivity..."
if curl -s http://localhost:8080/albums > /dev/null; then
    echo "✅ Server is running and accessible"
else
    echo "❌ Server not accessible at http://localhost:8080/albums"
    echo "Make sure your Go server is running first!"
    exit 1
fi

echo
echo "3. Choose your testing method:"
echo "   a) Direct Locust (simple)"
echo "   b) Docker Compose (distributed)"
echo

read -p "Enter choice (a/b): " choice

if [ "$choice" = "a" ]; then
    echo "Starting Locust directly..."
    echo "Open http://localhost:8089 in your browser for the UI"
    locust -f locustfile.py --host=http://localhost:8080
    
elif [ "$choice" = "b" ]; then
    echo "Starting Locust with Docker Compose..."
    echo "This will start 1 master + 4 workers"
    echo "Open http://localhost:8089 in your browser for the UI"
    docker-compose up
    
else
    echo "Invalid choice. Run the script again."
    exit 1
fi