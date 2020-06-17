variable "region" {

default = "ap-south-1"

}

variable "key" {

 default = "mykey97"

}


provider "aws" {
  region  = var.region
  profile = "root"
}

resource "aws_key_pair" "enter_key_name" {
  key_name   = var.key
  public_key = file("/root/my_project/mykey97.pub")
}

resource "aws_security_group" "cloud-security" {
  name        = "my-cloud-security"
  description = "terraform task"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "my-cloud-security"
  }
}

resource "aws_instance" "my-project-instance" {
  ami             = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        = "mykey97"
  security_groups = ["${aws_security_group.cloud-security.name}"]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/root/my_project/mykey97")
    host        = aws_instance.my-project-instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "MYOS"
  }
}
/*
output "InstanceAZ" {
  value = aws_instance.my-project-instance.availability_zone
}
*/
output "InstancePIP" {
  value = aws_instance.my-project-instance.public_ip
}

resource "aws_ebs_volume" "my-volume" {
  availability_zone = aws_instance.my-project-instance.availability_zone
  size              = 1

  tags = {
    Name = "my-project-volume"
  }
}

/*
output "VolumeInfo" {
  value = aws_ebs_volume.my-volume.id
}
*/
resource "aws_volume_attachment" "my-volume-attach" {
  device_name  = "/dev/sdf"
  volume_id    = aws_ebs_volume.my-volume.id
  instance_id  = aws_instance.my-project-instance.id
  force_detach = true
}

resource "null_resource" "local" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.my-project-instance.public_ip} > publicip.txt"
  }
}

resource "null_resource" "remote" {
  depends_on = [
    aws_volume_attachment.my-volume-attach,
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/root/my_project/mykey97")
    host        = aws_instance.my-project-instance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdb",
      "sudo mount /dev/xvdb /var/www/html",
      "sudo rm -rf /var/www/html/*",
    ]
  }
}
resource "null_resource" "remote-1" {
  depends_on = [
    null_resource.remote,
  ]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/root/my_project/mykey97")
    host        = aws_instance.my-project-instance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo git clone https://github.com/anandtn1997/sample_html.git /var/www/html",
      "sudo systemctl restart httpd",
      "sudo sed -i 's/cfid/${aws_cloudfront_distribution.kvbb_distribution.domain_name}/g' /var/www/html/index.html",
    ]
  }
}
resource "aws_s3_bucket" "mykvbbprojectbucket" {
  bucket = "kvbbbucket"
  acl    = "public-read"

  tags = {
    Name        = "kvbbprojectbucket"
    Environment = "Dev"
  }
}
/*
output "s3" {
  value = aws_s3_bucket.mykvbbprojectbucket.bucket_regional_domain_name
}
*/

resource "aws_s3_bucket_object" "kvbbfileupload" {
  depends_on = [
    aws_s3_bucket.mykvbbprojectbucket
  ]
  bucket = "kvbbbucket"
  acl    = "public-read"
  key    = "image.jpg"
  source = "/root/my_project/images/myimage.jpg"

}
resource "aws_cloudfront_distribution" "kvbb_distribution" {
  origin {
    domain_name = aws_s3_bucket.mykvbbprojectbucket.bucket_regional_domain_name
    origin_id   = "aws_s3_bucket.mykvbbprojectbucket.id"

    custom_origin_config {
      http_port              = 80
      https_port             = 80
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  enabled = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "aws_s3_bucket.mykvbbprojectbucket.id"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
/*
output "CLoudFrontURL" {
  value = aws_cloudfront_distribution.kvbb_distribution.domain_name
}
*/
resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.mykvbbprojectbucket.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
	 {
         "Sid":"AllowPublicRead",
         "Effect":"Allow",
         "Principal": {
            "AWS":"*"
         },
         "Action":"s3:GetObject",
         "Resource":"arn:aws:s3:::kvbbbucket/*"
      }
    ]
}
POLICY
}


resource "null_resource" "local1"  {
depends_on = [
    null_resource.local,
  ]
        provisioner "local-exec" {
            command = "firefox  ${aws_instance.my-project-instance.public_ip}"
        }
}
      
