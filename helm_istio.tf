resource "helm_release" "istio_base" {
  name             = "istio-base"
  chart            = "base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.20.1"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth
  ]
}

resource "helm_release" "istiod" {
  name             = "istio"
  chart            = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.20.1"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base
  ]
}

resource "helm_release" "istio_ingress" {
  name             = "istio-ingressgateway"
  chart            = "gateway"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.20.1"

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "service.ports[0].name"
    value = "tcp-statusport"
  }

  set {
    name  = "service.ports[0].port"
    value = 15021
  }

  set {
    name  = "service.ports[0].targetPort"
    value = 15021
  }

  set {
    name  = "service.ports[0].nodePort"
    value = 30021
  }

  set {
    name  = "service.ports[0].protocol"
    value = "TCP"
  }

  set {
    name  = "service.ports[1].name"
    value = "http2"
  }

  set {
    name  = "service.ports[1].port"
    value = 80
  }

  set {
    name  = "service.ports[1].targetPort"
    value = 80
  }

  set {
    name  = "service.ports[1].nodePort"
    value = 30080
  }

  set {
    name  = "service.ports[1].protocol"
    value = "TCP"
  }

  set {
    name  = "service.ports[2].name"
    value = "https"
  }

  set {
    name  = "service.ports[2].port"
    value = 443
  }

  set {
    name  = "service.ports[2].targetPort"
    value = 443
  }

  set {
    name  = "service.ports[2].nodePort"
    value = 30443
  }

  set {
    name  = "service.ports[2].protocol"
    value = "TCP"
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod
  ]
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
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod
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
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod
  ]

}

## ISTIO ADDONS WITH INGRESS

data "kubectl_file_documents" "kiali" {
  content = file("istio_addons/kiali.yaml")
}

resource "kubectl_manifest" "kiali" {
  count              = length(data.kubectl_file_documents.kiali.documents)
  yaml_body          = element(data.kubectl_file_documents.kiali.documents, count.index)
  override_namespace = "istio-system"

  depends_on = [
    helm_release.istio_base,
    helm_release.istiod
  ]
}

data "kubectl_file_documents" "prometheus" {
  content = file("istio_addons/prometheus.yaml")
}

resource "kubectl_manifest" "prometheus" {
  count              = length(data.kubectl_file_documents.prometheus.documents)
  yaml_body          = element(data.kubectl_file_documents.prometheus.documents, count.index)
  override_namespace = "istio-system"

  depends_on = [
    helm_release.istio_base,
    helm_release.istiod
  ]
}

data "kubectl_file_documents" "jaeger" {
  content = file("istio_addons/jaeger.yaml")
}

resource "kubectl_manifest" "jaeger" {
  count              = length(data.kubectl_file_documents.jaeger.documents)
  yaml_body          = element(data.kubectl_file_documents.jaeger.documents, count.index)
  override_namespace = "istio-system"

  depends_on = [
    helm_release.istio_base,
    helm_release.istiod
  ]
}

resource "kubectl_manifest" "kiali_gw" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: kiali-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway 
  servers:
  - port:
      number: 443
      name: http
      protocol: HTTP
    hosts:
    - ${var.kiali_virtual_service_host}
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod
  ]

}

resource "kubectl_manifest" "kiali_virtual_service" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: kiali
  namespace: istio-system
spec:
  hosts:
  - ${var.kiali_virtual_service_host}
  gateways:
  - kiali-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: kiali
        port:
          number: 20001
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod
  ]

}

resource "kubectl_manifest" "jaeger_gw" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: jaeger
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway 
  servers:
  - port:
      number: 443
      name: http
      protocol: HTTP
    hosts:
    - ${var.jaeger_virtual_service_host}
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod
  ]

}

resource "kubectl_manifest" "jaeger_virtual_service" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: tracing
  namespace: istio-system
spec:
  hosts:
  - ${var.jaeger_virtual_service_host}
  gateways:
  - jaeger
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: tracing
        port:
          number: 80
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.istiod
  ]

}
