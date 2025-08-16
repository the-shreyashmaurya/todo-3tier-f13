#!/bin/bash

# Script to update frontend API URL for EC2 deployment
# Usage: ./update-api-url.sh <EC2_PUBLIC_IP>

# if [ $# -eq 0 ]; then
#     echo "Usage: $0 <EC2_PUBLIC_IP>"
#     echo "Example: $0 3.110.45.123"
#     exit 1
# fi

API_URL="http://13.234.213.233:5000/api"

echo "Updating frontend API URL to: $API_URL"

# Update the main.dart file
sed -i "s|baseUrl: 'http://[^']*'|baseUrl: '$API_URL'|g" frontend/lib/main.dart

echo "API URL updated successfully!"
echo "Now build the frontend with: cd frontend && flutter build web --release"
