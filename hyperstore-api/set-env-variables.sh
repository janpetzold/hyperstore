#!/bin/bash

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

# Read .env file line by line
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ $line == \#* ]]; then
        continue
    fi

    # Remove any trailing comments
    line=$(echo "$line" | cut -d '#' -f 1)

    # Export the variable
    export "$line"
    
    # Optional: Print the exported variable (commented out by default)
    # echo "Exported: $line"
done < .env

echo "Environment variables loaded successfully"