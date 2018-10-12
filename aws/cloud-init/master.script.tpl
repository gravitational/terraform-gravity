#!/bin/sh
# TODO(knisbet) This should really be removed, because things like tokens will get printed to the logs
set -x

echo "bootstrap master"

if [ "${skip_install}" == "true" ]; then
  exit 0
fi

# Set some curl options so that temporary failures get retried
# More info: https://ec.haxx.se/usingcurl-timeouts.html
CURL_OPTS="--retry 100 --retry-delay 0 --connect-timeout 10 --max-time 300"

# Apparently AWS ELB interface does not expose the proper ELB Hosted Zone ID for use
# with Route53 to properly create ALIAS records
# See: https://forums.aws.amazon.com/thread.jspa?messageID=608949 and https://github.com/hashicorp/terraform/issues/9289
declare -A elb_hosted_zones
elb_hosted_zones["ap-south-1"]="ZP97RAFLXTNZK"
elb_hosted_zones["ap-northeast-1"]="Z14GRHDCWA56QT"
elb_hosted_zones["ap-northeast-2"]="ZWKZPGTI48KDX"
elb_hosted_zones["ap-southeast-1"]="Z1LMS91P8CMLE5"
elb_hosted_zones["ap-southeast-2"]="Z1GM3OXH4ZPM65"
elb_hosted_zones["eu-central-1"]="Z215JYRZR1TBD5"
elb_hosted_zones["eu-west-1"]="Z32O12XQLNTSW2"
elb_hosted_zones["sa-east-1"]="Z2P70J7HTTTPLU"
elb_hosted_zones["us-east-1"]="Z35SXDOTRQ7X7K"
elb_hosted_zones["us-east-2"]="Z3AADJGX6KTTL2"
elb_hosted_zones["us-west-1"]="Z368ELLRRE2KJ0"
elb_hosted_zones["us-west-2"]="Z1H1FL5HABSF5"

#
# Mount / Create etcd partition
#
umount /dev/xvdc || true
mkfs.ext4 /dev/xvdc
mkdir -p /var/lib/gravity/planet/etcd
mount /var/lib/gravity/planet/etcd



#
# Install Gravity Application
#
EC2_AVAIL_ZONE=`curl $${CURL_OPTS} -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
EC2_INSTANCE_ID=`curl $${CURL_OPTS} -s http://169.254.169.254/latest/meta-data/instance-id`

AUTOSCALING_GROUP_NAME=`aws --region $EC2_REGION autoscaling describe-auto-scaling-instances --instance-ids $EC2_INSTANCE_ID --query 'AutoScalingInstances[*].AutoScalingGroupName' --output text`
AUTOSCALING_INSTANCES=`aws --region $EC2_REGION autoscaling describe-auto-scaling-groups --auto-scaling-group-name $${AUTOSCALING_GROUP_NAME} --query 'AutoScalingGroups[*].Instances[*].[InstanceId]' --output text | sed 's/\\n/ /g'`

# Poor man's leader election, look at all the instance id's in the ASG, sort them, and the top sored entry should coordinate the installation
# TODO: is it possible that a node can get this far into installation where another node isn't listed in the ASG yet? which sould elect multiple leaders?
INSTALL_LEADER=`echo $AUTOSCALING_INSTANCES | tr " " "\n" | sort | head -1`

#
#
# Download and install the application
#
#

# Try and contact an existing cluster and download the gravity binary
# This is tricky, because the SSM store doesn't get cleaned up, so we can't use the presence / absence of a value in the SSM store to understand
# if a cluster is present or not. This has the risk though, that a temporary failure could launch a new cluster install, but installing masters
# to an existing cluster should be quite rare
TELEKUBE_SERVICE=`aws ssm get-parameter --name /telekube/${cluster_name}/service --region $EC2_REGION --query 'Parameter.Value' --output text`
if [ ! -z "$${TELEKUBE_SERVICE}" ]; then
  # Download gravity of the right version directly from the cluster
  curl $${CURL_OPTS} -k -o /tmp/gravity $${TELEKUBE_SERVICE}/telekube/gravity
  chmod +x /tmp/gravity
fi

