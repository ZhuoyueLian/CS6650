#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp3_ordering/localstack

echo "=== High Volume Test: 200 messages in parallel ===" | tee $RESULTS_DIR/high_volume_test.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/high_volume_test.txt
echo "" | tee -a $RESULTS_DIR/high_volume_test.txt

# Send 200 messages simultaneously (no delays)
echo "Sending 200 messages in parallel..." | tee -a $RESULTS_DIR/high_volume_test.txt
for i in {1..200}; do
  curl -s -X POST http://localhost:8080/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" > /dev/null &
done
wait

echo "All 200 messages sent: $(date)" | tee -a $RESULTS_DIR/high_volume_test.txt
echo "Waiting 90 seconds for processing..." | tee -a $RESULTS_DIR/high_volume_test.txt
sleep 90

echo "Messages sent: 200" | tee -a $RESULTS_DIR/high_volume_test.txt
