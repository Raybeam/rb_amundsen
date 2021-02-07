#!/usr/bin/env bash

sudo rm /etc/neo4j/reset-password-aws.sh

sudo -u neo4j tee -a /etc/neo4j/reset-password-aws.sh << END
#!/bin/sh
# This script resets the default neo4j password to the AWS instance ID.
#
# It executes every time the system service starts, but will do nothing if
# the password has already been reset.
AWSINSTANCEID=$(curl -f -s http://169.254.169.254/latest/meta-data/instance-id)

export LOGFILE=/etc/neo4j/password-reset.log

while true; do
    if curl -s -I http://localhost:7474 | grep '200 OK'; then
        echo `date` 'Neo4j is up; changing default password' | tee $LOGFILE

        curl -v -H 'Content-Type: application/json' \
                -XPOST -d '{"password":"'${neo4j_password}'"}' \
                -u neo4j:neo4j \
                http://localhost:7474/user/neo4j/password 2>&1 | grep '200 OK'

        if [ $? -eq 0 ] ; then
          echo `date` "Default password reset to AWS instance ID $AWSINSTANCEID - a graph user is you!" | tee $LOGFILE
        else
          echo "Password has already been reset" | tee $LOGFILE
        fi
        break
    fi

    echo `date` 'Waiting for neo4j to come up' | tee $LOGFILE
    sleep 1
done
END
sudo chmod 755 /etc/neo4j/reset-password-aws.sh 

sudo service neo4j stop
sudo rm /var/lib/neo4j/data/dbms/auth
sudo service neo4j start 
# sudo /etc/neo4j/reset-password-aws.sh