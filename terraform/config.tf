provider "aws" {
  region = "us-east-1"
}

module "eks" {
  source         = "terraform-aws-modules/eks/aws"
  cluster_name   = "Test-Green-Cluster-ten"
  cluster_version = "1.28"

  vpc_id = "vpc-0fe2c01a1360765e3"
  subnet_ids = ["subnet-07016ef218378d92f", "subnet-0f6c2f95e7ba90911", "subnet-074cf248e712ccbb5", "subnet-03eeb45e200a89454"]  # Specify your VPC subnets

  eks_managed_node_groups = {
    six = {
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

resource "aws_eks_access_entry" "ten" {
  cluster_name = "Test-Green-Cluster-ten"
  principal_arn = "arn:aws:iam::877258856486:user/leadalign-eks-master"
  type="STANDARD"
}

