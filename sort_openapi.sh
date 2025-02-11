#!/bin/bash
# Bash script to sort the endpoint (and method) paths in an OpenAPI spec file
# Dependencies: yq
# Syntax: ./sort_openapi.sh <input_file.yaml> <output_file.yaml>

# Exit on error
set -e

sort_path_yq() {
    local file=$1
    local key_to_order=$2

    # Get keys and sort them
    sorted_keys=$(yq eval "$key_to_order | keys" openapi.yaml |
            cut -c 3- |
            sort)

    # Keep backup of old keys
    local tmp_file="$file.tmp"
    cp -r $file $tmp_file
    
    # Remove keys part from file
    yq eval "del($key_to_order)" -i $file

    # Add sorted keys to file
    for key in $sorted_keys; do
        value=$(yq eval "$key_to_order[\"$key\"]" -o json $tmp_file)
        yq eval "$2 += {\"$key\": $value}" -i $1
    done

    rm $tmp_file
}

process_yq() {
    local input_file=$1
    local output_file=$2

    cp $input_file $output_file

    sort_path_yq $output_file ".paths"

    local keys=$(yq eval ".paths | keys" openapi.yaml | cut -c 3-)
    for key in $keys; do
        sort_path_yq $output_file ".paths[\"$key\"]"
    done
}

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 input_file output_file"
    exit 1
fi

input_file="$1"
output_file="$2"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file not found!"
    exit 1
fi

# Check if input file is valid
if ! yq $input_file > /dev/null; then
    echo "Invalid input file"
    exit 1
fi

# Check if output file already exists
if [ -f "$output_file" ]; then
    echo -n "Output file already exists. Do you want to override ? [yN] "
    read -r response
    if [[ ! "${response,,}" =~ ^yes$|^y$ ]]; then
        echo "Exiting"
        exit 1
    fi
fi

# process the OpenAPI file
process_yq $input_file $output_file

echo "Processing complete. Output written to file '$output_file'"
