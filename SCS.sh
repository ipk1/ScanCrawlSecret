#!/bin/bash

# Create output directory
mkdir output
touch output/unique_subdomains.txt
touch output/live_domains.txt
touch output/nuclei_results.txt
touch output/ffuf_results.txt
touch output/unique_urls_with_params.txt
touch output/js_files.txt

# Read domain input
read -p "Enter domain: " DOMAIN

# Enumerate subdomains
./tools/subfinder -d $DOMAIN -o output/subfinder_results.txt
./tools/amass enum -d $DOMAIN -o output/amass_results.txt
./tools/chaos -d $DOMAIN -o output/chaos_results.txt
cat output/subfinder_results.txt output/amass_results.txt output/chaos_results.txt | sort -u > output/unique_subdomains.txt

# Find live domains
cat output/unique_subdomains.txt | ./tools/httpx -o output/live_domains.txt

# Run nuclei with high and critical templates
./tools/nuclei -l output/live_domains.txt -t ~/nuclei-templates/ -severity high,critical -o output/nuclei_results.txt

# Run ffuf
while read -r DOMAIN; do
  ./tools/ffuf -u "http://$DOMAIN/FUZZ" -w ~/wordlists/ -o output/ffuf_$DOMAIN.txt
done < output/live_domains.txt

# Run Katana
./tools/Katana/katana.py -l output/live_domains.txt -oJ output/js_files.txt -oP output/unique_urls_with_params.txt

# Run SecretFinder and TruffleHog on JS files
mkdir output/secretfinder_results
mkdir output/trufflehog_results

while read -r JS_FILE; do
  SECRET_FINDER_OUTPUT="output/secretfinder_results/$(basename "$JS_FILE").txt"
  TRUFFLEHOG_OUTPUT="output/trufflehog_results/$(basename "$JS_FILE").txt"

  ./tools/SecretFinder/SecretFinder.py -i "$JS_FILE" -o cli > "$SECRET_FINDER_OUTPUT"
  truffleHog --regex --entropy=False "$JS_FILE" --output_path "$TRUFFLEHOG_OUTPUT"
done < output/js_files.txt


