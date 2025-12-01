#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp1_dlq/aws
DLQ_URL="https://sqs.us-west-2.amazonaws.com/662921601207/order-pipeline-dlq"

echo "=== Monitoring AWS DLQ Messages ===" | tee $RESULTS_DIR/dlq_checks.txt
echo "Monitoring started at: $(date)" | tee -a $RESULTS_DIR/dlq_checks.txt
echo "" | tee -a $RESULTS_DIR/dlq_checks.txt

# Check at 15 seconds
echo "Waiting 15 seconds..." | tee -a $RESULTS_DIR/dlq_checks.txt
sleep 15
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Check at 15 seconds:" | tee -a $RESULTS_DIR/dlq_checks.txt
aws sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names ApproximateNumberOfMessages \
  --region us-west-2 | tee -a $RESULTS_DIR/dlq_checks.txt
echo "" | tee -a $RESULTS_DIR/dlq_checks.txt

# Check at 30 seconds
echo "Waiting another 15 seconds (total 30)..." | tee -a $RESULTS_DIR/dlq_checks.txt
sleep 15
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Check at 30 seconds:" | tee -a $RESULTS_DIR/dlq_checks.txt
aws sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names ApproximateNumberOfMessages \
  --region us-west-2 | tee -a $RESULTS_DIR/dlq_checks.txt
echo "" | tee -a $RESULTS_DIR/dlq_checks.txt

# Final check at 45 seconds
echo "Waiting another 15 seconds (total 45)..." | tee -a $RESULTS_DIR/dlq_checks.txt
sleep 15
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Final check at 45 seconds:" | tee -a $RESULTS_DIR/dlq_checks.txt
aws sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names ApproximateNumberOfMessages \
  --region us-west-2 | tee -a $RESULTS_DIR/dlq_checks.txt

echo "" | tee -a $RESULTS_DIR/dlq_checks.txt
echo "Monitoring complete at: $(date)" | tee -a $RESULTS_DIR/dlq_checks.txt
