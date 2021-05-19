# Pruning Activities

Build, DeploymentConfigs and Images require regular pruning jobs on the platform

We establish CronJobs which run such pruning commands (`oc adm prune ...`) in a pod on the platform.

## Prerequisites/Preparations

> The example is based upon a namespace 'cluster-operations'.
> 
> Please create this namespace/project before continuing with the next sections.

The CronJob definitions below define node selectors on the worker nodes. Please remove or adjust depending on your cluster node role definitions.


## Note: Adjust to your OpenShift release

> Please adjust the image references in below's CronJob definitions to your matching OpenShift release.

The examples below are currently based upon OpenShift v4.7 and use the generic 'v4.7' tag. The `imagePullPolicy: Always` ensures that the latest image release within the OpenShift version is always used.

## Create Service Account

We create a Service Account to run the CronJob Pod for pruning activities.

### using command line

```shell
oc create sa cron-prune-runner-sa
```

### using yaml

Create ServiceAccount Yaml file `sa_pruneRunnner.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cron-prune-runner-sa
  namespace: "cluster-operations"
```

and import the yaml using `oc create -f sa_pruneRunnner.yaml`.

## Create Role Binding for Service Account

The Service Account needs to get a role binding to obtain the required permissions.

Create the Yaml file `crb_prungRunner.yaml`

```yaml
apiVersion: authorization.openshift.io/v1
kind: ClusterRoleBinding
metadata:
  name: cron-prune-runner
roleRef:
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: cron-prune-runner-sa
  namespace: "cluster-operations"
```

and import the yaml using `oc apply -f crb_pruneRunnner.yaml`.

> Note: For simplicity, we use the 'ClusterAdmin' role. It would be a better solution to create a custom role definition having only the required permissions for the Service Account. However, as the pruning jobs anyway run in a namespace owned by a platform team and thus 'ClusterAdmin' enabled users, using 'cluster-admin' role is acceptable.


## Create Image Pull Secret

You will need to create a registry service account to use prior to completing any of the following tasks. See <https://access.redhat.com/terms-based-registry/> to create the pull secret.

Once your pull secret is created there, the page provides you access to download the secret and import it into OpenShift.

Yaml File Example `pullSecretSample.yaml`

> Note: get the correct one from the Web page to obtain the correct pull secret. Example has dummy value only and the Yaml file cannot be imported as is!

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



## Create Cron Job - Image Pruning

Create the Yaml file `cronJob_pruneImages.yaml`.
The CronJob uses the created service account for running the pod and requires the pull secret as `imagePullSecret`.

> Notes:
> 
> - By default in OCP v4 the registry is not exposed
> - `oc adm prune image ...` command attempts to use the internal 'https' service URL.
> - For simplicity of the image pruning in the pod, the `--force-insecure` is being used.

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: prune-images
  namespace: cluster-operations
spec:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  schedule: "45 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          nodeSelector:
            node-role.kubernetes.io/worker: ""
          containers:
          - name: prune-images
            image: registry.redhat.io/openshift4/ose-cli:v4.7
            command:
            - /bin/bash
            - -c
            - |
              #/bin/bash
              oc adm prune images --keep-tag-revisions=3 --keep-younger-than=60m --force-insecure --confirm
              oc adm prune images --prune-over-size-limit --force-insecure --confirm
            imagePullPolicy: Always
            env:
            - name: HOME
              value: "/tmp"
          restartPolicy: OnFailure
          serviceAccountName: cron-prune-runner-sa
          imagePullSecrets:
          - name: xyz-user-pull-secret
```


Create the CronJob object in the cluster:

```shell
oc apply -f cronJob_pruneImages.yaml
```

## Create Cron Job - Pruning Deployments

Create a similar CronJob and repleace the 'oc adm prune images ...' commands in the CronJob 
definition with commands for pruning Deployments.

E.g. using following `cronJob_pruneDeployments.yaml`:

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: prune-deployments
  namespace: cluster-operations
spec:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  schedule: "45 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          nodeSelector:
            node-role.kubernetes.io/worker: ""
          containers:
          - name: prune-images
            image: registry.redhat.io/openshift4/ose-cli:v4.7
            command:
            - /bin/bash
            - -c
            - |
              #/bin/bash
              oc adm prune deployments --keep-younger-than=60m --confirm
            imagePullPolicy: Always
            env:
            - name: HOME
              value: "/tmp"
          restartPolicy: OnFailure
          serviceAccountName: cron-prune-runner-sa
          imagePullSecrets:
          - name: xyz-user-pull-secret
```

Create the CronJob object in the cluster:

```shell
oc apply -f cronJob_pruneDeployments.yaml
```


## Create Cron Job - Pruning Builds

Create a similar CronJob and repleace the 'oc adm prune images ...' commands in the CronJob 
definition with commands for pruning Builds.

E.g. using following `cronJob_pruneBuilds.yaml`:

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: prune-builds
  namespace: cluster-operations
spec:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  schedule: "45 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          nodeSelector:
            node-role.kubernetes.io/worker: ""
          containers:
          - name: prune-images
            image: registry.redhat.io/openshift4/ose-cli:v4.7
            command:
            - /bin/bash
            - -c
            - |
              #/bin/bash
              oc adm prune builds --orphans --keep-complete=3 --keep-failed=1 --keep-younger-than=60m --confirm
            imagePullPolicy: Always
            env:
            - name: HOME
              value: "/tmp"
          restartPolicy: OnFailure
          serviceAccountName: cron-prune-runner-sa
          imagePullSecrets:
          - name: xyz-user-pull-secret
```

Create the CronJob object in the cluster:

```shell
oc apply -f cronJob_pruneBuilds.yaml
```
