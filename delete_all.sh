#!/bin/sh -e

jobs=$(kubectl -n specialcollections-test get jobs -lrole=manual-index | awk '{print $1}' | grep -v NAME | tr '\n' ' ')
total_jobs=$(echo $jobs | wc -w | tr -d ' ')
count=0
for j in $jobs
do
  count=$((count + 1))
  echo "Deleting job $count of $total_jobs: $j"
    kubectl -n specialcollections-test delete jobs $j 
done
