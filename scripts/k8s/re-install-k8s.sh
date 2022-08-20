#!/bin/bash
# https://raw.githubusercontent.com/chengxiangdong/quick-scripts/main/scripts/k8s/re-install-k8s.sh

docker_version=20.10.2
kubernetes_version=1.23.0

echo 'Kernel-release: '`uname -r`
# yum -y update

function echoTitle() {
    echo -e '\n\e[1;32m>> '$1' <<\e[0m\n'
}

echoTitle 'Remove existing docker'
echo 'Installed docker'
echo '==========================================================================================='
yum list installed | grep docker
echo '==========================================================================================='
systemctl stop docker
yum -y remove docker*
yum -y remove docker docker-common docker-selinux docker-engine

set -e

echoTitle 'Install docker '${docker_version}
yum-config-manager --add-repo http://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce-${docker_version} docker-ce-cli-${docker_version}

echoTitle 'Start docker service'
systemctl stop docker && systemctl start docker && systemctl enable docker

echoTitle 'Remove existing kubernetes'
echo 'Installed docker'
echo '==========================================================================================='
yum list installed | grep docker
echo -e '===========================================================================================\n'
yum -y remove kubelet kubeadm kubectl kubernetes*

echoTitle 'Install kubernetes '${kubernetes_version}''
yum -y install kubelet-${kubernetes_version} kubeadm-${kubernetes_version} kubectl-${kubernetes_version}
systemctl enable kubelet && systemctl start kubelet

# echo "source <(kubectl completion bash)" >> ~/.bashrc
# source  ~/.bashrc
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile
source ~/.bash_profile

echoTitle 'Testing docker ${kubernetes_version}'
docker --version
docker run hello-world

echoTitle 'Initialize the master node'
kubeadm reset -f
rm -rf /etc/cni/net.d
rm -rf $HOME/.kube/config
kubeadm init --service-cidr=10.1.0.0/16 --pod-network-cidr=10.244.0.0/16

echoTitle 'Remove taint from master node'
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl get no -o yaml | grep taint -A 5

echoTitle 'Install kube-flannel'
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl get all -A

echoTitle 'All installations are complete.'
echo 
