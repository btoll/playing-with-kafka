#!/bin/bash

set -e

echo "Waiting for Kafka brokers to be ready..."
until kafka-broker-api-versions --bootstrap-server kafka-1:9092 2>/dev/null
do
    printf "Brokers not ready yet, retrying..."
    sleep 2
done

printf "Brokers are ready. Creating topics..."

TOPICS=(
    link-scanner-results
    weather-results
)

for topic in "${TOPICS[@]}"
do
    kafka-topics \
        --create \
        --topic "$topic" \
        --bootstrap-server kafka-1:9092,kafka-2:9092,kafka-3:9092 \
        --partitions 3 \
        --replication-factor 3 \
        --if-not-exists

    printf "Created topic \`%s\`." "$topic"
done

