resource "helm_release" "istio_base" {
  name             = "istio-base"
  chart            = "base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.25.2"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    helm_release.karpenter,
    time_sleep.wait_30_seconds_karpenter
  ]
}

resource "helm_release" "istiod" {
  name             = "istio"
  chart            = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.25.2"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    helm_release.istio_base,
    helm_release.karpenter,
    time_sleep.wait_30_seconds_karpenter
  ]
}

resource "helm_release" "istio_ingress" {
  name             = "istio-ingressgateway"
  chart            = "gateway"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.25.2"

  set = [
    {
      name  = "service.type"
      value = "NodePort"
    },
    {
      name  = "service.ports[0].name"
      value = "tcp-statusport"
    },
    {
      name  = "service.ports[0].port"
      value = "15021"
    },
    {
      name  = "service.ports[0].targetPort"
      value = "15021"
    },
    {
      name  = "service.ports[0].nodePort"
      value = "30021"
    },
    {
      name  = "service.ports[0].protocol"
      value = "TCP"
    },
    {
      name  = "service.ports[1].name"
      value = "http2"
    },
    {
      name  = "service.ports[1].port"
      value = "80"
    },
    {
      name  = "service.ports[1].targetPort"
      value = "80"
    },
    {
      name  = "service.ports[1].nodePort"
      value = "30080"
    },
    {
      name  = "service.ports[1].protocol"
      value = "TCP"
    },
    {
      name  = "service.ports[2].name"
      value = "https"
    },
    {
      name  = "service.ports[2].port"
      value = "443"
    },
    {
      name  = "service.ports[2].targetPort"
      value = "443"
    },
    {
      name  = "service.ports[2].nodePort"
      value = "30443"
    },
    {
      name  = "service.ports[2].protocol"
      value = "TCP"
    }
  ]

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.karpenter,
    time_sleep.wait_30_seconds_karpenter
  ]
}

resource "time_sleep" "wait_40_seconds_albcontroller" {
  depends_on = [helm_release.alb_ingress_controller]

  create_duration = "40s"
}

resource "kubectl_manifest" "istio_target_group_binding_http" {
  yaml_body = <<YAML
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: istio-ingress
  namespace: istio-system
spec:
  serviceRef:
    name: istio-ingressgateway
    port: http2
  targetGroupARN: ${aws_lb_target_group.http.arn}
YAML


  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.alb_ingress_controller,
    time_sleep.wait_40_seconds_albcontroller,
  ]

}

resource "kubectl_manifest" "istio_target_group_binding_https" {
  yaml_body = <<YAML
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: istio-ingress-https
  namespace: istio-system
spec:
  serviceRef:
    name: istio-ingressgateway
    port: https
  targetGroupARN: ${aws_lb_target_group.https.arn}
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.alb_ingress_controller,
    time_sleep.wait_40_seconds_albcontroller,
  ]

}