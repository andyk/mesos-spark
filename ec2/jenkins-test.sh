#!/bin/sh

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is a script that captures what we want Jenkins to run in order to do
# a distributed test. We put this here instead of in the jenkins project
# configuration so that it can be tracked via SVC.


# Shut down any nodes that are currently running under the "andy" keypair
for i in `euca-describe-instances|grep running|grep andy|cut -f2`; do
  euca-terminate-instances $i
done

function update_num_running {
  ALL_RUNNING=`euca-describe-instances|grep andy|grep running|wc -l`
  ALL_SHUTTING_DOWN=`euca-describe-instances|grep andy|grep shutting-down|wc -l`
  NUM_RUNNING=$(($ALL_RUNNING+$ALL_SHUTTING_DOWN))
  if [[ $NUM_RUNNING > 0 ]]; then echo something is running; else echo nothing is running; fi
}
# give the instances a few seconds to shut down
sleep 2
update_num_running
while [[ $NUM_RUNNING > 0 ]]; do
  echo waiting for instances to shut down...
  update_num_running
  sleep 5
done

rm -rf ~/.ssh/known_hosts
./ec2/spark-ec2 --ami emi-EDB63CA9 -i ~/andy.pem -k andy -s 1 -w 40 --initial-user root --cluster-type standalone launch jenkins-test-cluster > spark-ec2-output

# We use this instead of ./spark-ec2 get-master jenkins-test-cluster since
# that functionality is currently broken in the port of spark_ec2.py to work
# with eucalyptus - I think because we don't set up and use groups correctly.
MASTER_IP=`grep "Master IP:" spark-ec2-output | cut -d " " -f3`

# Get the master port by scraping it off of the standalone cluster web UI 
MASTER_PORT=`curl $MASTER_IP:8080| grep "<title>Spark Master on " | sed -e 's/.*Spark Master on [^:]*:\([0-9]*\).*/\1/'`

# ssh into the master and run a spark example job
ssh -t -t -o StrictHostKeyChecking=no -i ~/andy.pem root@$MASTER_IP 'pushd /root/spark/; ./run spark.examples.SparkLR spark://$MASTER_IP:$MASTER_PORT'
# TODO(andyk):double check that SCALA_HOME is set up by the spark-ec2 setup scripts.

# shut down the cluster
# TODO: implement me.