#
# Install
#
# Install if we're the leader and we failed to download gravity from an existing cluster
if [ "$${INSTALL_LEADER}" = "$${EC2_INSTANCE_ID}" ] && [ ! -f /tmp/gravity ]; then
  # Application is available over http(s)
  if [ "$(echo "${source}" | cut -c 1-7)" = 'http://' ] || [ "$(echo "${source}" | cut -c 1-8)" = 'https://' ]; then
    curl $${CURL_OPTS} ${source} -o /tmp/installer.tar

  # application is on s3
  elif [ "$(echo "${source}" | cut -c 1-5)" = 's3://' ]; then
    aws s3 cp ${source} /tmp/installer.tar

  # application is on a private ops center
  elif [ ! -z "${ops_url}" ]; then 
    tele login --token=${ops_token} ${ops_url}
    tele pull -o /tmp/installer.tar ${source} 

  # default get.gravitational.io
  else 
    tele pull -o /tmp/installer.tar ${source} 
  fi

  ADVERTISE=""
  if [ ! -z "${ops_advertise_addr}" ]; then
    ADVERTISE="--ops-advertise-addr=${ops_advertise_addr}"
  fi

  TRUSTED_CLUSTER_TOKEN=`aws ssm get-parameter --name /telekube/${cluster_name}/config/trusted-cluster-token --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  if [ ! -z "$${TRUSTED_CLUSTER_TOKEN}" ]; then
    PROVISION_TRUSTED_CLUSTER="--ops-tunnel-token $${TRUSTED_CLUSTER_TOKEN}"
  fi

  mkdir -p /tmp/gravity
  tar -xvf /tmp/installer.tar -C /tmp/gravity
  pushd /tmp/gravity
  ./gravity install --cluster ${cluster_name} --flavor ${flavor} --role ${master_role} $${PROVISION_TRUSTED_CLUSTER} $${ADVERTISE}
  popd

  #
  # Provision an admin token that terraform can use to administer this cluster
  #
  TF_ADMIN_TOKEN=`aws ssm get-parameter --name /telekube/${cluster_name}/tf-admin-token --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  if [ ! -z "$${TF_ADMIN_TOKEN}" ]; then
    cat <<EOF > token.yaml
kind: token
version: v2
metadata:
   name: $${TF_ADMIN_TOKEN}
spec:
   user: "adminagent@${cluster_name}"
EOF
    gravity resource create token.yaml
    rm token.yaml
  fi

  #
  # Provision Trusted Clusters
  #
  # TODO(knisbet) Should the ops center ports be variables?
  TC_HOSTNAME=`aws ssm get-parameter --name /telekube/${cluster_name}/trusted-cluster/host --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  TC_TOKEN=`aws ssm get-parameter --name /telekube/${cluster_name}/trusted-cluster/token --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  if [ ! -z "$${TC_HOSTNAME}" ]; then
  cat <<EOF > trusted_cluster.yaml
kind: trusted_cluster
version: v2
metadata:
  name: $${TC_HOSTNAME}
spec:
  enabled: true
  pull_updates: false
  token: $${TC_TOKEN}
  tunnel_addr: "$${TC_HOSTNAME}:3024"
  web_proxy_addr: "$${TC_HOSTNAME}:443"
