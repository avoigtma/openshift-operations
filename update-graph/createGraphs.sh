#!/bin/bash

DIR=$(dirname "$0")

$DIR/makeGraph.sh candidate-4.6 pdf
$DIR/makeGraph.sh candidate-4.7 pdf

$DIR/makeGraph.sh fast-4.6 pdf
$DIR/makeGraph.sh fast-4.7 pdf

$DIR/makeGraph.sh stable-4.6 pdf
$DIR/makeGraph.sh stable-4.7 pdf

