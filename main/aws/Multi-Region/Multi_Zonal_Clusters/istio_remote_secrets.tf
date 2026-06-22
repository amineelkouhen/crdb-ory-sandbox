############################################################
# Istio multi-primary remote-secret exchange
#
# Each cluster's istiod needs a kubeconfig (packaged as a
# Kubernetes secret) for the OTHER cluster so it can discover
# remote services. We generate the secret on each bastion (which
# already has istioctl + kubectl wired up by the multi_region
# bootstrap) and apply it on the peer bastion via SSH piping
# from the operator's machine.
#
# Pre-requisites on the operator's machine:
#   - SSH access to both bastion public IPs (the same key
#     referenced by var.ssh_private_key).
############################################################

resource "null_resource" "istio_remote_secret_r1_to_r2" {
  depends_on = [
    null_resource.wait_for_ory_lbs_r1,
    null_resource.wait_for_ory_lbs_r2,
  ]

  triggers = {
    bastion_r1 = module.bastion-1.public-ip
    bastion_r2 = module.bastion-2.public-ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${module.bastion-1.public-ip} \
        'istioctl create-remote-secret --name=${var.istio_cluster_names[0]}' \
      | ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${module.bastion-2.public-ip} \
        'kubectl apply -f -'
    EOT
  }
}

resource "null_resource" "istio_remote_secret_r2_to_r1" {
  depends_on = [
    null_resource.wait_for_ory_lbs_r1,
    null_resource.wait_for_ory_lbs_r2,
  ]

  triggers = {
    bastion_r1 = module.bastion-1.public-ip
    bastion_r2 = module.bastion-2.public-ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${module.bastion-2.public-ip} \
        'istioctl create-remote-secret --name=${var.istio_cluster_names[1]}' \
      | ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${module.bastion-1.public-ip} \
        'kubectl apply -f -'
    EOT
  }
}
