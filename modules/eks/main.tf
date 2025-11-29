########################################################
# Data + locals
########################################################
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  region_nodash = replace(var.region, "-", "")
  name_prefix   = "${var.project}-${var.environment}-${var.component}-${local.region_nodash}"

  base_tags = merge(var.tags, {
    Name        = local.name_prefix
    Project     = var.project
    Environment = var.environment
    Component   = var.component
    ManagedBy   = "terraform"
  })
}

########################################################
# IAM: EKS cluster role
########################################################
resource "aws_iam_role" "cluster" {
  name = "${local.name_prefix}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "cluster_attach" {
  for_each = toset(["AmazonEKSClusterPolicy","AmazonEKSServicePolicy"])
  role = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.key}"
}

########################################################
# IAM: Node group role & policies
########################################################
resource "aws_iam_role" "node_group" {
  name = "${local.name_prefix}-nodegroup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "node_group_worker" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonSSMManagedInstanceCore"
  ])
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.key}"
}

# allow nodes to read SSM params under project/env (optional)
resource "aws_iam_role_policy" "node_ssm" {
  name = "${local.name_prefix}-node-ssm"
  role = aws_iam_role.node_group.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      Resource = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.id}:*:/\"${var.project}/${var.environment}/*\""
    }]
  })
}

########################################################
# EKS Cluster
########################################################
resource "aws_eks_cluster" "this" {
  name     = "${local.name_prefix}-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = var.node_security_group_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = ["api","audit","authenticator","controllerManager","scheduler"]
  tags = local.base_tags

  depends_on = [aws_iam_role_policy_attachment.cluster_attach]
}

########################################################
# Managed Node Group
########################################################
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name_prefix}-nodegroup"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  version         = var.eks_cluster_version

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  instance_types = [var.node_instance_type]

  tags = merge(local.base_tags, { Name = "${local.name_prefix}-nodegroup" })

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker
  ]
}

########################################################
# OIDC Provider (IRSA)
########################################################
# Wait to fetch cluster identity (computed)
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags = local.base_tags
}

########################################################
# EBS CSI addon (managed addon)
########################################################
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"
  tags         = local.base_tags
}

########################################################
# ALB Controller IAM policy + IRSA role
########################################################
resource "aws_iam_policy" "alb_controller" {
  name        = "${local.name_prefix}-alb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/alb-controller-policy.json")
  tags        = local.base_tags
}

resource "aws_iam_role" "alb_controller" {
  name = "${local.name_prefix}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

########################################################
# Cluster Autoscaler IAM policy + IRSA role
########################################################
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${local.name_prefix}-cluster-autoscaler-policy"
  description = "Policy for Cluster Autoscaler"
  policy      = file("${path.module}/cluster-autoscaler-policy.json")
  tags        = local.base_tags
}

resource "aws_iam_role" "cluster_autoscaler" {
  name = "${local.name_prefix}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
        }
      }
    }]
  })

  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "ca_attach" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

########################################################
# Kubernetes provider (exec auth via aws cli) - for local runs
#
# This provider uses the EKS cluster endpoint & CA and uses the
# AWS CLI to obtain tokens during apply via `aws eks get-token`.
########################################################
provider "kubernetes" {
  host = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.region]
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this.name
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}



########################################################
# Kubernetes ServiceAccounts (IRSA) - annotated with role ARNs
########################################################
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
}

resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler.arn
    }
  }
}

########################################################
# Helm releases
# - ALB Controller
# - Cluster Autoscaler
########################################################

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.this.name
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb_controller.metadata[0].name
      }
      region = var.region
      vpcId  = var.vpc_id
    })
  ]

  depends_on = [
    kubernetes_service_account.alb_controller,
    aws_iam_role_policy_attachment.alb_attach
  ]
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      awsRegion = var.region
      autoDiscovery = {
        clusterName = aws_eks_cluster.this.name
      }
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.cluster_autoscaler.metadata[0].name
      }
      rbac = { create = false }
    })
  ]

  depends_on = [
    kubernetes_service_account.cluster_autoscaler,
    aws_iam_role_policy_attachment.ca_attach
  ]
}

########################################################
# End
########################################################
