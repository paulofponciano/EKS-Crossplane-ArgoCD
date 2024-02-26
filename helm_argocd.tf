data "kubectl_file_documents" "argocd_ns" {
  content = file("argocd/argocd_ns.yaml")
}

data "kubectl_file_documents" "argocd" {
  content = file("argocd/argocd_install.yaml")
}

data "kubectl_file_documents" "image_updater" {
  content = file("argocd/argocd_image_updater.yaml")
}

resource "kubectl_manifest" "argocd_ns" {
  count              = length(data.kubectl_file_documents.argocd_ns.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd_ns.documents, count.index)
  override_namespace = "argocd"

  depends_on = [
    aws_eks_node_group.cluster,
    helm_release.karpenter,
    kubectl_manifest.karpenter_provisioner,
    kubectl_manifest.karpenter_nodetemplate
  ]
}

resource "kubectl_manifest" "argocd" {
  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd.documents, count.index)
  override_namespace = "argocd"

  depends_on = [
    kubectl_manifest.argocd_ns
  ]
}

resource "kubectl_manifest" "image_updater" {
  count              = length(data.kubectl_file_documents.image_updater.documents)
  yaml_body          = element(data.kubectl_file_documents.image_updater.documents, count.index)
  override_namespace = "argocd"

  depends_on = [
    kubectl_manifest.argocd_ns
  ]
}

resource "kubectl_manifest" "argocd_gw" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: argocd-gateway
spec:
  selector:
    istio: ingressgateway 
  servers:
  - port:
      number: 443
      name: http
      protocol: HTTP
    hosts:
    - ${var.argocd_virtual_service_host}
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod,
    kubectl_manifest.argocd
  ]
}

resource "kubectl_manifest" "argocd_virtual_service" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: argocd
spec:
  hosts:
  - ${var.argocd_virtual_service_host}
  gateways:
  - argocd-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: argocd-server.argocd.svc.cluster.local
        port:
          number: 80
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod,
    kubectl_manifest.argocd
  ]
}
