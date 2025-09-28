from flask import Flask, request, jsonify
import boto3
import json
from collections import Counter
from urllib.parse import urlparse

app = Flask(__name__)

# Initialize S3 client
s3_client = boto3.client('s3', region_name='us-west-2')

def parse_s3_url(s3_url):
    """Parse S3 URL to extract bucket and key"""
    parsed = urlparse(s3_url)
    bucket = parsed.netloc
    key = parsed.path.lstrip('/')
    return bucket, key

def download_mapper_result(s3_url):
    """Download and parse a mapper result file from S3"""
    try:
        bucket, key = parse_s3_url(s3_url)
        response = s3_client.get_object(Bucket=bucket, Key=key)
        result_data = json.loads(response['Body'].read().decode('utf-8'))
        return result_data['word_counts']
    except Exception as e:
        print(f"Error downloading {s3_url}: {str(e)}")
        return {}

@app.route('/')
def health_check():
    return jsonify({"status": "Reducer service is running"})

@app.route('/reduce')
def reduce_results():
    try:
        # Get mapper result URLs from query string (comma-separated)
        mapper_urls_param = request.args.get('mapper_urls')
        
        if not mapper_urls_param:
            return jsonify({"error": "mapper_urls parameter is required (comma-separated list)"}), 400
        
        # Split URLs by comma and strip whitespace
        mapper_urls = [url.strip() for url in mapper_urls_param.split(',')]
        
        if len(mapper_urls) == 0:
            return jsonify({"error": "At least one mapper URL is required"}), 400
        
        print(f"Processing {len(mapper_urls)} mapper results")
        
        # Combine word counts from all mappers
        combined_counts = Counter()
        processed_chunks = []
        total_unique_words_per_mapper = []
        total_words_per_mapper = []
        
        for i, mapper_url in enumerate(mapper_urls):
            print(f"Downloading mapper result {i+1}: {mapper_url}")
            word_counts = download_mapper_result(mapper_url)
            
            if word_counts:
                # Add to combined counter
                combined_counts.update(word_counts)
                processed_chunks.append(mapper_url)
                
                # Track stats per mapper
                unique_words = len(word_counts)
                total_words = sum(word_counts.values())
                total_unique_words_per_mapper.append(unique_words)
                total_words_per_mapper.append(total_words)
                
                print(f"Mapper {i+1}: {unique_words} unique words, {total_words} total words")
        
        if not combined_counts:
            return jsonify({"error": "No valid word counts found in mapper results"}), 500
        
        # Convert counter back to regular dict and sort by frequency (descending)
        final_word_counts = dict(combined_counts.most_common())
        
        # Prepare final results
        final_results = {
            "mappers_processed": len(processed_chunks),
            "processed_chunks": processed_chunks,
            "total_unique_words": len(final_word_counts),
            "total_word_occurrences": sum(final_word_counts.values()),
            "mapper_stats": {
                "unique_words_per_mapper": total_unique_words_per_mapper,
                "total_words_per_mapper": total_words_per_mapper
            },
            "top_20_words": dict(list(final_word_counts.items())[:20]),
            "word_counts": final_word_counts
        }
        
        # Get bucket name from first mapper URL
        bucket, _ = parse_s3_url(processed_chunks[0])
        output_key = "final/final_wordcount.json"
        
        # Save final results to S3
        print(f"Saving final results to s3://{bucket}/{output_key}")
        s3_client.put_object(
            Bucket=bucket,
            Key=output_key,
            Body=json.dumps(final_results, indent=2),
            ContentType='application/json'
        )
        
        final_url = f"s3://{bucket}/{output_key}"
        
        # Return summary response (without full word_counts to keep response manageable)
        response_summary = {
            "message": "MapReduce word counting completed successfully!",
            "mappers_processed": len(processed_chunks),
            "total_unique_words": len(final_word_counts),
            "total_word_occurrences": sum(final_word_counts.values()),
            "top_10_words": dict(list(final_word_counts.items())[:10]),
            "final_url": final_url
        }
        
        print(f"Reducer completed successfully: {len(final_word_counts)} unique words")
        return jsonify(response_summary)
        
    except Exception as e:
        error_msg = f"Error in reducer service: {str(e)}"
        print(error_msg)
        return jsonify({"error": error_msg}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)