#!/bin/bash

function tf_init()
{
  pwd
  echo terraform init
  terraform init
  echo
}

for d in *-module
do
  cd $d
  tf_init
  cd ..
done

tf_init