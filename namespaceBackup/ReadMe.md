# Namespace Backup

While an etcd backup is an essential part of OpenShift Day-2 operations activities, establishing the 'backup' of individual namespace artefacts to YAML or JSON can be helpful as well.

We show a simple approach for exporting all namespaces of a cluster using an OpenShift CronJob.

More enhanced approaches using tools like Restic [1] or Velero [2], or solutions like trillio.io [3] (commercial solution) can be considered as well, dependent on the goals.

[1] <https://restic.net/>
[2] <https://velero.io/>
[3] <https://www.trilio.io/triliovault-for-kubernetes/>

## History

Date       | Version | Comment 
---------- | ------- | ---
2020-06-23 | 0.1     | Initial version
2020-12-22 | 0.2     | Add configuration ConfigMap; use cluster-admin (instead of cluster-reader) for Job execution; update documentation
           |         | 

## Prerequisites

> The example is based upon a namespace 'cluster-operations'.

## Create Service Account

We create a Service Account to run the CronJob Pod for pruning activities.

Yaml definition 'crb_backupRunner'

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cron-namespace-backup-sa
  namespace: "cluster-operations"
```

Import this file to create the service account

```shell
oc apply -f sa_backupRunner.yaml
```

## Create Role Binding for Service Account

The Service Account needs to get a role binding to obtain the required permissions.

> Using 'cluster-admin' role for Job execution, as the 'cluster-reader' role by default cannot gather all information on CRDs added on cluster level.

Create the Yaml file `crb_backupRunner.yaml`

```yaml
apiVersion: authorization.openshift.io/v1
kind: ClusterRoleBinding
metadata:
  name: cron-namespace-backup
roleRef:
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: cron-namespace-backup-sa
  namespace: "cluster-operations"
```

and import the yaml using

```shell
oc apply -f crb_backupRunner.yaml
```


## Create Image Pull Secret

You will need to create a registry service account to use prior to completing any of the following tasks. See <https://access.redhat.com/terms-based-registry/> to create the pull secret.

Once your pull secret is created there, the page provides you access to download the secret and import it into OpenShift.

Yaml File Example `pullSecretSample.yaml`

> Note: get the correct one from the Web page to obtain the correct pull secret. Example has dummy value only and the Yaml file cannot be imported as is!

> Remember to set the correct target namespace (`cluster-operations`) in the Secret Yaml file.


```yaml
apiVersion: v1
kind: Secret
metadata:
  name: xyz-user-pull-secret
  namespace: cluster-operations
data:
  .dockerconfigjson: ey...replace-with-concrete-pull-secret...fQ==
type: kubernetes.io/dockerconfigjson
```

Import the secret. 

```shell
oc apply -f pullSecretSample.yaml
```



## Create Cron Job - Namespace Backup

### Backup target volume

We use a PVC as the target for the backup. The PVC can for example be bound to a NFS PV as shown below.

File `sample-backup-nfs-pv.yaml`. Create using `oc create -f sample-backup-nfs-pv.yaml` once the NFS server target data is adjusted.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-sample-nfs-pv
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 1Gi
  nfs:
    path: /data/export/share
    server: mynfs.myserver.example.com
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    kind: PersistentVolumeClaim
    namespace: cluster-operations
    name: backup-claim
```

File `sample-backup-nfs-pvc.yaml`. Create using `oc create -f sample-backup-nfs-pvc.yaml`. 

> Adjust the storage to a suitable size.

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: backup-claim
  namespace: cluster-operations
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
```

### Backup Configuration

The ConfigMap `backup-config` is used for simple configuration of the backup. the ConfigMap covers two settings

* `backup-clusterresources`
	* set to 'true' if all cluster-level resources should be included in the backup, e.g. any CustomResourceDefinitions, ClusterRoles, etc.
* `backup-namespace-selector`
	* define a label selector which is used to filter the namespaces to be included in the backup
	* the example uses 'backup=true' as label selector, i.e. only namespaces having this label are included in the backup
		* use `oc label namespace my-namespace backup=true` to set the label
	* in case backup-namespace-selector is empty, all namespaces are included

ConfigMap

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: backup-config
  namespace: cluster-operations
data:
  backup-clusterresources: 'true'
  backup-namespace-selector: backup=true
```

