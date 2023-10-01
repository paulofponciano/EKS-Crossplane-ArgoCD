resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v0.27.3"
  #version    = "v0.29.2"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  set {
    name  = "settings.aws.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = aws_eks_cluster.eks_cluster.endpoint
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter.name
  }

  set {
    name  = "replicas"
    value = "1"
  }

  depends_on = [aws_eks_node_group.cluster]
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = templatefile(
    "./karpenter/provisioner.yml.tpl", {
      EKS_CLUSTER        = var.cluster_name
      CAPACITY_TYPE      = var.karpenter_capacity_type
      INSTANCE_FAMILY    = var.karpenter_instance_class
      INSTANCE_SIZES     = var.karpenter_instance_size
      AVAILABILITY_ZONES = var.karpenter_azs
  })

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_nodetemplate" {
  yaml_body = templatefile(
    "./karpenter/nodetemplate.yml.tpl", {
      EKS_CLUSTER = var.cluster_name
  })

  depends_on = [
    helm_release.karpenter
  ]
}
