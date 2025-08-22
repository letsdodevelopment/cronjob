# Cluster and Node maintenance using CronJob

## Step2

- create a new project using admin role
`oc new-project application-space`

- create a 3x sample httpd app using httpd24_app.yaml
```shell
    oc create -f httpd24_app.yaml
    sed -e 's/registry.redhat.io\/ubi9\/httpd-24/registry.redhat.io\/ubi9\/httpd-24:1-1731599989/g' -e 's/httpd24-app/httpd24-app-v1/g' httpd24_app.yaml | oc create -f - 
    sed -e 's/registry.redhat.io\/ubi9\/httpd-24/registry.redhat.io\/ubi9\/httpd-24:1-1733127463/g' -e 's/httpd24-app/httpd24-app-v2/g' httpd24_app.yaml | oc create -f -
    # we end of create 3 httpd apps using different versions. This helps us populate images
    # when we run crictl images
        oc get deploy -o wide                                                                                                                                                                                                                                                                 ─╯
        NAME             READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                                          SELECTOR
        httpd24-app      1/1     1            1           26m     httpd-24     registry.redhat.io/ubi9/httpd-24                app=httpd24-app
        httpd24-app-v1   1/1     1            1           8m3s    httpd-24     registry.redhat.io/ubi9/httpd-24:1-1731599989   app=httpd24-app-v1
        httpd24-app-v2   1/1     1            1           7m19s   httpd-24     registry.redhat.io/ubi9/httpd-24:1-1733127463   app=httpd24-app-v2

     oc debug nodes/crc -- chroot /host /bin/bash -c 'crictl images | grep httpd-24'                                                                               󱃾 applications-space/api-crc-testing:6443/kubeadmin/applications-space 12:54:09
        Temporary namespace openshift-debug-p2png is created for debugging node...
        Starting pod/crc-debug-2znfc ...
        To use host binaries, run `chroot /host`
        registry.redhat.io/ubi9/httpd-24                                               1-1731599989        6444ecacc40f0       329MB
        registry.redhat.io/ubi9/httpd-24                                               1-1733127463        1faa411390ba2       328MB
        registry.redhat.io/ubi9/httpd-24                                               latest              6e0650b7b0221       312MB
```

create a simple bash script to run against node (e.g.deleteimages.sh)
    - e.g. list images and then prune old images
- create a configmap using --from-file
`oc create configmap cmdeleteimages --from-file=deleteimages.sh=deleteimages.sh -o yaml --validate=true --dry-run=client > cmdeleteimages.yaml`

The above command gives us an output in yaml which could be used for 
further customization. Now, create a cm using the following command

`oc create --save-config -f cmdeleteimages.yaml`

- create a cronjob using image `quay.io/openshift/origin-cli`

`oc create cronjob cjdeleteimages --dry-run=client -o yaml --image quay.io/openshift/origin-cli --schedule='*/5 * * * *' > cjdeleteimages.yaml`

Now there is work to do here. We need to update this file to use configmap
and we also need to add `command` describing where
the script is located.


once it done, execute the cronjob using the following command

`oc create --save-config -f cjdeleteimages.yaml`

Check if the cronjob is created. In this yaml we `--schedule=*/1 * * * *` which
means, that every other minute this job will run

Check the status of this job using

```shell
oc get cronjob
NAME             SCHEDULE      TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cjdeleteimages   */1 * * * *   <none>     False     0        42s             3m57s

# all looks okay but check the logs
oc logs pods/cjdeleteimages-29264379-6g7vf

Error from server (Forbidden): nodes is forbidden: User "system:serviceaccount:applications-space:default" cannot list resource "nodes" in API group "" at the cluster scope

# This error we need to resolve.
# From the error message it is clear
# we are using default service account i.e. we need to new service account
# And this service account needs a permission on nodes at cluster scope
```

`oc create serviceaccount cronjob-svv`

assign permissions to the service account,

`oc adm policy add-cluster-role-to-user cluster-admin -z cronjob-svv`

we need to assign scc as well. Why?

`oc adm policy add-scc-to-user privileged -z cronjob-svv` 

now add this service account to the cronjob using
serviceAccountName: cronjob-svv



