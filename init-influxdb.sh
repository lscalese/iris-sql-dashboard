#!/bin/bash

# This script initializes InfluxDB with the necessary configurations for the IRIS SQL Dashboard.
# It performs the following tasks:
# 1. Retrieves the bucket ID for the specified bucket in the specified organization.
# 2. Creates an API key for Grafana with read access to the specified bucket.
# 3. Creates an API key for IRIS with write access to the specified bucket.
# 4. Creates a Telegraf configuration for the IRIS SQL Stats.
# 5. Creates an API key for Telegraf with read access to Telegraf configurations and write access to the specified bucket.

# Variables:
# - DOCKER_INFLUXDB_INIT_ORG: The organization name in InfluxDB.
# - DOCKER_INFLUXDB_INIT_BUCKET: The bucket name in InfluxDB.
# - API_KEY_DESCRIPTION: Description for the API keys being created.


# Retrieve the bucket ID for the specified bucket in the specified organization
BUCKET_ID=$(influx bucket list -o "$DOCKER_INFLUXDB_INIT_ORG" | grep "$DOCKER_INFLUXDB_INIT_BUCKET" | awk '{print $1}')

API_KEY_DESCRIPTION="Grafana_${DOCKER_INFLUXDB_INIT_BUCKET}"
GRAFANA_API_KEY=$(influx auth create \
  --description "$API_KEY_DESCRIPTION" \
  --org "$DOCKER_INFLUXDB_INIT_ORG" \
  --read-bucket "$BUCKET_ID" | grep "$API_KEY_DESCRIPTION" | awk '{print $3}')

API_KEY_DESCRIPTION="IRIS_${DOCKER_INFLUXDB_INIT_BUCKET}"
IRIS_API_KEY=$(influx auth create \
  --description "$API_KEY_DESCRIPTION" \
  --org "$DOCKER_INFLUXDB_INIT_ORG" \
  --write-bucket "$BUCKET_ID" | grep "$API_KEY_DESCRIPTION" | awk '{print $3}')
  

TELEGRAF_ID=$(influx telegrafs create \
  --name "Telegraf_IRIS-SQL-Stats" \
  --description "Configuration for Telegraf Agent to request IRIS" \
  --org ${DOCKER_INFLUXDB_INIT_ORG} \
  --file /etc/telegraf/telegraf.conf)

API_KEY_DESCRIPTION="Telegraf_${DOCKER_INFLUXDB_INIT_BUCKET}"
TELEGRAF_API_KEY=$(influx auth create \
  --description "$API_KEY_DESCRIPTION" \
  --org "$DOCKER_INFLUXDB_INIT_ORG" \
  --read-telegrafs \
  --write-bucket "$BUCKET_ID" | grep "$API_KEY_DESCRIPTION" | awk '{print $3}')
  

# Print the API keys in an ASCII art table with instructions
echo -e "\nGenerated API Keys:"
echo -e "+----------------------+------------------------------------------------------+"
echo -e "| Description          | API Key                                              |"
echo -e "+----------------------+------------------------------------------------------+"
echo -e "| Grafana - Read       | $GRAFANA_API_KEY"
echo -e "+----------------------+------------------------------------------------------+"
echo -e "| IRIS - Write         | $IRIS_API_KEY"
echo -e "+----------------------+------------------------------------------------------+"
echo -e "| Telegraf - Write     | $TELEGRAF_API_KEY"
echo -e "+----------------------+------------------------------------------------------+"
echo -e "| Instructions         | Copy the generated keys to your .env file.           |"
echo -e "|                      | Set the following variables:                         |"
echo -e "|                      |                                                      |"
echo -e "|                      | GRAFANA_INFLUX_API_KEY=$GRAFANA_API_KEY"
echo -e "|                      | IRIS_INFLUX_API_KEY=$IRIS_API_KEY"
echo -e "|                      | TELEGRAF_INFLUX_API_KEY=$TELEGRAF_API_KEY"
echo -e "+----------------------+------------------------------------------------------+"

exit 0