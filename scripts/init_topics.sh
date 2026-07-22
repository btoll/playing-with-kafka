#!/bin/bash

set -e

echo "Waiting for Kafka brokers to be ready..."
until kafka-broker-api-versions --bootstrap-server kafka-1:9092 2>/dev/null
do
    echo "Brokers not ready yet, retrying..."
    sleep 2
done

echo "Brokers are ready. Creating topics..."

kafka-topics \
    --create \
    --topic link-scanner-results \
    --bootstrap-server kafka-1:9092,kafka-2:9092,kafka-3:9092 \
    --partitions 3 \
    --replication-factor 3 \
    --if-not-exists

kafka-topics \
    --create \
    --topic weather-results \
    --bootstrap-server kafka-1:9092,kafka-2:9092,kafka-3:9092 \
    --partitions 3 \
    --replication-factor 3 \
    --if-not-exists

echo "Topic creation complete."

