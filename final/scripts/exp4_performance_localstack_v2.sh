#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp4_performance

echo "=== LocalStack Performance Test (Improved) ===" | tee $RESULTS_DIR/localstack_results_v2.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "" | tee -a $RESULTS_DIR/localstack_results_v2.txt

# Test 1: HTTP Response Time (100 samples for better statistics)
echo "Test 1: HTTP Response Time (100 samples)" | tee -a $RESULTS_DIR/localstack_results_v2.txt

# Use curl timing to measure more precisely
TIMES_FILE=$(mktemp)
for i in {1..100}; do
  curl -w "%{time_total}\n" -o /dev/null -s -X POST http://localhost:8080/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" >> $TIMES_FILE
done

# Calculate statistics
AVG=$(awk '{sum+=$1; count++} END {printf "%.3f", sum/count}' $TIMES_FILE)
MIN=$(sort -n $TIMES_FILE | head -1)
MAX=$(sort -n $TIMES_FILE | tail -1)
MEDIAN=$(sort -n $TIMES_FILE | awk '{a[NR]=$1} END {print (NR%2==1)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2}')

echo "  Samples: 100" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "  Average: ${AVG}s ($(echo "$AVG * 1000" | bc)ms)" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "  Median: ${MEDIAN}s ($(echo "$MEDIAN * 1000" | bc)ms)" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "  Min: ${MIN}s ($(echo "$MIN * 1000" | bc)ms)" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "  Max: ${MAX}s ($(echo "$MAX * 1000" | bc)ms)" | tee -a $RESULTS_DIR/localstack_results_v2.txt
rm $TIMES_FILE
echo "" | tee -a $RESULTS_DIR/localstack_results_v2.txt

# Test 2: Throughput under load (200 messages)
echo "Test 2: Sustained Throughput (200 messages)" | tee -a $RESULTS_DIR/localstack_results_v2.txt
START=$(date +%s.%N)
for i in {1..200}; do
  curl -s -X POST http://localhost:8080/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\: 10.0}]}" > /dev/null &
  
  # Batch in groups of 50 to avoid overwhelming
  if [ $((i % 50)) -eq 0 ]; then
    wait
  fi
done
wait
END=$(date +%s.%N)
DURATION=$(echo "$END - $START" | bc)
THROUGHPUT=$(echo "scale=2; 200 / $DURATION" | bc)

echo "  Messages: 200" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "  Duration: ${DURATION}s" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "  Throughput: ${THROUGHPUT} msg/sec" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "" | tee -a $RESULTS_DIR/localstack_results_v2.txt

# Wait for processing
echo "Waiting 60 seconds for processing..." | tee -a $RESULTS_DIR/localstack_results_v2.txt
sleep 60

# Final metrics
echo "=== Final Metrics ===" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "Order Service:" | tee -a $RESULTS_DIR/localstack_results_v2.txt
curl -s http://localhost:8080/metrics | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "Processor Service:" | tee -a $RESULTS_DIR/localstack_results_v2.txt
curl -s http://localhost:8081/metrics | tee -a $RESULTS_DIR/localstack_results_v2.txt

echo "" | tee -a $RESULTS_DIR/localstack_results_v2.txt
echo "Test completed: $(date)" | tee -a $RESULTS_DIR/localstack_results_v2.txt
