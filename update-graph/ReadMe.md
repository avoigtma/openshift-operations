# Update Graph for OpenShift v4.x

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

## Create a visual represenation

Run the script supplying 2 parameters

* parameter 1: OpenShift Update Channel, e.g. 'stable-4.5'
* parameter 2: output format supported by 'graphviz', e.g. 'pdf', 'png' or 'svg'

Example:

```shell
./makeGraph.sh fast-4.5 pdf
```


