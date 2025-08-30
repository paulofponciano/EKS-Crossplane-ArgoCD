## ALB INGRESS CONTROLLER

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
  name               = join("-", ["role", var.cluster_name, var.environment, "alb-controller"])
}

data "aws_iam_policy_document" "aws_load_balancer_controller_policy" {
  version = "2012-10-17"

  statement {

    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]

    resources = [
      "*"
    ]

  }

  statement {

    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]

    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    ]

  }

  statement {

    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]

    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]

  }

}

resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name        = join("-", ["policy", var.cluster_name, var.environment, "alb-controller"])
  path        = "/"
  description = var.cluster_name

  policy = data.aws_iam_policy_document.aws_load_balancer_controller_policy.json
}

resource "aws_iam_policy_attachment" "aws_load_balancer_controller_policy" {
  name = "aws_load_balancer_controller_policy"

  roles = [aws_iam_role.alb_controller.name]

  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
}

## NODES

data "aws_iam_policy_document" "eks_nodes_role" {

  version = "2012-10-17"

  statement {

    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }

  }

}

resource "aws_iam_role" "eks_nodes_roles" {
  name               = join("-", ["role", var.cluster_name, var.environment, "eks-nodes"])
  assume_role_policy = data.aws_iam_policy_document.eks_nodes_role.json
}

resource "aws_iam_role_policy_attachment" "cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes_roles.name
}

resource "aws_iam_role_policy_attachment" "node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes_roles.name
}

resource "aws_iam_role_policy_attachment" "ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes_roles.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodes_roles.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_nodes_roles.name
}

data "aws_iam_policy_document" "csi_driver" {
  version = "2012-10-17"

  statement {

    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = [
      aws_kms_key.eks.arn
    ]

  }

}

data "aws_iam_policy_document" "csi" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_ebs_csi_driver" {
  name               = "eks-ebs-csi-driver-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.csi.json

  tags = {
    Environment = var.environment
    Project     = var.project
    Terraform   = true
  }
}

resource "aws_iam_role_policy_attachment" "amazon_ebs_csi_driver" {
  role       = aws_iam_role.eks_ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


data "aws_iam_policy_document" "nodes_volume_create" {
  version = "2012-10-17"

  statement {

    effect = "Allow"
    actions = [
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "ec2:AttachVolume",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]

    resources = [
      "*"
    ]

  }
}

resource "aws_iam_policy" "nodes_volume_create" {
  name        = join("-", ["policy", var.cluster_name, var.environment, "nodes-volume-create"])
  path        = "/"
  description = var.cluster_name

  policy = data.aws_iam_policy_document.nodes_volume_create.json
}

resource "aws_iam_policy_attachment" "nodes_volume_create" {
  name = "nodes_volume_create"

  roles = [aws_iam_role.eks_nodes_roles.name]

  policy_arn = aws_iam_policy.nodes_volume_create.arn
}

## CLUSTER

data "aws_iam_policy_document" "eks_cluster_role" {

  version = "2012-10-17"

  statement {

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"
      identifiers = [
        "eks.amazonaws.com",
        "eks-fargate-pods.amazonaws.com"
      ]
    }

  }

}

resource "aws_iam_role" "eks_cluster_role" {
  name               = join("-", ["role", var.cluster_name, var.environment, "eks-cluster"])
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_role.json
}

resource "aws_iam_role_policy_attachment" "eks-cluster-cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-service" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

## KARPENTER CONTROLLER

data "aws_iam_policy_document" "karpenter_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:karpenter"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role_policy.json
  name               = join("-", ["role", var.cluster_name, var.environment, "karpenter"])
}

resource "aws_iam_policy" "karpenter_controller" {
  policy = file("karpenter/karpenter-controller-trust-policy.json")
  name   = join("-", ["policy", var.cluster_name, var.environment, "karpenter"])
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}"
  role = aws_iam_role.eks_nodes_roles.name
}

## IAM EKS Access entry

resource "aws_eks_access_entry" "owner" {
  count         = var.create_cluster_access_entry ? length(var.cluster_role_or_user_arn_access_entry) : 0
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = var.cluster_role_or_user_arn_access_entry[count.index]
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "AmazonEKSClusterAdminPolicy" {
  count         = var.create_cluster_access_entry ? length(var.cluster_role_or_user_arn_access_entry) : 0
  cluster_name  = aws_eks_cluster.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.cluster_role_or_user_arn_access_entry[count.index]

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.owner
  ]
}

## ARGOCD IMAGE UPDATER

data "aws_iam_policy_document" "argocd_image_updater" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:argocd:argocd-image-updater"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "argocd_image_updater" {
  name = join("-", ["role", var.cluster_name, var.environment, "argocd-image-updater"])

  assume_role_policy = data.aws_iam_policy_document.argocd_image_updater.json
  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_access_origination" {
  role       = aws_iam_role.argocd_image_updater.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

## CROSSPLANE IRSA

data "aws_iam_policy_document" "crossplane_providers_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:crossplane-system:provider-aws-rds*",
        "system:serviceaccount:crossplane-system:provider-aws-lambda*",
        "system:serviceaccount:crossplane-system:provider-aws-iam*",
        "system:serviceaccount:crossplane-system:provider-aws-s3*",
        "system:serviceaccount:crossplane-system:provider-aws-apigatewayv2*",
        "system:serviceaccount:crossplane-system:provider-aws-apigateway*",
        "system:serviceaccount:crossplane-system:provider-aws-cloudwatchevents*"
      ]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "crossplane_providers_role" {
  name               = join("-", ["role", var.cluster_name, var.environment, "crossplane-providers"])
  assume_role_policy = data.aws_iam_policy_document.crossplane_providers_assume_role.json
}

resource "aws_iam_role_policy_attachment" "crossplane_providers_cluster_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.crossplane_providers_role.name
}

resource "aws_iam_role_policy_attachment" "crossplane_providers_cluster_rds" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  role       = aws_iam_role.crossplane_providers_role.name
}

resource "aws_iam_role_policy_attachment" "crossplane_providers_cluster_sns" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  role       = aws_iam_role.crossplane_providers_role.name
}

resource "aws_iam_role_policy_attachment" "crossplane_providers_cluster_sqs" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  role       = aws_iam_role.crossplane_providers_role.name
}

resource "aws_iam_role_policy_attachment" "crossplane_providers_cluster_lambda" {
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
  role       = aws_iam_role.crossplane_providers_role.name
}

resource "aws_iam_role_policy_attachment" "crossplane_providers_cluster_s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.crossplane_providers_role.name
}

data "aws_iam_policy_document" "crossplane_providers_cluster_custom_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRoles",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:TagPolicy",
      "iam:ListInstanceProfilesForRole",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:GET",
      "apigateway:DELETE",
      "apigateway:PATCH",
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "events:PutRule",
      "events:DeleteRule",
      "events:DescribeRule",
      "events:EnableRule",
      "events:DisableRule",
      "events:ListRules",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:ListTargetsByRule",
      "events:PutEvents",
      "events:TagResource",
      "events:ListTagsForResource",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "crossplane_providers_cluster_custom_policy" {
  name   = join("-", ["policy", var.cluster_name, var.environment, "crossplane-providers"])
  policy = data.aws_iam_policy_document.crossplane_providers_cluster_custom_policy.json
}

resource "aws_iam_role_policy_attachment" "crossplane_providers_cluster_custom" {
  policy_arn = aws_iam_policy.crossplane_providers_cluster_custom_policy.arn
  role       = aws_iam_role.crossplane_providers_role.name
}
