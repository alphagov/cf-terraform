#! /bin/bash

set -e # fail on error

SCRIPT_DIR=$(cd $(dirname $0) && pwd)


# Read the platform configuration
TARGET_PLATFORM=$1
case $TARGET_PLATFORM in
  aws)
    ;;
  gce)
    ;;
  *)
    echo "Must specify the target platform: gce|aws"
    exit 1
    ;;
esac

export BUNDLE_GEMFILE=$SCRIPT_DIR/Gemfile
BOSH_CLI="bundle exec bosh"

# Other config
export PATH=$PATH:/usr/local/bin

# Include the terraform output variables
. $SCRIPT_DIR/terraform-outputs-${TARGET_PLATFORM}.sh

cd ~

# Generate manifest
./generate_docker_manifest.sh $TARGET_PLATFORM > ~/docker-manifest.yml

# Deploy docker-broker
$BOSH_CLI deployment ~/docker-manifest.yml
time $BOSH_CLI -n deploy

# Register broker if any of the services provided is not available in marketpace
services="$(python -c 'import yaml; print "\n".join([s["name"] for s in yaml.load(file("docker-manifest.yml"))["properties"]["broker"]["services"]])'| sort)"
marketplace_services="$(cf m | tail -n+5 | head -n-2 | awk '{print $1}' | sort)"
diff="$(comm -23 <(echo "$services") <(echo "$marketplace_services") | head)"
[[ -n "$diff" ]] && echo "Registering additional services: $diff" && time $BOSH_CLI -n run errand broker-registrar

# Cofigure security
DOCKER_IP=$(/usr/local/bin/bosh vms 2>&1 | awk  '$2 ~ /docker-broker\/0/ {print $8}')
echo '[{"protocol":"tcp","destination":"'$DOCKER_IP'","ports":"1-65535"}]' > docker-sec-group.json
cf create-security-group docker-security-group docker-sec-group.json
cf bind-staging-security-group docker-security-group
cf bind-running-security-group docker-security-group
