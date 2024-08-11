# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      },
    ],
  })

  tags = {
    Name = "ec2-role"
  }
}

# Data source for the SSM Managed Instance Core Policy
data "aws_iam_policy" "ssm_managed_instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Data source for the SNS Publish Policy
data "aws_iam_policy" "sns_publish" {
  arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Attach the Policies to the Role
resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn  = data.aws_iam_policy.ssm_managed_instance_core.arn
}

resource "aws_iam_role_policy_attachment" "attach_sns_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn  = data.aws_iam_policy.sns_publish.arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}