Add the ConfigMap to the namespace using

```shell
oc apply -f cm_backup-config.yaml
```


### The backup CronJob

Create the Yaml file `cronJob_backupNamespaces.yaml`.
The CronJob uses the created service account for running the pod and requires the pull secret as `imagePullSecret`.

> Adjust the schedule entry when the CronJob is getting executed.

Note the 'CronJob.spec.concurrencyPolicy' is set to 'Forbid' to disallow concurrent execution. As the one-by-one backup of a large number of namespaces may take a while, this prevents multiple job executions to be fired.

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: backup-namespaces
  namespace: cluster-operations
spec:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 2
  concurrencyPolicy: "Forbid"
  schedule: "55 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          containers:
          - name: backup-namespaces
            image: registry.redhat.io/openshift4/ose-cli
            env:
              - name: BACKUP_CLUSTERRESOURCES
                valueFrom:
                  configMapKeyRef:
                    name: backup-config 
                    key: backup-clusterresources 
              - name: NS_SELECTOR
                valueFrom:
                  configMapKeyRef:
                    name: backup-config 
                    key: backup-namespace-selector 
            envFrom:
              - configMapRef:
                  name: backup-config 
            command:
            - /bin/bash
            - -c
            - |
              #/bin/bash
              # workaround: ose-cli image sets $HOME to "/" which is not writable and prevents 'oc' to create $HOME/.kube directory
              # hence we set to writable '/tmp' directory
              export HOME=/tmp
              #
              # backup timestamp
              TIMESTAMP=$(date +%F--%H-%M-%S)
              #
              # process config
              selector=""
              [ $NS_SELECTOR ] && selector="-l $NS_SELECTOR"
              echo "INFO: starting backup at " $TIMESTAMP
              echo "INFO: backup cluster resources: " $BACKUP_CLUSTERRESOURCES
              echo "INFO: list of namespaces for backup (selector: " $$NS_SELECTOR "): $(oc get namespaces $selector -o jsonpath='{range .items[*]}{.metadata.name}{", "}')"
              echo "INFO:"
              echo
              if [ $BACKUP_CLUSTERRESOURCES == "true" ]
              then
                 #
                 # Backup cluster resource
                 #
                 echo "Backing up cluster resources"
                 oc get --ignore-not-found $( oc api-resources --verbs=list --namespaced=false -o name | xargs | sed 's/\ /,/g') -o yaml 2>/backup/"$TIMESTAMP"_backup_clusterresources.log | gzip -9 -c >/backup/"$TIMESTAMP"_backup_clusterresources.yaml.gz
              fi
              #
              # Backup individual namespace resources
              #
              echo "Backing up namespaces ..."
              for ns in $(oc get namespaces $selector -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}')
              do
                echo
                echo "Backing up namespace $ns at $TIMESTAMP";
                oc get -n $ns --ignore-not-found  $( oc api-resources -n $ns --verbs=list --namespaced -o name | xargs | sed 's/\ /,/g') -o yaml 2>/backup/"$TIMESTAMP"_backup_"$ns".log | gzip -9 -c >/backup/"$TIMESTAMP"_backup_"$ns".yaml.gz
              done
            volumeMounts:
              - name: backup-claim
                mountPath: /backup
            imagePullPolicy: IfNotPresent
          restartPolicy: OnFailure
          serviceAccountName: cron-namespace-backup-sa
          imagePullSecrets:
          - name: xyz-user-pull-secret
          volumes:
            - name: backup-claim
              persistentVolumeClaim:
                claimName: backup-claim
```


Create the CronJob object

```shell
oc apply -f cronJob_backupNamespaces.yaml
```

### Creating files using defined UID/GID

If a NFS share mounted using the PV requires to have defined UID/GID for the backup files being created, use a 'securityContext' definition in the backup CronJob. See example file `cronJob_backupNamespaces_withUIDGID.yaml`.

