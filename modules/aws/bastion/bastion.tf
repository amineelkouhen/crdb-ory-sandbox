terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################################################
# Network Interface

resource "aws_network_interface" "nic" {
  subnet_id       = var.subnet
  security_groups = var.security_groups

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client-nic"
  })
}


# Elastic IP to the Network Interface
resource "aws_eip" "eip" {
  network_interface         = aws_network_interface.nic.id
  associate_with_private_ip = aws_network_interface.nic.private_ip
  depends_on                = [aws_instance.bastion]

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client-eip"
  })
}


############################################################
# EC2
resource "aws_instance" "bastion" {
  ami               = var.machine_image 
  instance_type     = var.machine_type
  availability_zone = var.availability_zone
  key_name          = var.ssh_key_name
  depends_on        = [var.dependencies]

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client"
  })

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.nic.id
  }

  user_data_base64 = base64gzip(<<-EOF
#!/bin/bash
  echo "$(date) - 📦 Preparing client" >> /home/${var.ssh_user}/prepare_client.log
  export DEBIAN_FRONTEND=noninteractive
  export TZ="UTC"
  ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
  apt-get -y install vim iotop iputils-ping netcat-openbsd bind9-dnsutils tzdata build-essential autoconf automake libevent-dev pkg-config zlib1g-dev libssl-dev
  dpkg-reconfigure --frontend noninteractive tzdata
  binaries="${var.cockroach_release}"
  filename=$${binaries##*/}
  packagename=$${filename%.*}
  mkdir /home/${var.ssh_user}/install
  echo "$(date) - 📥 Downloading CockroachDB from : " ${var.cockroach_release} >> /home/${var.ssh_user}/prepare_client.log
  wget "${var.cockroach_release}" -P /home/${var.ssh_user}/install
  sudo tar xvf /home/${var.ssh_user}/install/$filename -C /home/${var.ssh_user}/install/
  echo "$(date) - 🛠  Installing CockroachDB 🪳" >> /home/${var.ssh_user}/prepare_client.log
  cd /home/${var.ssh_user}/install
  sudo cp -i $packagename/cockroach /usr/local/bin/
  sudo mkdir -p /usr/local/lib/cockroach
  sudo cp -a $packagename/lib/. /usr/local/lib/cockroach/
  sleep 10
  echo "$(date) - ✅ CRDB installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 🛠  Installing GCloud and AWS CLI ☁️" >> /home/${var.ssh_user}/prepare_client.log
  yes | sudo snap install google-cloud-cli --classic >> /home/${var.ssh_user}/prepare_client.log 2>&1
  yes | sudo snap install aws-cli --classic >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ✅ GCloud & AWS CLI installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  yes | sudo sudo snap install go --classic >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo go get -u golang.org/x/sys
  echo "$(date) - ✅ Golang installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 🛠  Installing Kubectl" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'yes | sudo snap install kubectl --classic' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ✅ Kubectl installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 🛠  Installing Docker 🐳" >> /home/${var.ssh_user}/prepare_client.log
  sudo apt update
  sudo apt -y install apt-transport-https ca-certificates curl software-properties-common
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
  sudo apt -y install docker-ce
  sudo groupadd docker
  sudo usermod -aG docker ${var.ssh_user}
  sudo systemctl restart docker
  sudo chmod 666 /var/run/docker.sock
  sudo apt -y install docker-compose
  echo "$(date) - ✅ Docker installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ⏳ Waiting for CRDB Cluster to respond..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  status_code=$(curl --write-out '%%{http_code}' --silent  --output /dev/null "http://${var.cluster_fqdn}:8080")
  while [ "$status_code" != "200" ]; do
      echo "🔄 Retry in 20 seconds..." >> /home/${var.ssh_user}/prepare_client.log
      sleep 20
      status_code=$(curl --write-out '%%{http_code}' --silent  --output /dev/null "http://${var.cluster_fqdn}:8080")
  done
  echo "$(date) - ✅ CRDB Cluster is Up." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 💰 Configure Cluster's License" >> /home/${var.ssh_user}/prepare_client.log
  name=$${repository##*/}
  foldername=$${name%.*}
  cd /home/${var.ssh_user}/$foldername
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"SET CLUSTER SETTING cluster.organization = '${var.cluster_organization}'\""
  echo "$command" >> /home/${var.ssh_user}/prepare_client.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"SET CLUSTER SETTING enterprise.license = '${var.cluster_license}';\""
  echo "$command" >> /home/${var.ssh_user}/prepare_client.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  echo "$(date) - ✅ CRDB Cluster license is active." >> /home/${var.ssh_user}/prepare_client.log 2>&1
%{ if var.init_schema ~}
  echo "$(date) - 📝 Create Ory Schemas" >> /home/${var.ssh_user}/prepare_client.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"DROP DATABASE IF EXISTS hydra; CREATE DATABASE IF NOT EXISTS hydra;\""
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  echo "$(date) - ✅ Hydra DB is created." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"DROP DATABASE IF EXISTS kratos; CREATE DATABASE IF NOT EXISTS kratos;\""
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  echo "$(date) - ✅ Kratos DB is created." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"DROP DATABASE IF EXISTS keto; CREATE DATABASE IF NOT EXISTS keto;\""
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  echo "$(date) - ✅ Keto DB is created." >> /home/${var.ssh_user}/prepare_client.log 2>&1
%{ endif ~}
%{ if var.multi_region && var.init_schema && var.crdb_multi_region_sql != "" ~}
  echo "$(date) - 🌍 Applying multi-region locality SQL" >> /home/${var.ssh_user}/prepare_client.log
  cat > /home/${var.ssh_user}/multi_region.sql <<'MRSQL'
${var.crdb_multi_region_sql}
MRSQL
  sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/multi_region.sql
  sudo bash -c "cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --file=/home/${var.ssh_user}/multi_region.sql 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  echo "$(date) - ✅ Multi-region locality applied." >> /home/${var.ssh_user}/prepare_client.log 2>&1
%{ endif ~}
%{ if !var.init_schema && var.peer_init_marker_table != "" ~}
  echo "$(date) - ⏳ Waiting for peer bastion to initialize schema (marker: ${var.peer_init_marker_table})..." >> /home/${var.ssh_user}/prepare_client.log
  until sudo bash -c "cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"SELECT 1 FROM ${var.peer_init_marker_table} LIMIT 1\"" >/dev/null 2>&1; do
    echo "🔄 Schema not ready yet, retrying in 15s..." >> /home/${var.ssh_user}/prepare_client.log
    sleep 15
  done
  echo "$(date) - ✅ Peer-initialized schema detected." >> /home/${var.ssh_user}/prepare_client.log 2>&1
%{ endif ~}
  echo "$(date) - 👮 Activate Service Account for Ory(OEL)" >> /home/${var.ssh_user}/prepare_client.log
  sudo gcloud auth activate-service-account --key-file='/home/${var.ssh_user}/credentials.json' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 🛠  Install Helm" >> /home/${var.ssh_user}/prepare_client.log
  yes | sudo snap install helm --classic >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ➕ Add Ory (OEL) repository" >> /home/${var.ssh_user}/prepare_client.log
  yes | sudo gcloud auth configure-docker europe-docker.pkg.dev >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ➕ Add Ory Helm Repository" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'helm repo add ory https://k8s.ory.sh/helm/charts' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c 'helm repo update' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ☸️  Connect Kubectl to EKS Cluster" >> /home/${var.ssh_user}/prepare_client.log
  export AWS_CONFIG_FILE=/home/${var.ssh_user}/.aws/config
  export AWS_SHARED_CREDENTIALS_FILE=/home/${var.ssh_user}/.aws/credentials
  echo "export AWS_CONFIG_FILE=/home/${var.ssh_user}/.aws/config" >> /home/${var.ssh_user}/.bashrc
  echo "export AWS_SHARED_CREDENTIALS_FILE=/home/${var.ssh_user}/.aws/credentials" >> /home/${var.ssh_user}/.bashrc
  sudo -H -u ${var.ssh_user} bash -c 'aws eks --region ${var.regions[0]} update-kubeconfig --name ${var.k8s_cluster_name}' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ✏️  Setting the CRDB endpoint in Helm Charts" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's/\$${CRDB_FQDN}/${var.cluster_fqdn}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${CRDB_FQDN}/${var.cluster_fqdn}/' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's/\$${CRDB_FQDN}/${var.cluster_fqdn}/' /home/${var.ssh_user}/values_keto.yaml
  echo "$(date) - ✏️  Setting the repositoy images/releases in Helm Charts" >> /home/${var.ssh_user}/prepare_client.log
  # Split each *_image (full URL) into registry + repo. The chart templates
  # image as "{{ image.registry }}/{{ image.repository }}", so a full URL in
  # repository would otherwise be prefixed with the chart's default docker.io.
  split_image() {
    case "$1" in
      *.*/*) echo "$${1%%/*}|$${1#*/}" ;;
      *)     echo "docker.io|$1" ;;
    esac
  }
  HYDRA_PAIR=$(split_image '${var.hydra_image}');  HYDRA_REG=$${HYDRA_PAIR%%|*};  HYDRA_REPO=$${HYDRA_PAIR#*|}
  KRATOS_PAIR=$(split_image '${var.kratos_image}'); KRATOS_REG=$${KRATOS_PAIR%%|*}; KRATOS_REPO=$${KRATOS_PAIR#*|}
  KETO_PAIR=$(split_image '${var.keto_image}');    KETO_REG=$${KETO_PAIR%%|*};   KETO_REPO=$${KETO_PAIR#*|}
  sudo sed -i "s@\$${REGISTRY}@$HYDRA_REG@"  /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i "s@\$${IMAGE}@$HYDRA_REPO@"    /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${RELEASE}/${var.hydra_release}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i "s@\$${REGISTRY}@$KRATOS_REG@" /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i "s@\$${IMAGE}@$KRATOS_REPO@"   /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's/\$${RELEASE}/${var.kratos_release}/' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i "s@\$${REGISTRY}@$KETO_REG@"   /home/${var.ssh_user}/values_keto.yaml
  sudo sed -i "s@\$${IMAGE}@$KETO_REPO@"     /home/${var.ssh_user}/values_keto.yaml
  sudo sed -i 's/\$${RELEASE}/${var.keto_release}/' /home/${var.ssh_user}/values_keto.yaml
  echo "$(date) - ✏️  Setting the ports in Helm Charts" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's/\$${ADMIN_PORT}/${var.hydra_admin_port}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${PUBLIC_PORT}/${var.hydra_public_port}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${ADMIN_PORT}/${var.kratos_admin_port}/' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's/\$${PUBLIC_PORT}/${var.kratos_public_port}/' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's/\$${READ_PORT}/${var.keto_read_port}/' /home/${var.ssh_user}/values_keto.yaml
  sudo sed -i 's/\$${WRITE_PORT}/${var.keto_write_port}/' /home/${var.ssh_user}/values_keto.yaml
%{ if var.hydra_issuer_url != "" ~}
  echo "$(date) - 🌐 Setting Hydra issuer URL in Helm values" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's@\$${ISSUER_URL}@${var.hydra_issuer_url}@' /home/${var.ssh_user}/values_hydra.yaml
%{ endif ~}
%{ if var.hydra_system_secret != "" ~}
  echo "$(date) - 🔐 Setting Hydra shared system secret in Helm values" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's@\$${SYSTEM_SECRET}@${var.hydra_system_secret}@' /home/${var.ssh_user}/values_hydra.yaml
%{ endif ~}
%{ if var.kratos_public_base_url != "" ~}
  echo "$(date) - 🌐 Setting Kratos public base URL in Helm values" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's@\$${KRATOS_PUBLIC_BASE_URL}@${var.kratos_public_base_url}@' /home/${var.ssh_user}/values_kratos.yaml
%{ endif ~}
%{ if var.kratos_default_secret != "" ~}
  echo "$(date) - 🔐 Setting Kratos shared default secret in Helm values" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's@\$${KRATOS_DEFAULT_SECRET}@${var.kratos_default_secret}@' /home/${var.ssh_user}/values_kratos.yaml
%{ endif ~}
%{ if var.kratos_cookie_secret != "" ~}
  echo "$(date) - 🔐 Setting Kratos shared cookie secret in Helm values" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's@\$${KRATOS_COOKIE_SECRET}@${var.kratos_cookie_secret}@' /home/${var.ssh_user}/values_kratos.yaml
%{ endif ~}
  sleep 10
%{ if var.multi_region ~}
  echo "$(date) - 🕸️  Installing Istio multi-primary (cluster=${var.istio_cluster_name}, network=${var.istio_network_name})" >> /home/${var.ssh_user}/prepare_client.log
  ISTIO_VERSION=1.22.0
  cd /home/${var.ssh_user}
  sudo -H -u ${var.ssh_user} bash -c "curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo cp /home/${var.ssh_user}/istio-$ISTIO_VERSION/bin/istioctl /usr/local/bin/
  sudo -H -u ${var.ssh_user} bash -c 'kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  cat > /home/${var.ssh_user}/ca-cert.pem <<'CACERT'
${var.istio_root_ca_cert}
CACERT
  cat > /home/${var.ssh_user}/ca-key.pem <<'CAKEY'
${var.istio_root_ca_key}
CAKEY
  sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/ca-cert.pem /home/${var.ssh_user}/ca-key.pem
  sudo chmod 600 /home/${var.ssh_user}/ca-key.pem
  sudo -H -u ${var.ssh_user} bash -c "kubectl create secret generic cacerts -n istio-system \
    --from-file=ca-cert.pem=/home/${var.ssh_user}/ca-cert.pem \
    --from-file=ca-key.pem=/home/${var.ssh_user}/ca-key.pem \
    --from-file=root-cert.pem=/home/${var.ssh_user}/ca-cert.pem \
    --from-file=cert-chain.pem=/home/${var.ssh_user}/ca-cert.pem \
    --dry-run=client -o yaml | kubectl apply -f -" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  cat > /home/${var.ssh_user}/istio-config.yaml <<EOC
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: ory-mesh
      multiCluster:
        clusterName: ${var.istio_cluster_name}
      network: ${var.istio_network_name}
EOC
  sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/istio-config.yaml
  sudo -H -u ${var.ssh_user} bash -c "istioctl install --skip-confirmation -f /home/${var.ssh_user}/istio-config.yaml" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ⏳ Waiting for istiod to be ready before installing east-west gateway" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c "kubectl rollout status deploy/istiod -n istio-system --timeout=300s" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c "kubectl wait --for=condition=Available deploy/istiod -n istio-system --timeout=300s" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c "/home/${var.ssh_user}/istio-$ISTIO_VERSION/samples/multicluster/gen-eastwest-gateway.sh --mesh ory-mesh --cluster ${var.istio_cluster_name} --network ${var.istio_network_name} | istioctl install -y -f -" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 🩹 Forcing explicit proxy image on istio-eastwestgateway (works around 'image: auto' webhook race)" >> /home/${var.ssh_user}/prepare_client.log
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    if sudo -H -u ${var.ssh_user} bash -c "kubectl get deployment istio-eastwestgateway -n istio-system" >/dev/null 2>&1; then break; fi
    sleep 5
  done
  sudo -H -u ${var.ssh_user} bash -c "kubectl set image deployment/istio-eastwestgateway -n istio-system istio-proxy=docker.io/istio/proxyv2:$ISTIO_VERSION" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c "kubectl rollout status deploy/istio-eastwestgateway -n istio-system --timeout=300s" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c "kubectl apply -n istio-system -f /home/${var.ssh_user}/istio-$ISTIO_VERSION/samples/multicluster/expose-services.yaml" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ✅ Istio multi-primary installed." >> /home/${var.ssh_user}/prepare_client.log 2>&1
%{ endif ~}
  echo "$(date) - ☸️  Creating EKS Ory Namespace" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'kubectl create namespace ory --dry-run=client -o yaml | kubectl apply -f -' >> /home/${var.ssh_user}/prepare_client.log 2>&1
%{ if var.multi_region ~}
  sudo -H -u ${var.ssh_user} bash -c 'kubectl label namespace ory istio-injection=enabled --overwrite' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c 'kubectl label namespace ory topology.istio.io/network=${var.istio_network_name} --overwrite' >> /home/${var.ssh_user}/prepare_client.log 2>&1
%{ endif ~}
  sudo -H -u ${var.ssh_user} bash -c 'kubectl config set-context --current --namespace ory' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.3.0
  sudo mv ./hydra /usr/local/bin/
  bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . kratos v1.3.1
  sudo mv ./kratos /usr/local/bin/
  bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . keto v0.14.0
  sudo mv ./keto /usr/local/bin/
  echo "$(date) - 📦 Deploy Hydra in EKS ☸️" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'kubectl create secret docker-registry ory-oel-gcr-secret --docker-server=europe-docker.pkg.dev --docker-username=_json_key --docker-password="$(cat /home/${var.ssh_user}/credentials.json)" --namespace ory --dry-run=client -o yaml | kubectl apply -f -' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c 'helm upgrade --install ory-hydra ory/hydra --namespace ory -f /home/${var.ssh_user}/values_hydra.yaml' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sleep 20
  hydra_admin_hostname=$(kubectl get svc --namespace ory ory-hydra-admin --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  hydra_public_hostname=$(kubectl get svc --namespace ory ory-hydra-public --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  echo "⏳ Waiting for Hydra API to respond..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  until curl -sf http://$hydra_admin_hostname:${var.hydra_admin_port}/health/alive > /dev/null; do
    echo "⌛ Still waiting for Hydra API..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
    sleep 10
  done
  echo "$(date) - ✏️  Setting Hydra environment variables" >> /home/${var.ssh_user}/prepare_client.log
  echo "export HYDRA_ADMIN_URL=http://$hydra_admin_hostname:${var.hydra_admin_port}" >> /home/${var.ssh_user}/.bashrc
  echo "export HYDRA_PUBLIC_URL=http://$hydra_public_hostname:${var.hydra_public_port}" >> /home/${var.ssh_user}/.bashrc
  echo "✅ Hydra API is up." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 📦 Deploy Kratos in EKS ☸️" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'helm upgrade --install ory-kratos ory/kratos --namespace ory -f /home/${var.ssh_user}/values_kratos.yaml' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sleep 20
  kratos_admin_hostname=$(kubectl get svc --namespace ory ory-kratos-admin --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  kratos_public_hostname=$(kubectl get svc --namespace ory ory-kratos-public --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  echo "⏳ Waiting for Kratos API to respond..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  until curl -sf http://$kratos_public_hostname:${var.kratos_public_port}/health/alive > /dev/null; do
    echo "⌛ Still waiting for Kratos API..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
    sleep 10
  done
  echo "$(date) - ✏️  Setting Kratos environment variables" >> /home/${var.ssh_user}/prepare_client.log
  echo "export KRATOS_ADMIN_URL=http://$kratos_admin_hostname:${var.kratos_admin_port}" >> /home/${var.ssh_user}/.bashrc
  echo "export KRATOS_PUBLIC_URL=http://$kratos_public_hostname:${var.kratos_public_port}" >> /home/${var.ssh_user}/.bashrc
  echo "✅ Kratos API is up." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 📦 Deploy Keto in EKS ☸️" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'helm upgrade --install ory-keto ory/keto -f /home/${var.ssh_user}/values_keto.yaml --namespace ory' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sleep 20
  keto_read_hostname=$(kubectl get svc --namespace ory ory-keto-read --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  keto_write_hostname=$(kubectl get svc --namespace ory ory-keto-write --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  echo "⏳ Waiting for Keto API to respond..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  until curl -sf http://$keto_read_hostname:${var.keto_read_port}/health/alive > /dev/null; do
    echo "⌛ Still waiting for Keto API..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
    sleep 10
  done
  echo "$(date) - ✏️  Setting Keto environment variables" >> /home/${var.ssh_user}/prepare_client.log
  echo "export KETO_WRITE_REMOTE=http://$keto_write_hostname:${var.keto_write_port}" >> /home/${var.ssh_user}/.bashrc
  echo "export KETO_READ_REMOTE=http://$keto_read_hostname:${var.keto_read_port}" >> /home/${var.ssh_user}/.bashrc
  eval "$(cat /home/${var.ssh_user}/.bashrc | tail -n +10)"
  echo "✅ Keto API is up." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  ################
  # Clone the demo repository
  echo "$(date) - Clone the workload simulator repository ${var.simulator_repository}" >> /home/${var.ssh_user}/prepare_client.log
  repository="${var.simulator_repository}"
  cd /home/${var.ssh_user}
  command="git clone $repository"
  sudo -H -u ${var.ssh_user} bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$command" >> /home/${var.ssh_user}/prepare_client.log
  echo "$(date) - Prepare config file" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's@$${HYDRA_ADMIN}@'"http://$hydra_admin_hostname:${var.hydra_admin_port}"'@' /home/${var.ssh_user}/crdb-ory-load-test/config/config.yaml
  sudo sed -i 's@$${HYDRA_PUBLIC}@'"http://$hydra_public_hostname:${var.hydra_public_port}"'@' /home/${var.ssh_user}/crdb-ory-load-test/config/config.yaml
  sudo sed -i 's@$${KRATOS_ADMIN}@'"http://$kratos_admin_hostname:${var.kratos_admin_port}"'@' /home/${var.ssh_user}/crdb-ory-load-test/config/config.yaml
  sudo sed -i 's@$${KRATOS_PUBLIC}@'"http://$kratos_public_hostname:${var.kratos_public_port}"'@' /home/${var.ssh_user}/crdb-ory-load-test/config/config.yaml
  sudo sed -i 's@$${KETO_WRITE}@'"http://$keto_write_hostname:${var.keto_write_port}"'@' /home/${var.ssh_user}/crdb-ory-load-test/config/config.yaml
  sudo sed -i 's@$${KETO_READ}@'"http://$keto_read_hostname:${var.keto_read_port}"'@' /home/${var.ssh_user}/crdb-ory-load-test/config/config.yaml
  sleep 5
  cd /home/${var.ssh_user}/crdb-ory-load-test
  sudo -H -u ${var.ssh_user} bash -c 'make clean build' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - 💯 Client setting Completed" >> /home/${var.ssh_user}/prepare_client.log
  EOF
  )

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
  }

  connection {
    host     = self.public_ip
    type     = "ssh"
    user     = var.ssh_user
    agent    = "false"
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source      = "~/.aws"
    destination = "/home/${var.ssh_user}"
  }

  provisioner "file" {
    source      = "./resources/"
    destination = "/home/${var.ssh_user}/"
  }
}