#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp3_ordering/aws
ALB_URL="http://order-service-alb-383094491.us-west-2.elb.amazonaws.com"

echo "=== AWS Experiment 3: Sending 50 sequential messages ===" | tee $RESULTS_DIR/send_log.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/send_log.txt
echo "" | tee -a $RESULTS_DIR/send_log.txt
echo "Send Order:" | tee -a $RESULTS_DIR/send_log.txt

for i in {1..50}; do
  echo "$i" | tee -a $RESULTS_DIR/send_log.txt
  curl -s -X POST $ALB_URL/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" > /dev/null
  sleep 0.1
done

echo "" | tee -a $RESULTS_DIR/send_log.txt
echo "All messages sent: $(date)" | tee -a $RESULTS_DIR/send_log.txt
