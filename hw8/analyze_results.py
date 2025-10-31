#!/usr/bin/env python3
"""
Analyze and compare MySQL vs DynamoDB performance
"""

import json
import statistics

def load_results(filename):
    with open(filename, 'r') as f:
        return json.load(f)

def calculate_percentile(data, percentile):
    """Calculate percentile from sorted data"""
    if not data:
        return 0
    sorted_data = sorted(data)
    index = (percentile / 100) * len(sorted_data)
    if index.is_integer():
        return sorted_data[int(index) - 1]
    else:
        lower = sorted_data[int(index) - 1]
        upper = sorted_data[int(index)]
        return (lower + upper) / 2

def analyze_database(results, db_name):
    """Analyze performance metrics for a database"""
    
    # Filter by operation type
    operations = {}
    for op_type in ['create_cart', 'add_items', 'get_cart']:
        op_results = [r for r in results if r['operation'] == op_type]
        operations[op_type] = op_results
    
    # Calculate overall statistics
    all_times = [r['response_time'] for r in results]
    success_count = sum(1 for r in results if r['success'])
    
    stats = {
        'database': db_name,
        'total_operations': len(results),
        'successful_operations': success_count,
        'success_rate': (success_count / len(results) * 100) if results else 0,
        'avg_response_time': statistics.mean(all_times) if all_times else 0,
        'median_response_time': statistics.median(all_times) if all_times else 0,
        'p50': calculate_percentile(all_times, 50),
        'p95': calculate_percentile(all_times, 95),
        'p99': calculate_percentile(all_times, 99),
        'min_response_time': min(all_times) if all_times else 0,
        'max_response_time': max(all_times) if all_times else 0,
        'operations': {}
    }
    
    # Per-operation statistics
    for op_type, op_results in operations.items():
        if op_results:
            times = [r['response_time'] for r in op_results]
            successes = sum(1 for r in op_results if r['success'])
            stats['operations'][op_type] = {
                'count': len(op_results),
                'success_count': successes,
                'avg': statistics.mean(times),
                'min': min(times),
                'max': max(times),
                'median': statistics.median(times)
            }
    
    return stats

def main():
    # Load combined results
    with open('test-results/combined_results.json', 'r') as f:
        combined = json.load(f)
    
    mysql_results = combined['mysql']
    dynamodb_results = combined['dynamodb']
    
    # Analyze both databases
    mysql_stats = analyze_database(mysql_results, 'MySQL')
    dynamodb_stats = analyze_database(dynamodb_results, 'DynamoDB')
    
    # Print comparison table
    print("=" * 80)
    print("PERFORMANCE COMPARISON: MySQL vs DynamoDB")
    print("=" * 80)
    
    print("\n" + "=" * 80)
    print("OVERALL METRICS")
    print("=" * 80)
    
    metrics = [
        ('Avg Response Time (ms)', 'avg_response_time'),
        ('P50 Response Time (ms)', 'p50'),
        ('P95 Response Time (ms)', 'p95'),
        ('P99 Response Time (ms)', 'p99'),
        ('Min Response Time (ms)', 'min_response_time'),
        ('Max Response Time (ms)', 'max_response_time'),
        ('Success Rate (%)', 'success_rate'),
        ('Total Operations', 'total_operations'),
    ]
    
    print(f"\n{'Metric':<30} {'MySQL':<15} {'DynamoDB':<15} {'Winner':<15} {'Margin':<15}")
    print("-" * 90)
    
    for metric_name, metric_key in metrics:
        mysql_val = mysql_stats[metric_key]
        dynamodb_val = dynamodb_stats[metric_key]
        
        if metric_key == 'success_rate':
            winner = 'Tie' if mysql_val == dynamodb_val else ('MySQL' if mysql_val > dynamodb_val else 'DynamoDB')
            margin = f"{abs(mysql_val - dynamodb_val):.2f}%"
        elif metric_key == 'total_operations':
            winner = '-'
            margin = '-'
        else:
            winner = 'MySQL' if mysql_val < dynamodb_val else 'DynamoDB'
            if mysql_val > 0:
                margin = f"{abs((dynamodb_val - mysql_val) / mysql_val * 100):.1f}%"
            else:
                margin = "N/A"
        
        print(f"{metric_name:<30} {mysql_val:<15.2f} {dynamodb_val:<15.2f} {winner:<15} {margin:<15}")
    
    # Operation-specific breakdown
    print("\n" + "=" * 80)
    print("OPERATION-SPECIFIC BREAKDOWN")
    print("=" * 80)
    
    for op in ['create_cart', 'add_items', 'get_cart']:
        print(f"\n{op.upper().replace('_', ' ')}:")
        mysql_op = mysql_stats['operations'].get(op, {})
        dynamodb_op = dynamodb_stats['operations'].get(op, {})
        
        print(f"  {'Metric':<20} {'MySQL':<15} {'DynamoDB':<15} {'Faster By':<15}")
        print("  " + "-" * 65)
        
        for metric in ['avg', 'min', 'max']:
            mysql_val = mysql_op.get(metric, 0)
            dynamodb_val = dynamodb_op.get(metric, 0)
            faster = 'MySQL' if mysql_val < dynamodb_val else 'DynamoDB'
            diff = abs(mysql_val - dynamodb_val)
            print(f"  {metric.upper():<20} {mysql_val:<15.2f} {dynamodb_val:<15.2f} {faster} ({diff:.2f}ms)")
    
    print("\n" + "=" * 80)
    
    # Save detailed analysis
    analysis = {
        'mysql': mysql_stats,
        'dynamodb': dynamodb_stats,
        'comparison': {
            'overall_winner': 'DynamoDB' if dynamodb_stats['avg_response_time'] < mysql_stats['avg_response_time'] else 'MySQL',
            'performance_difference_pct': abs((dynamodb_stats['avg_response_time'] - mysql_stats['avg_response_time']) / mysql_stats['avg_response_time'] * 100)
        }
    }
    
    with open('docs/performance_analysis.json', 'w') as f:
        json.dump(analysis, f, indent=2)
    
    print("\n✓ Detailed analysis saved to: docs/performance_analysis.json")

if __name__ == "__main__":
    main()
