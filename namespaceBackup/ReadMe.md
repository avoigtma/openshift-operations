# Namespace Backup

While an etcd backup is an essential part of OpenShift Day-2 operations activities, establishing the 'backup' of individual namespace artefacts to YAML or JSON can be helpful as well.

We show a simple approach for exporting all namespaces of a cluster using an OpenShift CronJob.

More enhanced approaches using tools like Restic [1] or Velero [2], or solutions like trillio.io [3] (commercial solution) should be considered as well, dependent on the goals.

[1] <https://restic.net/>
[2] <https://velero.io/>
[3] <https://www.trilio.io/triliovault-for-kubernetes/>

> The example is based upon a namespace 'cluster-operations'.

## Create Service Account

We create a Service Account to run the CronJob Pod for pruning activities.

Yaml definition 'crb_backupRunner'

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cron-namespace-backup-sa
  namespace: "cluster-operations"
```

Import this file to create the service account

```
oc create -f crb_backupRunner
```

## Create Role Binding for Service Account

The Service Account needs to get a role binding to obtain the required permissions.

Create the Yaml file `crb_backupRunner.yaml`

```
apiVersion: authorization.openshift.io/v1
kind: ClusterRoleBinding
metadata:
  name: cron-namespace-backup
roleRef:
  name: cluster-reader
subjects:
- kind: ServiceAccount
  name: cron-namespace-backup-sa
  namespace: "cluster-operations"
```

and import the yaml using `oc create -f crb_backupRunner.yaml`.


## Create Image Pull Secret

You will need to create a registry service account to use prior to completing any of the following tasks. See <https://access.redhat.com/terms-based-registry/> to create the pull secret.

Once your pull secret is created there, the page provides you access to download the secret and import it into OpenShift.

Yaml File Example `pullSecretSample.yaml`

> Note: get the correct one from the Web page to obtain the correct pull secret. Example has dummy value only and the Yaml file cannot be imported as is!

```
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

```
oc create -f pullSecretSample.yaml
```



## Create Cron Job - Namespace Backup

### Backup target volume

We use a PVC as the target for the backup. The PVC can for example be bound to a NFS PV as shown below.

File `sample-backup-nfs-pv.yaml`. Create using `oc create -f sample-backup-nfs-pv.yaml` once the NFS server target data is adjusted.

```
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

```
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



### Thee backup CronJob

Create the Yaml file `cronJob_backupNamespaces.yaml`.
The CronJob uses the created service account for running the pod and requires the pull secret as `imagePullSecret`.

> Adjust the schedule entry when the CronJob is getting executed.

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: backup-namespaces
  namespace: cluster-operations
spec:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 2
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
            command:
            - /bin/bash
            - -c
            - |
              #/bin/bash
              # workaround: ose-cli image sets $HOME to "/" which is not writable and prevents 'oc' to create $HOME/.kube directory
              # hence we set to writable '/tmp' directory
              export HOME=/tmp
              #
              TIMESTAMP=$(date +%F--%H-%M-%S)
              for ns in $(oc get projects --no-headers | awk '{print $1}')
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

```
oc create -f cronJob_backupNamespaces.yaml
```


