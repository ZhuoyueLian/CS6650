#!/usr/bin/env python3
"""
Combine MySQL and DynamoDB test results for analysis
"""

import json

# Load both result files
with open('test-results/mysql_test_results.json', 'r') as f:
    mysql_results = json.load(f)

with open('test-results/dynamodb_test_results.json', 'r') as f:
    dynamodb_results = json.load(f)

# Add database identifier to each result
for result in mysql_results:
    result['database'] = 'mysql'

for result in dynamodb_results:
    result['database'] = 'dynamodb'

# Combine results
combined_results = {
    'mysql': mysql_results,
    'dynamodb': dynamodb_results,
    'metadata': {
        'mysql_operations': len(mysql_results),
        'dynamodb_operations': len(dynamodb_results),
        'total_operations': len(mysql_results) + len(dynamodb_results)
    }
}

# Save combined results
with open('test-results/combined_results.json', 'w') as f:
    json.dump(combined_results, f, indent=2)

print("✓ Combined results created: test-results/combined_results.json")
print(f"  MySQL operations: {len(mysql_results)}")
print(f"  DynamoDB operations: {len(dynamodb_results)}")
print(f"  Total operations: {len(mysql_results) + len(dynamodb_results)}")
