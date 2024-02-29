provider "aws" {
  region = "us-east-1"
}

module "eks" {
  source         = "terraform-aws-modules/eks/aws"
  cluster_name   = "Test-Blue-Cluster"
  cluster_version = "1.28"

  vpc_id = "vpc-0fe2c01a1360765e3"
  subnet_ids = ["subnet-07016ef218378d92f", "subnet-0f6c2f95e7ba90911", "subnet-074cf248e712ccbb5", "subnet-03eeb45e200a89454"]  # Specify your VPC subnets

  eks_managed_node_groups = {
    one = {
      desired_capacity = 2
      max_capacity     = 4
      min_capacity     = 1

      instance_type = "t3.medium"
    }
  }
}
