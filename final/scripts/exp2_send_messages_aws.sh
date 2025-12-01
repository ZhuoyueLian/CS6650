#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp2_fanout/aws
ALB_URL="http://order-service-alb-2050017386.us-west-2.elb.amazonaws.com"

echo "=== AWS Experiment 2: Sending 100 messages to test SNS fan-out ===" | tee $RESULTS_DIR/send_log.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/send_log.txt
echo "" | tee -a $RESULTS_DIR/send_log.txt

for i in {1..100}; do
  curl -s -X POST $ALB_URL/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" &
done
wait

echo "" | tee -a $RESULTS_DIR/send_log.txt
echo "All 100 messages sent: $(date)" | tee -a $RESULTS_DIR/send_log.txt
