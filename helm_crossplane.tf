resource "helm_release" "crossplane" {
  name             = "crossplane"
  namespace        = "crossplane-system"
  create_namespace = true
  chart            = "./helm/crossplane"

  depends_on = [
    aws_eks_node_group.cluster,
    helm_release.karpenter,
    kubectl_manifest.karpenter-nodeclass,
    kubectl_manifest.karpenter-nodepool-default,
    time_sleep.wait_30_seconds_karpenter
  ]
}

data "kubectl_file_documents" "providers_aws_crossplane" {
  content = file("crossplane_provider/provider_aws.yaml")
}

resource "kubectl_manifest" "providers_aws_crossplane" {
  count              = length(data.kubectl_file_documents.providers_aws_crossplane.documents)
  yaml_body          = element(data.kubectl_file_documents.providers_aws_crossplane.documents, count.index)
  override_namespace = "crossplane-system"

  depends_on = [
    aws_eks_node_group.cluster,
    helm_release.karpenter,
    kubectl_manifest.karpenter-nodeclass,
    kubectl_manifest.karpenter-nodepool-default,
    helm_release.crossplane,
    time_sleep.wait_30_seconds_karpenter
  ]
}