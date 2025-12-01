#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp2_fanout/localstack

echo "=== Stress Test: 500 messages ===" | tee $RESULTS_DIR/stress_test.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/stress_test.txt

for i in {1..500}; do
  curl -s -X POST http://localhost:8080/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" > /dev/null &
done
wait

echo "500 messages sent: $(date)" | tee -a $RESULTS_DIR/stress_test.txt
echo "Waiting 2 minutes for processing..." | tee -a $RESULTS_DIR/stress_test.txt
sleep 120

# Check metrics
echo "=== Final Metrics ===" | tee -a $RESULTS_DIR/stress_test.txt
curl -s http://localhost:8080/metrics | tee -a $RESULTS_DIR/stress_test.txt
echo "" | tee -a $RESULTS_DIR/stress_test.txt
curl -s http://localhost:8081/metrics | tee -a $RESULTS_DIR/stress_test.txt
echo "" | tee -a $RESULTS_DIR/stress_test.txt
curl -s http://localhost:8082/metrics | tee -a $RESULTS_DIR/stress_test.txt

# Check for any losses
echo "" | tee -a $RESULTS_DIR/stress_test.txt
echo "Expected: 500 sent, 500 processed, 500 notifications" | tee -a $RESULTS_DIR/stress_test.txt
