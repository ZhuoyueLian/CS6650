#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp4_performance

echo "=== LocalStack Performance Test ===" | tee $RESULTS_DIR/localstack_results.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/localstack_results.txt
echo "" | tee -a $RESULTS_DIR/localstack_results.txt

# Test 1: Single message latency (10 samples)
echo "Test 1: Single Message Latency (10 samples)" | tee -a $RESULTS_DIR/localstack_results.txt
LATENCIES=()
for i in {1..10}; do
  START=$(date +%s%N)
  curl -s -X POST http://localhost:8080/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" > /dev/null
  END=$(date +%s%N)
  LATENCY=$(( (END - START) / 1000000 ))  # Convert to milliseconds
  LATENCIES+=($LATENCY)
  echo "  Sample $i: ${LATENCY}ms" | tee -a $RESULTS_DIR/localstack_results.txt
  sleep 0.5
done

# Calculate average
TOTAL=0
for lat in "${LATENCIES[@]}"; do
  TOTAL=$((TOTAL + lat))
done
AVG=$((TOTAL / 10))
echo "Average latency: ${AVG}ms" | tee -a $RESULTS_DIR/localstack_results.txt
echo "" | tee -a $RESULTS_DIR/localstack_results.txt

# Test 2: Burst throughput (50 messages)
echo "Test 2: Burst Throughput (50 messages)" | tee -a $RESULTS_DIR/localstack_results.txt
START=$(date +%s)
for i in {1..50}; do
  curl -s -X POST http://localhost:8080/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" > /dev/null &
done
wait
END=$(date +%s)
DURATION=$((END - START))
THROUGHPUT=$(echo "scale=2; 50 / $DURATION" | bc)

echo "Time to send 50 messages: ${DURATION}s" | tee -a $RESULTS_DIR/localstack_results.txt
echo "Throughput: ${THROUGHPUT} msg/sec" | tee -a $RESULTS_DIR/localstack_results.txt
echo "" | tee -a $RESULTS_DIR/localstack_results.txt

# Wait for processing
echo "Waiting 30 seconds for processing..." | tee -a $RESULTS_DIR/localstack_results.txt
sleep 30

# Check metrics
echo "=== Service Metrics ===" | tee -a $RESULTS_DIR/localstack_results.txt
curl -s http://localhost:8080/metrics | tee -a $RESULTS_DIR/localstack_results.txt
echo "" | tee -a $RESULTS_DIR/localstack_results.txt
curl -s http://localhost:8081/metrics | tee -a $RESULTS_DIR/localstack_results.txt

echo "" | tee -a $RESULTS_DIR/localstack_results.txt
echo "Test completed: $(date)" | tee -a $RESULTS_DIR/localstack_results.txt
