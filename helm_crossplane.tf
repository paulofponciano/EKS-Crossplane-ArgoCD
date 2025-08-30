resource "helm_release" "crossplane" {
  name             = "crossplane"
  chart            = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  namespace        = "crossplane-system"
  create_namespace = true

  version = "2.0.2"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.karpenter,
    kubectl_manifest.karpenter-nodeclass,
    kubectl_manifest.karpenter-nodepool-default,
    time_sleep.wait_30_seconds_karpenter
  ]
}

resource "kubectl_manifest" "provider_config" {
  yaml_body = <<YAML
apiVersion: aws.m.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: irsa-providerconfig
spec:
  credentials:
    source: IRSA
YAML

  depends_on = [
    helm_release.crossplane,
    helm_release.karpenter,
    time_sleep.wait_30_seconds_karpenter
  ]
}

resource "kubectl_manifest" "deployment_runtime_config" {
  yaml_body = <<YAML
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: irsa-runtimeconfig
spec:
  serviceAccountTemplate:
    metadata:
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.crossplane_providers_role.arn}
YAML

  depends_on = [
    helm_release.crossplane,
    helm_release.karpenter,
    time_sleep.wait_30_seconds_karpenter
  ]
}

data "kubectl_file_documents" "providers_aws_crossplane" {
  content = file("helm/crossplane/provider_aws.yaml")
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
    time_sleep.wait_30_seconds_karpenter,
    kubectl_manifest.provider_config,
    kubectl_manifest.deployment_runtime_config
  ]
}
