#!/bin/bash

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

API_KEY_DESCRIPTION="Telegraf_${DOCKER_INFLUXDB_INIT_BUCKET}"
TELEGRAF_API_KEY=$(influx auth create \
  --description "$API_KEY_DESCRIPTION" \
  --org "$DOCKER_INFLUXDB_INIT_ORG" \
  --read-telegrafs \
  --write-bucket "$BUCKET_ID" | grep "$API_KEY_DESCRIPTION" | awk '{print $3}')
  

echo -e "                                                                                "
echo -e "                                                                                "
echo -e "                                                                                "
echo -e "                                   .=-:.                                        "
echo -e "                                   .====--:.                                    "
echo -e "                                   .========-:.                                 "
echo -e "                           .:..    .============-:.                             "
echo -e "                           .::::.. .===============--                           "
echo -e "                           .::::::::::-==============.                          "
echo -e "                           .::::::::   .--===========.                          "
echo -e "                           .::::::::       :-========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::        -========.                          "
echo -e "                           .::::::::.       -========.                          "
echo -e "                           .::::::::::..    -========.                          "
echo -e "                           .::::::::::::::..-========.                          "
echo -e "                            .:::::::::::::::..--=====.                          "
echo -e "                               ..:::::::::::.    .--=.                          "
echo -e "                                  ...:::::::.       .                           "
echo -e "                                      ..::::.                                   "
echo -e "                                          ...                                   "
echo -e "                                                                                "
echo -e "                                                                                "
echo -e "                                                                                "

if [ -f /etc/telegraf/docker-envfile.txt ]; then

  echo "The file /etc/telegraf/docker-envfile.txt exists."
  echo "Updating the file with the generated API keys..."
  
  cp /etc/telegraf/docker-envfile.txt /etc/telegraf/docker-envfile.txt.tmp
  sed -i "s/^GRAFANA_INFLUX_API_KEY=.*/GRAFANA_INFLUX_API_KEY=$GRAFANA_API_KEY/" /etc/telegraf/docker-envfile.txt.tmp
  sed -i "s/^TELEGRAF_INFLUX_API_KEY=.*/TELEGRAF_INFLUX_API_KEY=$TELEGRAF_API_KEY/" /etc/telegraf/docker-envfile.txt.tmp
  cp -f /etc/telegraf/docker-envfile.txt.tmp /etc/telegraf/docker-envfile.txt

else
  echo "The file /etc/telegraf/docker-envfile.txt does not exist."
  echo -e "                                                                                "
  echo -e "\nGenerated API Keys:"
  echo -e "+----------------------+------------------------------------------------------+"
  echo -e "| Description          | API Keys                                             |"
  echo -e "+----------------------+------------------------------------------------------+"
  echo -e "| Grafana - Read       | $GRAFANA_API_KEY"
  echo -e "+----------------------+------------------------------------------------------+"
  echo -e "| Telegraf - Write     | $TELEGRAF_API_KEY"
  echo -e "+----------------------+------------------------------------------------------+"
  echo -e "| Instructions         | Copy the generated keys to your .env file.           |"
  echo -e "|                      | Set the following variables:                         |"
  echo -e "|                      |                                                      |"
  echo -e "|                      | GRAFANA_INFLUX_API_KEY=$GRAFANA_API_KEY"
  echo -e "|                      | TELEGRAF_INFLUX_API_KEY=$TELEGRAF_API_KEY"
  echo -e "+----------------------+------------------------------------------------------+"
fi

exit 0