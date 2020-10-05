#!/bin/bash

CHANNEL=$1
FORMAT=$2

if [ -z $CHANNEL ]
then
  echo "Error: please set env var CHANNEL to a valid update channel value such as 'stable-4.5'"
  exit 1
fi

[ -f graph.sh ] || wget https://raw.githubusercontent.com/openshift/cincinnati/master/hack/graph.sh
chmod 755 graph.sh

echo "Generating graph for channel '$CHANNEL'"
echo "(please change variable in script to adjust channel)"

curl -sH 'Accept:application/json' 'https://api.openshift.com/api/upgrades_info/v1/graph?channel='$CHANNEL'&arch=amd64' | ./graph.sh | dot -T$FORMAT > graph_$CHANNEL.$FORMAT


