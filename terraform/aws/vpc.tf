# vpc the eks cluster lives in, sized just big enough for a 2-az cluster
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  # one nat gateway instead of one per az, cuts the hourly cost roughly in half -
  # not what you'd run in prod but fine for a demo cluster
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # eks and the load balancer controller look for these exact tags to know
  # which subnets to use, cluster won't provision load balancers correctly without them
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
