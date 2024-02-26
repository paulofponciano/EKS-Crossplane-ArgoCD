output "istio_ingress_nlb" {
  value = aws_lb.istio_ingress.dns_name
}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}