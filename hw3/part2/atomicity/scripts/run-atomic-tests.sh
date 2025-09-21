#!/bin/bash

echo "================================================"
echo "ATOMICITY EXPERIMENT - MULTIPLE RUNS"
echo "================================================"

echo
echo "🔬 Running WITHOUT race detection (5 times)..."
echo "------------------------------------------------"
for i in {1..5}; do 
    echo "Run $i:"
    go run atomic-counters.go
    echo
done

echo
echo "🔍 Running WITH race detection (3 times)..."
echo "Note: Race detection adds overhead, so running fewer times"
echo "------------------------------------------------"
for i in {1..3}; do 
    echo "Run $i with race detection:"
    go run -race atomic-counters.go 2>&1 | head -20  # Limit output to avoid spam
    echo
    echo "----------------------------------------"
done