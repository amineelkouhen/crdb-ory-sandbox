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
  #!/usr/bin/env bash
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
  sudo cp -i $packagename/lib/libgeos.so /usr/local/lib/cockroach/
  sudo cp -i $packagename/lib/libgeos_c.so /usr/local/lib/cockroach/
  sleep 10
  echo "$(date) - ✅ CRDB installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 🛠  Installing GCloud CLI ☁️" >> /home/${var.ssh_user}/prepare_client.log
  yes | sudo snap install google-cloud-cli --classic >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ✅ GCloud CLI installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 🛠  Installing AWS CLI ☁️" >> /home/${var.ssh_user}/prepare_client.log
  yes | sudo snap install aws-cli --classic >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ✅ AWS CLI installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

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
  echo "$(date) - ✅ Docker installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 🛠  Installing Docker Compose" >> /home/${var.ssh_user}/prepare_client.log
  sudo apt update >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo apt -y install docker-compose
  echo "$(date) - ✅ Docker compose installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

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

  echo "$(date) - 📝 Create Ory Hydra Schema" >> /home/${var.ssh_user}/prepare_client.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"DROP DATABASE IF EXISTS hydra; CREATE DATABASE IF NOT EXISTS hydra;\""
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log

  if [ ${length(var.regions)} -ge 3 ]; then
    echo "$(date) - 🌍 Associate Regions for Hydra DB" >> /home/${var.ssh_user}/prepare_client.log
    regions=(${join(" ", var.regions)})
    for i in "$${!regions[@]}"; do
      if [ $i -eq 0 ]; then
        command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE hydra SET PRIMARY REGION '$${regions[$i]}';\""
        sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
      else
        command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE hydra ADD REGION '$${regions[$i]}';\""
        sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
      fi
    done

    echo "$(date) - 🚨 Create SURVIVE REGION FAILURE for Hydra DB" >> /home/${var.ssh_user}/prepare_client.log
    command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE hydra SURVIVE REGION FAILURE;\""
    sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  fi
  echo "$(date) - ✅ Hydra DB is created." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 📝 Create Ory Keto Schema" >> /home/${var.ssh_user}/prepare_client.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"DROP DATABASE IF EXISTS keto; CREATE DATABASE IF NOT EXISTS keto;\""
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log

  if [ ${length(var.regions)} -ge 3 ]; then
    echo "$(date) - 🌍  Associate Regions for Keto DB" >> /home/${var.ssh_user}/prepare_client.log
    regions=(${join(" ", var.regions)})
    for i in "$${!regions[@]}"; do
      if [ $i -eq 0 ]; then
        command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE keto SET PRIMARY REGION '$${regions[$i]}';\""
        sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
      else
        command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE keto ADD REGION '$${regions[$i]}';\""
        sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
      fi
    done

    echo "$(date) - 🚨 Create SURVIVE REGION FAILURE for Keto DB" >> /home/${var.ssh_user}/prepare_client.log
    command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE keto SURVIVE REGION FAILURE;\""
    sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/prepare_client.log
  fi
  echo "$(date) - ✅ Keto DB is created." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 🛠  Install Helm" >> /home/${var.ssh_user}/prepare_client.log
  yes | sudo snap install helm --classic >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "$(date) - ✅ Helm installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 👮 Activate Service Account for Ory(OEL)" >> /home/${var.ssh_user}/prepare_client.log
  sudo gcloud auth activate-service-account --key-file='/home/${var.ssh_user}/credentials.json' >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - ➕ Add Ory (OEL) repository" >> /home/${var.ssh_user}/prepare_client.log
  yes | sudo gcloud auth configure-docker europe-docker.pkg.dev >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - ➕ Add Ory Helm Repository" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'helm repo add ory https://k8s.ory.sh/helm/charts' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c 'helm repo update' >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - ☸️  Connect Kubectl to EKS Cluster" >> /home/${var.ssh_user}/prepare_client.log
  export AWS_CONFIG_FILE=/home/${var.ssh_user}/.aws/config
  export AWS_SHARED_CREDENTIALS_FILE=/home/${var.ssh_user}/.aws/credentials
  echo "export AWS_CONFIG_FILE=/home/${var.ssh_user}/.aws/config" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "export AWS_CONFIG_FILE=/home/${var.ssh_user}/.aws/config" >> /home/${var.ssh_user}/.bashrc
  echo "export AWS_SHARED_CREDENTIALS_FILE=/home/${var.ssh_user}/.aws/credentials" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "export AWS_SHARED_CREDENTIALS_FILE=/home/${var.ssh_user}/.aws/credentials" >> /home/${var.ssh_user}/.bashrc

  sudo -H -u ${var.ssh_user} bash -c 'aws eks --region ${var.regions[0]} update-kubeconfig --name ${var.k8s_cluster_name}' >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - ✏️  Setting the CRDB endpoint in Helm Charts" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's/\$${CRDB_FQDN}/${var.cluster_fqdn}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${CRDB_FQDN}/${var.cluster_fqdn}/' /home/${var.ssh_user}/values_keto.yaml

  echo "$(date) - ✏️  Setting the repositoy images/releases in Helm Charts" >> /home/${var.ssh_user}/prepare_client.log

  sudo sed -i 's@$${IMAGE}@'"${var.hydra_image}"'@' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${RELEASE}/${var.hydra_release}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's@$${IMAGE}@'"${var.keto_image}"'@' /home/${var.ssh_user}/values_keto.yaml
  sudo sed -i 's/\$${RELEASE}/${var.keto_release}/' /home/${var.ssh_user}/values_keto.yaml

  echo "$(date) - ✏️  Setting the ports in Helm Charts" >> /home/${var.ssh_user}/prepare_client.log
  sudo sed -i 's/\$${ADMIN_PORT}/${var.hydra_admin_port}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${PUBLIC_PORT}/${var.hydra_public_port}/' /home/${var.ssh_user}/values_hydra.yaml
  sudo sed -i 's/\$${READ_PORT}/${var.keto_read_port}/' /home/${var.ssh_user}/values_keto.yaml
  sudo sed -i 's/\$${WRITE_PORT}/${var.keto_write_port}/' /home/${var.ssh_user}/values_keto.yaml

  sleep 10

  echo "$(date) - ☸️  Creating EKS Ory Namespace" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'kubectl create namespace ory --dry-run=client -o yaml | kubectl apply -f -' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c 'kubectl config set-context --current --namespace ory' >> /home/${var.ssh_user}/prepare_client.log 2>&1

  bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.3.0
  sudo mv ./hydra /usr/local/bin/
  echo "$(date) - ✅ Hydra CLI installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . kratos v1.3.1
  sudo mv ./kratos /usr/local/bin/
  echo "$(date) - ✅ Kratos CLI installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . keto v0.14.0
  sudo mv ./keto /usr/local/bin/
  echo "$(date) - ✅ Keto CLI installation completed." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 📦 Deploy Hydra in EKS ☸️" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'kubectl create secret docker-registry ory-oel-gcr-secret --docker-server=europe-docker.pkg.dev --docker-username=_json_key --docker-password="$(cat /home/${var.ssh_user}/credentials.json)" --namespace ory --dry-run=client -o yaml | kubectl apply -f -' >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo -H -u ${var.ssh_user} bash -c 'helm upgrade --install ory-oel-hydra ory/hydra --namespace ory -f /home/${var.ssh_user}/values_hydra.yaml' >> /home/${var.ssh_user}/prepare_client.log 2>&1

  sleep 20
  admin_hostname=$(kubectl get svc --namespace ory ory-oel-hydra-admin --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  public_hostname=$(kubectl get svc --namespace ory ory-oel-hydra-public --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  echo "⏳ Waiting for Hydra API to respond..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  until curl -sf http://$admin_hostname:${var.hydra_admin_port}/health/alive > /dev/null; do
    echo "⌛ Still waiting for Hydra API..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
    sleep 10
  done

  echo "$(date) - ✏️  Setting Hydra environment variables" >> /home/${var.ssh_user}/prepare_client.log

  export HYDRA_ADMIN_URL=http://$admin_hostname:${var.hydra_admin_port}
  export HYDRA_PUBLIC_URL=http://$public_hostname:${var.hydra_public_port}
  echo "export HYDRA_ADMIN_URL=http://$admin_hostname:${var.hydra_admin_port}" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "export HYDRA_ADMIN_URL=http://$admin_hostname:${var.hydra_admin_port}" >> /home/${var.ssh_user}/.bashrc
  echo "export HYDRA_PUBLIC_URL=http://$public_hostname:${var.hydra_public_port}" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "export HYDRA_PUBLIC_URL=http://$public_hostname:${var.hydra_public_port}" >> /home/${var.ssh_user}/.bashrc
  sudo source /home/${var.ssh_user}/.bashrc

  echo "✅ Hydra API is up." >> /home/${var.ssh_user}/prepare_client.log 2>&1

  echo "$(date) - 📦 Deploy Keto in EKS ☸️" >> /home/${var.ssh_user}/prepare_client.log
  sudo -H -u ${var.ssh_user} bash -c 'helm upgrade --install ory-keto ory/keto -f /home/${var.ssh_user}/values_keto.yaml --namespace ory' >> /home/${var.ssh_user}/prepare_client.log 2>&1

  sleep 20
  read_hostname=$(kubectl get svc --namespace ory ory-keto-read --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  write_hostname=$(kubectl get svc --namespace ory ory-keto-write --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")

  echo "⏳ Waiting for Keto API to respond..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
  until curl -sf http://$read_hostname:${var.keto_read_port}/health/alive > /dev/null; do
    echo "⌛ Still waiting for Keto API..." >> /home/${var.ssh_user}/prepare_client.log 2>&1
    sleep 10
  done

  echo "$(date) - ✏️  Setting Keto environment variables" >> /home/${var.ssh_user}/prepare_client.log

  export KETO_WRITE_REMOTE=http://$write_hostname:${var.keto_write_port}
  export KETO_READ_REMOTE=http://$read_hostname:${var.keto_read_port}
  echo "export KETO_WRITE_REMOTE=http://$write_hostname:${var.keto_write_port}" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "export KETO_WRITE_REMOTE=http://$write_hostname:${var.keto_write_port}" >> /home/${var.ssh_user}/.bashrc
  echo "export KETO_READ_REMOTE=http://$read_hostname:${var.keto_read_port}" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  echo "export KETO_READ_REMOTE=http://$read_hostname:${var.keto_read_port}" >> /home/${var.ssh_user}/.bashrc
  eval "$(cat /home/${var.ssh_user}/.bashrc | tail -n +10)"

  echo "✅ Keto API is up." >> /home/${var.ssh_user}/prepare_client.log 2>&1

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