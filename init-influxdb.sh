# Variables
ORG_NAME=${DOCKER_INFLUXDB_INIT_ORG}
BUCKET_NAME=${DOCKER_INFLUXDB_INIT_BUCKET}
ADMIN_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
API_KEY_DESCRIPTION="Grafana - Read ${BUCKET_NAME}"

# Créer une organisation
# influx org create -n "$ORG_NAME" --host http://localhost:8086 --token "$ADMIN_TOKEN"

# Créer un bucket
# influx bucket create -n "$BUCKET_NAME" -o "$ORG_NAME" --host http://localhost:8086 --token "$ADMIN_TOKEN"

# Créer une API Key avec les permissions sur le bucket
BUCKET_ID=$(influx bucket list -o "$ORG_NAME" --host http://localhost:8086 --token "$ADMIN_TOKEN" | grep "$BUCKET_NAME" | awk '{print $1}')
API_KEY=$(influx auth create \
  --description "$API_KEY_DESCRIPTION" \
  --org "$ORG_NAME" \
  --read-bucket "$BUCKET_ID" \
  --host http://localhost:8086 \
  --token "$ADMIN_TOKEN")

echo "Generated API Key: $API_KEY"

API_KEY_DESCRIPTION="IRIS - Write ${BUCKET_NAME}"

API_KEY=$(influx auth create \
  --description "$API_KEY_DESCRIPTION" \
  --org "$ORG_NAME" \
  --write-bucket "$BUCKET_ID" \
  --host http://localhost:8086 \
  --token "$ADMIN_TOKEN")
  
echo "Generated API Key: $API_KEY"