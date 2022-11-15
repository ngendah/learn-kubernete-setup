CONTROL_PLANE_SCRIPTS="user-sudoers directories kubectl certificates-generator auth-configurations-generator etcd apiserver controller-manager scheduler cleanup finalize remove-all"

counter=10
for script in $CONTROL_PLANE_SCRIPTS
do
  cp -v controlplane-$script.sh controlplane-$counter-$script.sh
  ((counter+=1))
done


WORKER_SCRIPTS="user-sudoers directories hostname kubectl certificates-generator auth-configurations-generator kubelet kube-proxy"

counter=10
for script in $WORKER_SCRIPTS
do
  cp -v worker-$script.sh worker-$counter-$script.sh
  ((counter+=1))
done