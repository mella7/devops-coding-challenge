# the eks cluster itself plus one managed node group
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # ebs-csi-driver is what actually lets the mysql pvc in the helm chart get
  # provisioned as a real ebs volume, without it the mysql pod stays pending
  cluster_addons = {
    coredns            = {}
    kube-proxy         = {}
    vpc-cni            = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      # spot is noticeably cheaper than on-demand, fine here since this
      # isn't running anything that needs guaranteed uptime
      capacity_type = "SPOT"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }

  # without this the iam user that ran apply doesn't automatically get
  # cluster-admin, and kubectl/helm afterwards would fail with an auth error
  enable_cluster_creator_admin_permissions = true
}

# chart's mysql-pvc.yaml doesn't set a storageClassName, so this becomes
# the default and gives it real ebs-backed storage
resource "kubernetes_storage_class" "ebs_default" {
  metadata {
    name = "gp3-default"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "gp3"
  }

  depends_on = [module.eks]
}


module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
