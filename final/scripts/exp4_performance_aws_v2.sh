#!/bin/bash
RESULTS_DIR=~/git/CS6650/final/results/exp4_performance
ALB_URL="http://order-service-alb-383094491.us-west-2.elb.amazonaws.com"

echo "=== AWS Performance Test (Improved) ===" | tee $RESULTS_DIR/aws_results_v2.txt
echo "Start time: $(date)" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "" | tee -a $RESULTS_DIR/aws_results_v2.txt

# Test 1: HTTP Response Time (100 samples)
echo "Test 1: HTTP Response Time (100 samples)" | tee -a $RESULTS_DIR/aws_results_v2.txt

TIMES_FILE=$(mktemp)
for i in {1..100}; do
  curl -w "%{time_total}\n" -o /dev/null -s -X POST $ALB_URL/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" >> $TIMES_FILE
done

# Calculate statistics
AVG=$(awk '{sum+=$1; count++} END {printf "%.3f", sum/count}' $TIMES_FILE)
MIN=$(sort -n $TIMES_FILE | head -1)
MAX=$(sort -n $TIMES_FILE | tail -1)
MEDIAN=$(sort -n $TIMES_FILE | awk '{a[NR]=$1} END {print (NR%2==1)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2}')

echo "  Samples: 100" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "  Average: ${AVG}s ($(echo "$AVG * 1000" | bc)ms)" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "  Median: ${MEDIAN}s ($(echo "$MEDIAN * 1000" | bc)ms)" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "  Min: ${MIN}s ($(echo "$MIN * 1000" | bc)ms)" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "  Max: ${MAX}s ($(echo "$MAX * 1000" | bc)ms)" | tee -a $RESULTS_DIR/aws_results_v2.txt
rm $TIMES_FILE
echo "" | tee -a $RESULTS_DIR/aws_results_v2.txt

# Test 2: Throughput (200 messages)
echo "Test 2: Sustained Throughput (200 messages)" | tee -a $RESULTS_DIR/aws_results_v2.txt
START=$(date +%s.%N)
for i in {1..200}; do
  curl -s -X POST $ALB_URL/orders \
    -H "Content-Type: application/json" \
    -d "{\"customer_id\": $i, \"items\": [{\"product_id\": 1, \"quantity\": 1, \"price\": 10.0}]}" > /dev/null &
  
  if [ $((i % 50)) -eq 0 ]; then
    wait
  fi
done
wait
END=$(date +%s.%N)
DURATION=$(echo "$END - $START" | bc)
THROUGHPUT=$(echo "scale=2; 200 / $DURATION" | bc)

echo "  Messages: 200" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "  Duration: ${DURATION}s" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "  Throughput: ${THROUGHPUT} msg/sec" | tee -a $RESULTS_DIR/aws_results_v2.txt

echo "" | tee -a $RESULTS_DIR/aws_results_v2.txt
echo "Test completed: $(date)" | tee -a $RESULTS_DIR/aws_results_v2.txt
