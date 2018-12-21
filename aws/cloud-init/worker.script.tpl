#!/bin/sh
set -x

echo "bootstrap worker"

if [ "${skip_install}" == "true" ]; then
  exit 0
fi

#
# Install Gravity Application
#
EC2_AVAIL_ZONE=`curl $${CURL_OPTS} -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

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
/tmp/gravity autojoin ${cluster_name} --role ${worker_role}
