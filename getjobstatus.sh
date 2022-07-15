#!/bin/sh

#jobstatus=$(kubectl -n specialcollections-test get jobs -lrole=manual-index -o json)
jobstatus=$(cat jobstatus.json)
count_total=$(echo $jobstatus | jq '.items | length')
count_succeeded=$(echo $jobstatus | jq '[.items[].status.succeeded] | add')
echo "Failed EADs:"
echo $jobstatus | jq '.items[] | select(.status.succeeded != 1) | .metadata.annotations.ead'
echo "Succeeded: $count_succeeded/$count_total"
echo "Failed: $(expr $count_total - $count_succeeded)/$count_total"
