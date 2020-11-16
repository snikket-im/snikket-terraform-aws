#!/bin/bash

DOMAIN="${tf_domain}"
ESCAPED_DOMAIN=$(echo "$DOMAIN" | lua -e 'print((io.read():gsub("%W", function (c) return ("%%%02x"):format(c:byte())end)))')
EMAIL="${tf_admin_email}"
CONFIG_SECRET="${tf_config_secret}"

if [[ "${tf_import_test_data}" == "true" ]]; then
	install -d "/var/lib/snikket/prosody/$ESCAPED_DOMAIN"
	wget https://prosody.im/files/prosody-test-data.tar.gz
	tar xzf prosody-test-data.tar.gz -C "/var/lib/snikket/prosody/$ESCAPED_DOMAIN"
fi

curl -L "https://github.com/docker/compose/releases/download/1.25.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod a+x /usr/local/bin/docker-compose

mkdir /etc/snikket
cd /etc/snikket

tee docker-compose.yml <<EOF
---
version: "3.3"

services:
  snikket:
    container_name: snikket
    image: snikket/snikket:${tf_version}
    env_file: snikket.conf
    restart: unless-stopped
    network_mode: host
    volumes:
      - "/var/lib/snikket:/snikket"
EOF

tee snikket.conf <<EOF

# The primary domain of your Snikket instance
SNIKKET_DOMAIN=${tf_domain}

# An email address where the admin can be contacted
# (also used to register your Let's Encrypt account to obtain certificates)
SNIKKET_ADMIN_EMAIL=${tf_admin_email}

EOF

docker-compose up -d

# Generate invite API key and publish it at the SECRET location
docker exec -t snikket bash -c "prosodyctl mod_invites_api $DOMAIN create > /var/www/api-key-$CONFIG_SECRET"
