#!/bin/bash
# https://raw.githubusercontent.com/chengxiangdong/quick-scripts/main/scripts/k8s/install-k8s.sh

k8s_versions=(
"1.23.0"
"1.22.0"
"1.21.0"
"1.20.0"
"1.19.0"
"1.18.0"
)
docker_versions=(
"20.10.2 [v1.21+]"
"18.09.0-3.el7 [v1.18-20]"
"18.06.0.ce-3.el7 [v1.18-20]"
)
# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

function usage() {
  echo "usage:
  -d Docker version, such as 20.10.2.
  -k Kubernetes version, such as 1.23.0.
  -t Node type, master or work node. Valid parameters are m: master, w: work node
  -h help
  "
}

function parse_args() {
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

function valid_params() {
  if [ ! -n "${docker_version}" ]; then
    echo 'Error, invalid parameter, docker_version can not be empty'
    exit -1
  fi
  if [ ! -n "${kubernetes_version}" ]; then
    echo 'Error, invalid parameter, kubernetes_version can not be empty'
    exit -1
  fi

  if [ ${node_type} == 'm' ]; then
    node_type_name='Master Node'
  elif [ ${node_type} == 'w' ]; then
    node_type_name='Work Node'
  else
    echo 'Error, invalid parameter, node_type can only be m or w'
    exit -1
  fi
}

function docker_version_wizard(){
  while true; do
    echo -e "Please select the docker version:"
    for ((i = 1; i <= ${#docker_versions[@]}; i++)); do
      hint="${docker_versions[$i - 1]}"
      echo -e "${green}${i}${plain}) v${hint}"
    done

    read -p "Which version you do not select(Default: v${docker_versions[0]}): " pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Please enter a number"
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#docker_versions[@]} ]]; then
        echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#docker_versions[@]}"
        continue
    fi

    version=${docker_versions[$pick-1]}
    arr=($version)
    docker_version=${arr[0]}
    break
  done
}

function k8s_node_wizard() {
  node_types=(
  "Master Node"
  "Work Node"
  )
  while true; do
    echo -e "Please select the kubernetes node type:"
    for ((i = 1; i <= ${#node_types[@]}; i++)); do
      hint="${node_types[$i - 1]}"
      echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which type you do not select(Default: ${node_types[0]}): " pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
      echo -e "[${red}Error${plain}] Please enter a number"
      continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#node_types[@]} ]]; then
      echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#node_types[@]}"
      continue
    fi
    if [ "${node_types[$pick - 1]}" == 'Master Node' ]; then
      node_type='m'
    elif [ "${node_types[$pick - 1]}" == 'Work Node' ]; then
      node_type='w'
    fi
    break
  done
}

function k8s_version_wizard(){
    while true; do
      echo -e "Please select the kubernetes version:"
      for ((i = 1; i <= ${#k8s_versions[@]}; i++)); do
        hint="${k8s_versions[$i - 1]}"
        echo -e "${green}${i}${plain}) kubernetes v${hint}"
      done
      read -p "Which version you do not select(Default: v${k8s_versions[0]}): " pick
      [ -z "$pick" ] && pick=1
      expr ${pick} + 1 &>/dev/null
      if [ $? -ne 0 ]; then
          echo -e "[${red}Error${plain}] Please enter a number"
          continue
      fi
      if [[ "$pick" -lt 1 || "$pick" -gt ${#k8s_versions[@]} ]]; then
          echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#k8s_versions[@]}"
          continue
      fi
      kubernetes_version=${k8s_versions[$pick-1]}
    break
    done
}

function install_wizard() {
  k8s_node_wizard
  k8s_version_wizard
  docker_version_wizard
}

if [ ! -n "${docker_version}" ] || [ ! -n "${kubernetes_version}" ] || [ ${node_type} == 'm' ]; then
  install_wizard
fi

valid_params

echo -e "
\n\e[1;32m Kubernetes cluster is configured as follows: \e[0m\n
   Kubernetes Version:\e[1;32m v${kubernetes_version} \e[0m
       Docker Version:\e[1;32m v${docker_version} \e[0m
            Node Type:\e[1;32m ${node_type_name}  \e[0m
"
echo -e "\n\e[1;32m Press 'Enter' to continue:\e[0m"
read -p ""

##--------------------------------------------------------

function echoTitle() {
  echo -e '\n\e[1;32m>> '$1' <<\e[0m\n'
}

function uninstall_docker() {
  echoTitle 'Remove existing docker'
  echo 'Installed docker'
  echo '==========================================================================================='
  yum list installed | grep docker
  echo '==========================================================================================='
  systemctl stop docker
  yum -y remove docker*
  yum -y remove docker docker-common docker-selinux docker-engine
}

function install_docker() {
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
  "registry-mirrors": ["https://v16stybc.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
    systemctl daemon-reload && systemctl restart docker

    echoTitle 'Testing docker ${docker_version}'
    docker --version
    docker run hello-world
}

function uninstall_k8s(){
    echoTitle 'Remove existing kubernetes'
    echo 'Installed docker'
    echo '==========================================================================================='
    yum list installed | grep docker
    echo -e '===========================================================================================\n'
    yum -y remove kubelet kubeadm kubectl kubernetes*
}

function install_k8s(){
  echoTitle 'Disable swap'
  tee /etc/sysctl.d/k8s.conf <<-'EOF'
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

  sysctl -p /etc/sysctl.d/k8s.conf

  echoTitle 'Set kubernetes repository'
  tee /etc/yum.repos.d/kubernetes.repo <<-'EOF'
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

  echoTitle 'Install kubernetes '${kubernetes_version}''
  yum -y install kubelet-${kubernetes_version} kubeadm-${kubernetes_version} kubectl-${kubernetes_version}
  systemctl enable kubelet && systemctl start kubelet

  # echo "source <(kubectl completion bash)" >> ~/.bashrc
  # source  ~/.bashrc
  echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >>~/.bash_profile
  source ~/.bash_profile
}

function init_master() {
  echoTitle 'Initialize the master node'
  kubeadm reset -f
  rm -rf /etc/cni/net.d
  rm -rf $HOME/.kube/config
  kubeadm init --service-cidr=10.1.0.0/16 --pod-network-cidr=10.244.0.0/16

  export KUBECONFIG=/etc/kubernetes/admin.conf

  echoTitle 'Remove taint from master node'
  kubectl taint nodes --all node-role.kubernetes.io/master-
  kubectl get no -o yaml | grep taint -A 5

  echoTitle 'Install kube-flannel'
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  kubectl get all -A

  echo
  echo -e "${red}Initialization is complete, please run the following command:${plain}"
  echo 'As a regular user'
  echo -e "${green}    mkdir -p $HOME/.kube${plain}"
  echo -e "${green}    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config${plain}"
  echo -e "${green}    sudo chown $(id -u):$(id -g) $HOME/.kube/config${plain}"
  echo
  echo 'Alternatively, if you are the root user, you can run:'
  echo -e "${green}    export KUBECONFIG=/etc/kubernetes/admin.conf${plain}"
  echo
}

uname -r
# yum -y update

uninstall_docker
kubeadm reset -f
uninstall_k8s

set -e
install_docker
install_k8s
echo

if [ ${node_type} == 'm' ]; then
  init_master
fi

echoTitle 'All installations complete'
echo
