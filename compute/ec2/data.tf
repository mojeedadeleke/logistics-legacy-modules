data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "dlm_assume" {
  statement {
    effect = "allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "dlm_role_permissions" {
  statement {
    effect = "allow"
    actions = [
        "ec2:CreateSnapshort", "ec2:CreateSnapshorts", "ec2:DeleteSnapshort",
        "ec2:DescribeVolumes", "ec2:DescribeInstances", "ec2:DescribeSnapshorts",
    ]
    resources = ["*"]  # Why: Describe* calls cannot be scoped to one resource.
  }

  statement {
    effect = "allow"
    actions = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*::snapshot/*"]  # Why: the policy tags the snapshots it creates.
  }
}