# Launch Template
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-lunar-23.04-amd64-server-*"]
  }
}

resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-launch-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Attach IAM Role to Instance
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  key_name = "solo-access-key" # Replace with your key pair name

  user_data = base64encode(<<-EOF
              #!/bin/bash

              sleep 120
              sudo apt update -y
              sudo apt install python3-pip -y
              sudo apt install git -y
              sudo apt install python3-venv -y
              cd /home/ubuntu
              git clone https://github.com/ooghenekaro/Event-driven-Ecommerce-Ordering-Flask-app-VM.git
              cd Event-driven-Ecommerce-Ordering-Flask-app-VM
              sudo pip3 install -r requirements.txt --break-system-packages
              echo "[Unit]
              Description=Flask Application
              After=network.target

              [Service]
              User=ubuntu
              WorkingDirectory=/home/ubuntu/Event-driven-Ecommerce-Ordering-Flask-app-VM
#              ExecStart=/usr/bin/python3 /home/ubuntu/Event-driven-Ecommerce-Ordering-Flask-app-VM/app.py
              ExecStart=/usr/local/bin/gunicorn -b 0.0.0.0:5000 app:app

              [Install]
              WantedBy=multi-user.target" | sudo tee /etc/systemd/system/ecommerce-app.service

              sudo systemctl daemon-reload
              sudo systemctl start ecommerce-app
              sudo systemctl enable ecommerce-app
              EOF
  )

  network_interfaces {
    security_groups = [aws_security_group.app_sg.id]
    subnet_id       = aws_subnet.private_subnet1.id
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 8
      volume_type = "gp2"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "app-instance"
  }
}

# Autoscaling Group
resource "aws_autoscaling_group" "app_asg" {
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
