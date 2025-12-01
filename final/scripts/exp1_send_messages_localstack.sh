#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp1_dlq/localstack

echo "=== Experiment 1: Sending 5 messages with 100% failure rate ===" | tee $RESULTS_DIR/send_log.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/send_log.txt
echo "" | tee -a $RESULTS_DIR/send_log.txt

for i in {1..5}; do
  TIMESTAMP=$(date +%s)
  TIME_READABLE=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$TIME_READABLE] [$TIMESTAMP] Sending message $i" | tee -a $RESULTS_DIR/send_log.txt
  
  RESPONSE=$(curl -s -X POST http://localhost:8080/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}")
  
  echo "Response: $RESPONSE" | tee -a $RESULTS_DIR/send_log.txt
  echo "" | tee -a $RESULTS_DIR/send_log.txt
done

echo "All messages sent: $(date)" | tee -a $RESULTS_DIR/send_log.txt
