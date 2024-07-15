provider "aws" {
  region = "us-east-1"
}

module "eks" {
  source         = "terraform-aws-modules/eks/aws"
  cluster_name   = "Test-Green-Cluster-nine"
  cluster_version = "1.28"

  vpc_id = "vpc-0fe2c01a1360765e3"
  subnet_ids = ["subnet-07016ef218378d92f", "subnet-0f6c2f95e7ba90911", "subnet-074cf248e712ccbb5", "subnet-03eeb45e200a89454"]  # Specify your VPC subnets

  eks_managed_node_groups = {
    nine = {
      desired_size = 4
      max_size     = 6
      min_size     = 3

      labels = {
        role = "blue-green-node-set"
      }

      instance_types = ["t2.medium"]
      capacity_type = "ON_DEMAND"
    }
  }
}


