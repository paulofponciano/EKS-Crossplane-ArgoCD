resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.2.2"
  namespace        = "argocd"
  create_namespace = true

  set = [
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    }
  ]

  depends_on = [
    aws_eks_node_group.cluster,
    helm_release.karpenter,
    kubectl_manifest.karpenter-nodeclass,
    kubectl_manifest.karpenter-nodepool-default,
    time_sleep.wait_30_seconds_karpenter
  ]
}

resource "kubectl_manifest" "argocd_gw" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: argocd
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
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.argocd
  ]
}

resource "kubectl_manifest" "argocd_virtual_service" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: argocd
  namespace: argocd
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
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.argocd
  ]
}