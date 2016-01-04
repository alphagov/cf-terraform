#!/bin/bash

set -e # fail on error

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

get_cf_secret() { ${SCRIPT_DIR}/val_from_yaml.rb templates/cf-secrets.yml $1; }
get_output() { ${SCRIPT_DIR}/val_from_yaml.rb templates/outputs/terraform-outputs-${TARGET_PLATFORM}.yml $1; }

# Read the platform configuration
TARGET_PLATFORM=$1
case $TARGET_PLATFORM in
  aws)
    STEMCELL=light-bosh-stemcell-3074-aws-xen-hvm-ubuntu-trusty-go_agent.tgz
    ;;
  gce)
    STEMCELL=light-bosh-stemcell-3074-google-kvm-ubuntu-trusty-go_agent.tgz
    STEMCELL_URL=http://storage.googleapis.com/gce-bosh-stemcells/$STEMCELL
    ;;
  *)
    echo "Must specify the target platform: gce|aws"
    exit 1
    ;;
esac

# Include the terraform output variables
. $SCRIPT_DIR/terraform-outputs-${TARGET_PLATFORM}.sh

export BUNDLE_GEMFILE=$SCRIPT_DIR/Gemfile
BOSH_CLI="bundle exec bosh"

# Other config
export PATH=$PATH:/usr/local/bin

cf_compile_manifest() {
  # Use spiff to generate CF deployment manifest
  cd ~

  # Output the director uuid to be populated by spiff
  echo -e "---\ndirector_uuid: $($BOSH_CLI status --uuid)" > templates/director-uuid.yml

  # Generate the manifest
  ./scripts/generate_cf_manifest.sh > ~/cf-manifest.yml
}

cf_deploy() {
  $BOSH_CLI deployment ~/cf-manifest.yml
  time $BOSH_CLI -n deploy
}

cf_compile_manifest
cf_deploy