EOF
  gravity resource create trusted_cluster.yaml
  rm trusted_cluster.yaml
  fi
  

  #
  # Provision an identity provider for admin access
  # TODO(knisbet) This needs to be moved to a proper provisioning module, so a user can fully configure the oidc setup
  OIDC_CLIENT_ID=`aws ssm get-parameter --name /telekube/${cluster_name}/oidc/client-id --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  OIDC_CLIENT_SECRET=`aws ssm get-parameter --name /telekube/${cluster_name}/oidc/client-secret --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  OIDC_CLAIM=`aws ssm get-parameter --name /telekube/${cluster_name}/oidc/claim --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  OIDC_ISSUER_URL=`aws ssm get-parameter --name /telekube/${cluster_name}/oidc/issuer-url --region $EC2_REGION --query 'Parameter.Value' --output text --with-decryption`
  if [ ! -z "$${OIDC_CLIENT_SECRET}" ]; then
    cat <<EOF > oidc.yaml
kind: oidc
version: v2
metadata:
  name: sso
spec:
  claims_to_roles:
  - claim: roles
    roles:
    - '@teleadmin'
    value: $${OIDC_CLAIM}
  client_id: $${OIDC_CLIENT_ID}
  client_secret: $${OIDC_CLIENT_SECRET}
  issuer_url: $${OIDC_ISSUER_URL}
  redirect_url: https://${cluster_name}/portalapi/v1/oidc/callback
  scope:
  - roles
EOF
    gravity resource create oidc.yaml
    rm oidc.yaml
  fi

  #
  # Only if an opscenter with public access enabled, try to provision DNS / letsencrypt
  # TODO(knisbet) this should be offloaded to an automatic DNS service loaded in k8s / the app
  # But temporarily we'll provision from cloud-init script
  #
  # IF the cluster has the gravity-public svc, it must be an externally facing ops center
  if gravity enter -- --notty /usr/bin/kubectl -- --namespace=kube-system get svc/gravity-public; then
    #
    # Use letsencrypt to get a cert for this domain
    # TODO(knisbet) we should really be using a kubernetes project for this, that will automatically renew
    # certs and store them in k8s, but for now, we'll just provision / renew on the installer node
    #
    # TODO(knisbet) automatic renewal and import into telekube
    yum -y install epel-release
    yum -y install certbot

    # install certbot in a virtualenv to work around system python dependency issues
    yum -y install python-virtualenv
    mkdir -p /root/virtualenv
    cd /root/virtualenv
    virtualenv --no-site-packages -p /usr/bin/python2.7 certbot
    . /root/virtualenv/certbot/bin/activate
    pip install certbot certbot-dns-route53
    deactivate
    /root/virtualenv/certbot/bin/certbot certonly -n --agree-tos --email ${email} --dns-route53 -d ${cluster_name}
    cd

    cat <<EOF > keypair.yaml
kind: tlskeypair
version: v2
metadata:
  name: keypair
spec:
  private_key: |
EOF
    cat /etc/letsencrypt/live/${cluster_name}/privkey.pem | sed 's/^/    /' >> keypair.yaml
    echo "  cert: |" >> keypair.yaml 
    cat /etc/letsencrypt/live/${cluster_name}/fullchain.pem | sed 's/^/    /' >> keypair.yaml
    gravity resource create keypair.yaml
    rm keypair.yaml

    until [ ! -z "$$elb_dns_name" ]; do
      sleep 5
      elb_dns_name=$(sudo gravity enter -- --notty /usr/bin/kubectl -- --namespace=kube-system get svc/gravity-public -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    done
    echo "elb_dns_name: $${elb_dns_name}"
    alias_zone_id=$${elb_hosted_zones[$${EC2_REGION}]}
    echo "alias_zone_id: $${alias_zone_id}"
    hosted_zone_id=$(aws route53 list-hosted-zones --query 'HostedZones[?Name==`${aws_hosted_zone_name}`].Id' --output text | sed 's#/hostedzone/##')
    host_record=$(cat <<EOF
    {
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "AliasTarget": {
                        "DNSName": "dualstack.$${elb_dns_name}",
                        "EvaluateTargetHealth": false,
                        "HostedZoneId": "$${alias_zone_id}"
                    },
                    "Name": "${cluster_name}",
                    "Type": "A"
                }
            }
        ],
        "Comment": "Add DNS record for ${cluster_name}"
    }
EOF
    )

    # NOTE: requests to AWS Route53 can handle asterisk just fine,
    # but the response escapes the asterisk as "\052"
    wildcard_record=$(cat <<EOF
    {
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "AliasTarget": {
                        "DNSName": "${cluster_name}",
                        "EvaluateTargetHealth": false,
                        "HostedZoneId": "$${hosted_zone_id}"
                    },
                    "Name": "*.${cluster_name}",
                    "Type": "A"
                }
            }
        ],
        "Comment": "Add DNS record for *.${cluster_name}"
    }
EOF
    )

    # Create the DNS aliases
    change_id=$(aws route53 change-resource-record-sets --hosted-zone-id=$${hosted_zone_id} --change-batch "$${host_record}" --query 'ChangeInfo.Id' --output text)
    aws route53 change-resource-record-sets --hosted-zone-id=$${hosted_zone_id} --change-batch "$${wildcard_record}"
    echo "change_id: $${change_id}"

    status="PENDING"
    until [ "$${status}" != "PENDING" ]; do
      sleep 5
      status=$(aws route53 get-change --id "$${change_id}" --query 'Changinfo.Status' --output text)
      echo "Route53 ALIAS status for ${cluster_name}: $${status}"
    done
    echo "DNS record creation completed"

  fi

#
# Join
#
else
  # Wait until the leader completes it's installation and is available
  until [ -f /tmp/gravity ]; do
    sleep 15
    TELEKUBE_SERVICE=`aws ssm get-parameter --name /telekube/${cluster_name}/service --region $EC2_REGION --query 'Parameter.Value' --output text`
    if [ ! -z "$${TELEKUBE_SERVICE}" ]; then
       # Download gravity of the right version directly from the cluster
       curl $${CURL_OPTS} -k -o /tmp/gravity $${TELEKUBE_SERVICE}/telekube/gravity
       chmod +x /tmp/gravity
    fi
  done

 

  # In AWS mode gravity will discover the data from AWS SSM and join the cluster
  /tmp/gravity autojoin ${cluster_name} --role ${master_role}
fi