from flask import Flask, request, jsonify
import boto3
import json
import re
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

def clean_and_count_words(text):
    """Clean text and count word occurrences"""
    # Convert to lowercase and remove punctuation
    # Keep only alphabetic characters and spaces
    cleaned_text = re.sub(r'[^a-zA-Z\s]', '', text.lower())
    
    # Split into words and filter out empty strings
    words = [word for word in cleaned_text.split() if word]
    
    # Count word occurrences
    word_counts = Counter(words)
    
    return dict(word_counts)

@app.route('/')
def health_check():
    return jsonify({"status": "Mapper service is running"})

@app.route('/map')
def map_chunk():
    try:
        # Get chunk URL from query string
        chunk_url = request.args.get('chunk_url')
        
        if not chunk_url:
            return jsonify({"error": "chunk_url parameter is required"}), 400
        
        # Parse S3 URL
        chunk_bucket, chunk_key = parse_s3_url(chunk_url)
        
        # Download chunk from S3
        print(f"Downloading chunk: {chunk_key} from bucket: {chunk_bucket}")
        response = s3_client.get_object(Bucket=chunk_bucket, Key=chunk_key)
        chunk_text = response['Body'].read().decode('utf-8')
        
        print(f"Processing chunk with {len(chunk_text)} characters")
        
        # Count words in the chunk
        word_counts = clean_and_count_words(chunk_text)
        
        # Generate output file name based on input chunk
        chunk_name = chunk_key.split('/')[-1].replace('.txt', '')
        output_key = f"results/{chunk_name}_wordcount.json"
        
        # Save results to S3
        result_data = {
            "chunk_processed": chunk_url,
            "word_count": len(word_counts),
            "total_words": sum(word_counts.values()),
            "word_counts": word_counts
        }
        
        print(f"Saving results to: {output_key}")
        s3_client.put_object(
            Bucket=chunk_bucket,
            Key=output_key,
            Body=json.dumps(result_data, indent=2),
            ContentType='application/json'
        )
        
        output_url = f"s3://{chunk_bucket}/{output_key}"
        
        result = {
            "message": "Chunk processed successfully",
            "chunk_processed": chunk_url,
            "unique_words": len(word_counts),
            "total_words": sum(word_counts.values()),
            "result_url": output_url
        }
        
        print(f"Mapper completed successfully: {len(word_counts)} unique words")
        return jsonify(result)
        
    except Exception as e:
        error_msg = f"Error in mapper service: {str(e)}"
        print(error_msg)
        return jsonify({"error": error_msg}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)