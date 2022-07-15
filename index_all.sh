#!/bin/sh -e

#kubectl create job --from=cronjob/specialcollections-manual-index specialcollections-manual-index-

EAD_LIST=`find * -name '*.xml' -print`
total_eads=$(echo $EAD_LIST | wc -w | tr -d ' ')
count=0
for ead in $EAD_LIST
do
  count=$((count + 1))
  echo " *** Queuing $ead ($count/$total_eads) *** "
  # format job name without /, _, . characters; truncate to 63 char or less; ensure no trailing -
  ead_no_slash=${ead//\//-}
  ead_no_underscore=${ead_no_slash//_/-}
  ead_no_extension=${ead_no_underscore%\.xml}
  #full_job_name="specialcollections-manual-index-$ead_no_extension"
  #truncated_job_name=${full_job_name:0:63}
  truncated_ead_no_extension=${ead_no_extension:0:31}
  job_name="specialcollections-manual-index-${truncated_ead_no_extension%-} "
  if [ -z "$REALLY_RUN" ]; then
    echo "Dry run - set REALLY_RUN to run: $job_name"
    continue
  fi
  echo "apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
  namespace: specialcollections-test
  annotations:
    ead: $ead
spec:
  backoffLimit: 3
  activeDeadlineSeconds: 86400
  template:
    metadata:
      labels:
        app: specialcollections
        role: manual-index
      namespace: specialcollections-test
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - topologyKey: "kubernetes.io/hostname"
            labelSelector:
              matchLabels:
                app: specialcollections
                role: manual-index
      restartPolicy: Never
      initContainers:
      - name: git-clone
        image: alpine/git
        imagePullPolicy: Always
        command:
        - git
        - clone
        - https://github.com/NYULibraries/findingaids_eads_test.git
        - "/findingaids_eads"
        volumeMounts:
        - mountPath: "/findingaids_eads"
          name: eads
      containers:
      - name: manual-index
        image: quay.io/nyulibraries/specialcollections_cron:master
        imagePullPolicy: Always
        command:
        - "/bin/sh"
        - "-c"
        - "--"
        args:
        - bundle exec rake ead_indexer:index EAD=\$EAD
        env:
        - name: EAD
          value: findingaids_eads/$ead
        - name: RAILS_ENV
          value: staging
        - name: FINDINGAIDS_LOG
          value: STDOUT
        - name: SOLR_URL
          valueFrom:
            secretKeyRef:
              key: solr_url
              name: specialcollections-config
        - name: PROM_PUSHGATEWAY_URL
          value: http://prom-aggregation-gateway.default.svc.cluster.local
        volumeMounts:
        - mountPath: "/app/findingaids_eads"
          name: eads
        resources:
          limits:
            cpu: 1000m
            memory: 1000Mi
          requests:
            cpu: 100m
            memory: 1000Mi
      volumes:
      - emptyDir: {}
        name: eads
" | kubectl --namespace specialcollections-test create -f - || echo 'Failed to create job; continuing...'
done
