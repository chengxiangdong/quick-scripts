#!/bin/bash
# https://raw.githubusercontent.com/chengxiangdong/quick-scripts/main/scripts/k8s/re-install-k8s.sh

#!/bin/bash

function usage()
{
    echo "usage:
  -d Docker version, such as 20.10.2.
  -k Kubernetes version, such as 1.23.0.
  -t Node type, master or work node. Valid parameters are m: master, w: work node
  -h help
  "
}

function parse_args()
{
    while getopts "d:k:t:h" OPTION; do
        case $OPTION in
            d)
                docker_version="${OPTARG}"
                ;;
            k)
                kubernetes_version="${OPTARG}"
                ;;
            t)
                node_type="${OPTARG}"
                ;;
            h)
                usage
                exit -1
                ;;
            ?)
                usage
                exit -1
                ;;
        esac
    done
    return 0
}
parse_args $@

if [ ! -n "${docker_version}" ]; then
    echo 'Error, invalid parameter, docker_version can not be empty'
    exit -1
fi
if [ ! -n "${kubernetes_version}" ]; then
    echo 'Error, invalid parameter, kubernetes_version can not be empty'
    exit -1
fi

if [ ${node_type} == 'm' ]; then
    node_type_name='master node'
elif [ ${node_type} == 'w' ]; then
    node_type_name='Work Node'
else
    echo 'Error, invalid parameter, node_type can only be m or w'
    exit -1
fi

echo -e "
\n\e[1;32m Kubernetes cluster is configured as follows: \e[0m\n
   Kubernetes Version:\e[1;32m v${kubernetes_version} \e[0m
   Docker Version:\e[1;32m v${docker_version} \e[0m
   Node Type: \e[1;32m${node_type_name}  \e[0m
"
echo -e "\n\e[1;32m Press 'Enter' to continue:\e[0m"
read -p ""

##--------------------------------------------------------

uname -r
# yum -y update

function echoTitle() {
    echo -e '\n\e[1;32m>> '$1' <<\e[0m\n'
}

echoTitle 'Remove existing docker'
echo 'Installed docker'
echo '==========================================================================================='
yum list installed | grep docker
echo '==========================================================================================='
yum -y remove docker*
yum -y remove docker docker-common docker-selinux docker-engine

set -e

echoTitle 'Install utils'
yum -y install yum-utils device-mapper-persistent-data lvm2

echoTitle 'Install docker '${docker_version}
yum-config-manager --add-repo http://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce-${docker_version} docker-ce-cli-${docker_version} containerd.io

echoTitle 'Start docker service'
systemctl stop docker && systemctl start docker && systemctl enable docker

echoTitle 'Install bash-completion'
yum -y install bash-completion
source /etc/profile.d/bash_completion.sh

echoTitle 'Set daemon.json'
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://0970d7b7d400f2470fbec00316a03560.mirror.swr.myhuaweicloud.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl daemon-reload && systemctl restart docker

echoTitle 'Disable swap'
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/k8s.conf

echoTitle 'Set kubernetes repository'
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://repo.huaweicloud.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://repo.huaweicloud.com/kubernetes/yum/doc/yum-key.gpg https://repo.huaweicloud.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum clean all
yum -y makecache

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

echoTitle 'Testing docker ${docker_version}'
docker --version
docker run hello-world

if [ ${node_type} == 'm' ]; then
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
fi

echoTitle 'All installations are complete.'
echo
