provider "aws" {
  region  = var.region
}

########### DATA SOURCES
data "aws_eks_cluster" "sample-cluster" {
  name = module.eks-sample-cluster.cluster_id
}

data "aws_eks_cluster_auth" "sample-cluster" {
  name = module.eks-sample-cluster.cluster_id
}

data "aws_availability_zones" "available" {
}

#this has to be there, it is the auth token that allows communication with eks-cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.sample-cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.sample-cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.sample-cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}
########### EKS CLUSTER
module "eks-sample-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster-name
  subnets         = module.vpc.private_subnets      
  vpc_id          = module.vpc.vpc_id

  worker_groups = [
    {
      instance_type = "t2.micro"
      asg_max_size  = 5
      asg_min_size  = 1
      asg_desired_capacity = 1
    }
  ]
}

########### VPC MODULE
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = "test-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = false

  public_subnet_tags = {
    "kubernetes.io/cluster/var.cluster-name" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/var.cluster-name" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}