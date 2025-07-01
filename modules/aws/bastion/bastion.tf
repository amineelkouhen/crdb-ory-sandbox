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

  user_data = <<-EOF
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
  sudo sed -i 's@$${IMAGE}@'"${var.hydra_image}"'@' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${RELEASE}/${var.hydra_release}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's@$${IMAGE}@'"${var.kratos_image}"'@' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's/\$${RELEASE}/${var.kratos_release}/' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's@$${IMAGE}@'"${var.keto_image}"'@' /home/${var.ssh_user}/values_keto.yaml
  sudo sed -i 's/\$${RELEASE}/${var.keto_release}/' /home/${var.ssh_user}/values_keto.yaml
  echo "$(date) - ✏️  Setting the ports in Helm Charts" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's/\$${ADMIN_PORT}/${var.hydra_admin_port}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${PUBLIC_PORT}/${var.hydra_public_port}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${ADMIN_PORT}/${var.kratos_admin_port}/' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's/\$${PUBLIC_PORT}/${var.kratos_public_port}/' /home/${var.ssh_user}/values_kratos.yaml
  sudo sed -i 's/\$${READ_PORT}/${var.keto_read_port}/' /home/${var.ssh_user}/values_keto.yaml
  sudo sed -i 's/\$${WRITE_PORT}/${var.keto_write_port}/' /home/${var.ssh_user}/values_keto.yaml
  sleep 10
  echo "$(date) - ☸️  Creating EKS Ory Namespace" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'kubectl create namespace ory --dry-run=client -o yaml | kubectl apply -f -' >> /home/${var.ssh_user}/prepare_client.log 2>&1
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