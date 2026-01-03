# resource "kubernetes_config_map_v1" "aws-auth" {
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = <<YAML
# - rolearn: ${aws_iam_role.eks_nodes_roles.arn}
#   username: system:node:{{EC2PrivateDNSName}}
#   groups:
#   - system:bootstrappers
#   - system:nodes
#   - system:node-proxier
# YAML
#   }

#   depends_on = [
#     aws_eks_cluster.eks_cluster
#   ]
# }

resource "null_resource" "update_kubeconfig" {
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.cluster
  ]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region} --alias ${var.cluster_name}"
  }

  triggers = {
    cluster_name     = var.cluster_name
    cluster_endpoint = aws_eks_cluster.eks_cluster.endpoint
    cluster_version  = aws_eks_cluster.eks_cluster.version
  }
}