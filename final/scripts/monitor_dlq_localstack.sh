#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp1_dlq/localstack

echo "=== Monitoring DLQ Messages ===" | tee $RESULTS_DIR/dlq_checks.txt
echo "Monitoring started at: $(date)" | tee -a $RESULTS_DIR/dlq_checks.txt
echo "" | tee -a $RESULTS_DIR/dlq_checks.txt

# Check at 15 seconds
echo "Waiting 15 seconds..." | tee -a $RESULTS_DIR/dlq_checks.txt
sleep 15
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Check at 15 seconds:" | tee -a $RESULTS_DIR/dlq_checks.txt
aws --endpoint-url=http://localhost:4566 sqs get-queue-attributes \
  --queue-url http://sqs.us-west-2.localhost.localstack.cloud:4566/000000000000/orders-dlq \
  --attribute-names ApproximateNumberOfMessages \
  --region us-west-2 | tee -a $RESULTS_DIR/dlq_checks.txt
echo "" | tee -a $RESULTS_DIR/dlq_checks.txt

# Check at 30 seconds
echo "Waiting another 15 seconds (total 30)..." | tee -a $RESULTS_DIR/dlq_checks.txt
sleep 15
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Check at 30 seconds:" | tee -a $RESULTS_DIR/dlq_checks.txt
aws --endpoint-url=http://localhost:4566 sqs get-queue-attributes \
  --queue-url http://sqs.us-west-2.localhost.localstack.cloud:4566/000000000000/orders-dlq \
  --attribute-names ApproximateNumberOfMessages \
  --region us-west-2 | tee -a $RESULTS_DIR/dlq_checks.txt
echo "" | tee -a $RESULTS_DIR/dlq_checks.txt

# Final check at 45 seconds
echo "Waiting another 15 seconds (total 45)..." | tee -a $RESULTS_DIR/dlq_checks.txt
sleep 15
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Final check at 45 seconds:" | tee -a $RESULTS_DIR/dlq_checks.txt
aws --endpoint-url=http://localhost:4566 sqs get-queue-attributes \
  --queue-url http://sqs.us-west-2.localhost.localstack.cloud:4566/000000000000/orders-dlq \
  --attribute-names ApproximateNumberOfMessages \
  --region us-west-2 | tee -a $RESULTS_DIR/dlq_checks.txt

echo "" | tee -a $RESULTS_DIR/dlq_checks.txt
echo "Monitoring complete at: $(date)" | tee -a $RESULTS_DIR/dlq_checks.txt
