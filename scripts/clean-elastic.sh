#!/bin/bash

# Exit on any error
set -e

# Function to exit with an error message
function exit_with_error {
    echo "$1"
    exit 1
}

# Check if required parameters are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    exit_with_error "Usage: $0 <elastic_prefix> <elastic_host> <elastic_username> <elastic_password>"
fi

ELASTIC_PREFIX="$1"
ELASTIC_HOST="$2"
ELASTIC_USERNAME="$3"
ELASTIC_PASSWORD="$4"

echo "Deleting elastic indexes for env: '$ELASTIC_PREFIX'"
echo "Elastic host: $ELASTIC_HOST"
echo "Elastic username: $ELASTIC_USERNAME"
# Password masked for security

# Build the URL for the DELETE request
URL="${ELASTIC_HOST}/${ELASTIC_PREFIX}*"

# Create basic auth header
AUTH_HEADER=$(echo -n "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" | base64)

# Make the REST call to delete indices
echo "Deleting elastic indices with prefix: $ELASTIC_PREFIX"
curl -X DELETE "$URL" \
    -H "Authorization: Basic $AUTH_HEADER" \
    -H "Content-Type: application/json" \
    --fail --silent --show-error || exit_with_error "Failed to delete elastic indices"

echo "Successfully deleted elastic indices with prefix: $ELASTIC_PREFIX"
