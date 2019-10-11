data "aws_region" "current" {}

locals {
  manifest_template_dir     = "${path.module}/templates/manifests"
  strategic_merge_patch_dir = "${path.module}/templates/patches-strategic-merge"

  strategic_merge_patch_files = fileset("${local.strategic_merge_patch_dir}", "*")
  json6902_patch_files        = fileset("${path.module}/templates/patches-json6902", "*")
}

resource "local_file" "cluster" {
  content = templatefile("${local.manifest_template_dir}/cluster.yaml", {
    aws_region   = "${data.aws_region.current.name}"
    cluster_name = "${var.cluster_name}"
    ec2_key_pair = "${var.key_pair}"
  })
  filename = "${path.module}/manifests/cluster.yaml"
  file_permission = "0644"
}

resource "local_file" "controlplane_init" {
  content = templatefile("${local.manifest_template_dir}/controlplane-init.yaml", {
    cluster_name               = "${var.cluster_name}"
    controlplane_instance_type = "${var.controlplane_instance_type}"
    ec2_key_pair               = "${var.key_pair}"
    node_name                  = "${element(var.controlplane_nodes, 0)}",
    k8s_version                = "${var.k8s_version}"
    root_device_size           = "${var.root_device_size}"
  })
  filename = "${path.module}/manifests/${element(var.controlplane_nodes, 0)}.yaml"
  file_permission = "0644"
}

resource "local_file" "controlplane_join" {
  for_each = toset(slice(var.controlplane_nodes, 1, length(var.controlplane_nodes)))

  content = templatefile("${local.manifest_template_dir}/controlplane-join.yaml", {
    cluster_name               = "${var.cluster_name}"
    controlplane_instance_type = "${var.controlplane_instance_type}"
    ec2_key_pair               = "${var.key_pair}"
    node_name                  = "${each.value}"
    k8s_version                = "${var.k8s_version}"
    root_device_size           = "${var.root_device_size}"
  })
  filename = "${path.module}/manifests/${each.value}.yaml"
  file_permission = "0644"
}

resource "local_file" "machine_deployment" {
  for_each = var.worker_nodes

  content = templatefile("${local.manifest_template_dir}/machine-deployment.yaml", {
    cluster_name         = "${var.cluster_name}"
    ec2_key_pair         = "${var.key_pair}"
    k8s_version          = "${var.k8s_version}"
    replicas             = "${each.value}"
    root_device_size     = "${var.root_device_size}"
    worker_instance_type = "${var.worker_instance_type}"
    worker_name          = "${each.key}"
  })
  filename = "${path.module}/manifests/machine-deployment-${each.key}.yaml"
  file_permission = "0644"
}

resource "local_file" "base_kustomization" {
  content = templatefile("${local.manifest_template_dir}/base-kustomization.yaml", {
    controlplane_nodes = "${var.controlplane_nodes}"
    worker_nodes       = "${var.worker_nodes}"
  })
  filename = "${path.module}/manifests/kustomization.yaml"
  file_permission = "0644"
}

resource "local_file" "root_kustomization" {
  content = templatefile("${path.module}/templates/root-kustomization.yaml", {
    cluster_name                = "${var.cluster_name}"
    cni                         = "${var.cni}"
    controlplane_nodes          = "${var.controlplane_nodes}"
    strategic_merge_patch_dir   = "${local.strategic_merge_patch_dir}"
    strategic_merge_patch_files = "${local.strategic_merge_patch_files}"
  })
  filename = "${path.module}/kustomization.yaml"
  file_permission = "0644"
}

resource "local_file" "strategic_merge_patches" {
  for_each = local.strategic_merge_patch_files

  content = templatefile("${path.module}/templates/patches-strategic-merge/${each.value}", {
    ami_id                = "${var.ami_id}"
    controlplane_nodes    = "${var.controlplane_nodes}"
    cluster_name          = "${var.cluster_name}"
    k8s_image_repository  = "${var.k8s_image_repository}"
    k8s_version           = "${var.k8s_version}"
    private_subnet_ids    = "${var.private_subnet_ids}"
    security_group_ids    = "${var.security_group_ids}"
    subnet_ids            = "${concat(var.public_subnet_ids, var.private_subnet_ids)}"
    vpc_id                = "${var.vpc_id}"
    worker_nodes          = "${var.worker_nodes}"
  })
  filename = "${path.module}/patches-strategic-merge/${each.value}"
  file_permission = "0644"
}

# For future use
# resource "local_file" "json6902_patches" {
#   for_each = local.json6902_patch_files

#   content = templatefile("${path.module}/templates/patches-json6902/${each.value}", {
#   })
#   filename = "${path.module}/patches-json6902/${each.value}"
#   file_permission = "0644"
# }

resource "local_file" "get_kubeconfig" {
  content = templatefile("${path.module}/templates/get_kubeconfig.sh", {
    cluster_name = "${var.cluster_name}"
    path         = "${abspath(path.root)}"
  })
  filename = "${path.module}/get_kubeconfig.sh"
  file_permission = "0755"
}

resource "local_file" "set_kubeconfig" {
  content = templatefile("${path.module}/templates/set_kubeconfig.sh", {
    cluster_name = "${var.cluster_name}"
    path         = "${abspath(path.root)}"
  })
  filename = "${path.module}/set_kubeconfig.sh"
  file_permission = "0755"
}