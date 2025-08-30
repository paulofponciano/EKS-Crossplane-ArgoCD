resource "helm_release" "prometheus" {
  name             = "prometheus"
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  namespace        = "prometheus"
  create_namespace = true

  version = "75.4.0"

  values = [
    "${file("./helm/prometheus/values.yaml")}"
  ]


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

resource "kubectl_manifest" "prometheus_all_pod_monitor" {

  count = 0

  yaml_body = <<YAML
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: generic-stats-monitor
  namespace: prometheus
  labels:
    monitoring: istio-proxies
    release: istio
spec:
  selector:
    matchExpressions:
    - {key: istio-prometheus-ignore, operator: DoesNotExist}
  namespaceSelector:
    any: true
  jobLabel: generic-stats
  podMetricsEndpoints:
  - path: /metrics
    interval: 15s
    relabelings:
    - action: keep
YAML

  depends_on = [
    helm_release.prometheus
  ]
}

resource "kubectl_manifest" "grafana_gateway" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: grafana-gateway
  namespace: prometheus
spec:
  selector:
    istio: ingressgateway
  servers:
    - hosts:
        - ${var.grafana_virtual_service_host}
      port:
        name: https-workloads
        number: 443
        protocol: HTTP
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.prometheus,
    helm_release.karpenter,
    time_sleep.wait_30_seconds_karpenter
  ]

}

resource "kubectl_manifest" "grafana_service" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: grafana
  namespace: prometheus
spec:
  gateways:
    - grafana-gateway
  hosts:
    - ${var.grafana_virtual_service_host}
  http:
    - route:
        - destination:
            host: prometheus-grafana.prometheus.svc.cluster.local
            port:
              number: 80
          weight: 100
YAML

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster,
    kubernetes_config_map.aws-auth,
    helm_release.istio_base,
    helm_release.prometheus,
    helm_release.karpenter,
    time_sleep.wait_30_seconds_karpenter
  ]

}
