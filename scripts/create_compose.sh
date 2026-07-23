#!/bin/bash

set -euo pipefail

LANG=C
umask 0022

usage() {
    printf "Usage: %s --id 1 --port 1992 [--dry-run]\n\n" "$0"
    printf "Args:\n"
    printf -- "--id        : The ID of the first broker.\n"
    printf "              Every broker will increment by 1.\n"
    printf -- "--num       : The number of brokers.\n"
    printf -- "-p, --port  : The common port of the brokers.\n"
    printf "              The ports will start at this number and increase by 1.\n"
    printf -- "-h, --help  : Show usage.\n"
    exit "$1"
}

while [ "$#" -gt 0 ]
do
    OPT="$1"
    case $OPT in
        --id) shift; ID=$1 ;;
        --num) shift; NUM_BROKERS=$1 ;;
        -p|--port) shift; PORT=$1 ;;
        -h|--help) usage 0 ;;
        *) printf "Unknown flag %s\n" "$OPT"; usage 1 ;;
    esac
    shift
done

top=$(cat <<EOF
version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.6.0
    container_name: zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
EOF
)
echo "$top"

# https://www.shellcheck.net/wiki/SC2051
for ((n=ID; n < (ID+NUM_BROKERS); n++))
do
host_port=$((PORT+n))
broker=$(cat <<EOF

  kafka-$n:
    image: confluentinc/cp-kafka:7.6.0
    container_name: kafka-$n
    depends_on:
      - zookeeper
    ports:
      - "$host_port:$host_port"
    environment:
      KAFKA_BROKER_ID: $n
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181

      # Internal Docker network listener + external host listener
      KAFKA_LISTENERS: PLAINTEXT://:$PORT,PLAINTEXT_HOST://:$host_port
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-$n:$PORT,PLAINTEXT_HOST://localhost:$host_port
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT

      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_LOG_RETENTION_HOURS: 1
      KAFKA_LOG_SEGMENT_BYTES: 1073741824
    healthcheck:
      test: ["CMD-SHELL", "kafka-broker-api-versions --bootstrap-server localhost:$PORT"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
EOF
)
echo "$broker"
done

bottom=$(cat <<EOF

  kafka-init:
    image: confluentinc/cp-kafka:7.6.0
    depends_on:
      kafka-1:
        condition: service_healthy
      kafka-2:
        condition: service_healthy
      kafka-3:
        condition: service_healthy
    entrypoint: /init_topics.sh
    volumes:
      - ./scripts/init_topics.sh:/init_topics.sh
EOF
)
echo "$bottom"
