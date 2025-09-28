from flask import Flask, request, jsonify
import boto3
import os
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

def split_text_into_chunks(text, num_chunks):
    """Split text into roughly equal chunks by character count"""
    if num_chunks <= 0:
        return []
    
    total_length = len(text)
    chunk_size = total_length // num_chunks
    
    chunks = []
    for i in range(num_chunks):
        start_idx = i * chunk_size
        if i == num_chunks - 1:
            # Last chunk gets any remaining characters
            end_idx = total_length
        else:
            end_idx = start_idx + chunk_size
        
        chunk = text[start_idx:end_idx]
        chunks.append(chunk)
    
    return chunks

@app.route('/')
def health_check():
    return jsonify({"status": "Splitter service is running"})

@app.route('/split')
def split_file():
    try:
        # Get parameters from query string
        input_url = request.args.get('input_url')
        chunks = request.args.get('chunks', default=3, type=int)
        
        if not input_url:
            return jsonify({"error": "input_url parameter is required"}), 400
        
        # Parse S3 URL
        input_bucket, input_key = parse_s3_url(input_url)
        
        # Download file from S3
        print(f"Downloading {input_key} from bucket {input_bucket}")
        response = s3_client.get_object(Bucket=input_bucket, Key=input_key)
        text_content = response['Body'].read().decode('utf-8')
        
        print(f"Downloaded file size: {len(text_content)} characters")
        
        # Split text into chunks
        text_chunks = split_text_into_chunks(text_content, chunks)
        
        # Upload chunks to S3 and collect URLs
        chunk_urls = []
        for i, chunk in enumerate(text_chunks):
            chunk_key = f"chunks/chunk_{i+1}.txt"
            
            print(f"Uploading chunk {i+1} with {len(chunk)} characters")
            s3_client.put_object(
                Bucket=input_bucket,
                Key=chunk_key,
                Body=chunk.encode('utf-8'),
                ContentType='text/plain'
            )
            
            chunk_url = f"s3://{input_bucket}/{chunk_key}"
            chunk_urls.append(chunk_url)
        
        result = {
            "message": f"Successfully split file into {len(chunk_urls)} chunks",
            "input_file_size": len(text_content),
            "chunk_urls": chunk_urls
        }
        
        print(f"Splitter completed successfully: {len(chunk_urls)} chunks created")
        return jsonify(result)
        
    except Exception as e:
        error_msg = f"Error in splitter service: {str(e)}"
        print(error_msg)
        return jsonify({"error": error_msg}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)