---
name: bosh

releases:
- name: bosh
  url: https://bosh.io/d/github.com/cloudfoundry/bosh?v=207
  sha1: 5f835bad5fc46230cd2fa823c0a52a94829ee044
- name: bosh-aws-cpi
  url: https://bosh.io/d/github.com/cloudfoundry-incubator/bosh-aws-cpi-release?v=28
  sha1: c7ce03393ebedd87a860dc609758ddb9654360fa

resource_pools:
- name: vms
  network: private
  stemcell:
    url: https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent?v=3074
    sha1: 1a29c43d4e8abf7476ed6bb83168df1bdb742022
  cloud_properties:
    instance_type: t2.medium
    ephemeral_disk: {size: 25_000, type: gp2}
    availability_zone: ${aws_availability_zone} # <--- Replace with Availability Zone

disk_pools:
- name: disks
  disk_size: 20_000
  cloud_properties: {type: gp2}

networks:
- name: private
  type: manual
  subnets:
  - range: 10.0.0.0/24
    gateway: 10.0.0.1
    dns: [10.0.0.2]
    cloud_properties:
      subnet: ${aws_subnet_id} # <--- Replace with Subnet ID
      security_groups: [${bosh_security_group}]
- name: public
  type: vip

jobs:
- name: bosh
  instances: 1

  templates:
  - {name: nats, release: bosh}
  - {name: redis, release: bosh}
  - {name: postgres, release: bosh}
  - {name: blobstore, release: bosh}
  - {name: director, release: bosh}
  - {name: health_monitor, release: bosh}
  - {name: registry, release: bosh}
  - {name: cpi, release: bosh-aws-cpi}

  resource_pool: vms
  persistent_disk_pool: disks

  networks:
  - name: private
    static_ips: [${aws_static_ip}]
    default: [dns, gateway]
  - name: public
    static_ips: [${aws_public_ip}]

  properties:
    nats:
      address: 127.0.0.1
      user: nats
      password: nats-password

    redis:
      listen_addresss: 127.0.0.1
      address: 127.0.0.1
      password: redis-password

    postgres: &db
      host: 127.0.0.1
      user: postgres
      password: postgres-password
      database: bosh
      adapter: postgres

    registry:
      address: ${aws_static_ip}
      host: ${aws_static_ip}
      db: *db
      http: {user: admin, password: admin, port: 25777}
      username: admin
      password: admin
      port: 25777

    blobstore:
      address: ${aws_static_ip}
      port: 25250
      provider: dav
      director: {user: director, password: director-password}
      agent: {user: agent, password: agent-password}

    director:
      address: 127.0.0.1
      name: my-bosh
      db: *db
      cpi_job: cpi
      max_threads: 10
      ignore_missing_gateway: "false"

    hm:
      director_account: {user: admin, password: admin}
      resurrector_enabled: true

    aws: &aws
      access_key_id: ${aws_access_key_id} # <--- Replace with AWS Access Key ID
      secret_access_key: ${aws_secret_access_key} # <--- Replace with AWS Secret Key
      default_key_name: insecure-deployer
      default_security_groups: [${default_security_group}]
      region: ${aws_region}

    agent: {mbus: "nats://nats:nats-password@${aws_static_ip}:4222"}

    ntp: &ntp [0.pool.ntp.org, 1.pool.ntp.org]

cloud_provider:
  template: {name: cpi, release: bosh-aws-cpi}

  ssh_tunnel:
    host: ${aws_static_ip}
    port: 22
    user: vcap
    private_key: .ssh/id_rsa # Path relative to this manifest file

  mbus: "https://mbus:mbus-password@${aws_static_ip}:6868"

  properties:
    aws: *aws
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: *ntp
