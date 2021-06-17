# Update Graph for OpenShift v4.x

## Online Version

There is [https://access.redhat.com/labs/ocpupgradegraph/update_channel](https://access.redhat.com/labs/ocpupgradegraph/update_channel) in the Red Hat customer portal which allows to create an online display of the update graph.

The below's procedure shows, how to create PDFs locally.

## Overview

See Red Hat KCS #4583231 "OpenShift Container Platform (OCP) 4 upgrade paths" [https://access.redhat.com/solutions/4583231](https://access.redhat.com/solutions/4583231)

To visualize update paths, we need

* the `graph.sh` [https://github.com/openshift/cincinnati/blob/master/hack/graph.sh](https://github.com/openshift/cincinnati/blob/master/hack/graph.sh)
* `jq` utility
* `dot` utility (from 'graphviz' package)
* a SVG to PNG conversion tool like `inkscape`


## Installation

Install the dependencies using the platform package manager.

### Mac

```shell
brew install wget
brew install jq
brew install graphviz
brew cask install inkscape
```

### Linux

```shell
yum install -y wget
yum install -y jq
yum install -y graphviz
yum install -y inkscape
```

### Get the script

```shell
wget https://raw.githubusercontent.com/openshift/cincinnati/master/hack/graph.sh
```

## Create a visual represenation

Run the script supplying 2 parameters

* parameter 1: OpenShift Update Channel, e.g. 'stable-4.7'
	* common channels per minor release of OpenShift
		* 'stable-4.7'
		* 'fast-4.7'
		* 'candidate-4.7'
* parameter 2: output format supported by 'graphviz', e.g. 'pdf', 'png' or 'svg'

Example:

```shell
./makeGraph.sh fast-4.5 pdf
```


## Helper script

```shell
./createGraphs.sh
```

Creates PDF graphs for the 'stable' and 'fast' channels. Please adjust the scripts to cover the related release channels (currently for OCP v4.5 and v4.6 included).


