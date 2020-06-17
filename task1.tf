provider "aws" {
  region = "ap-south-1"
  //profile = "deepanshu2"

}
resource "aws_s3_bucket" "s3bucket" {
  bucket = "bucket-from-terraform"
  acl = "private"
  
  tags = {
    Name = "s3bucket"
  }
}
resource "aws_s3_bucket_public_access_block" "s3type" {
  bucket = "${aws_s3_bucket.s3bucket.id}"
  block_public_acls   = true
  block_public_policy = true
}
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  depends_on = [aws_s3_bucket.s3bucket]
}
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3bucket.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [  aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn ]
    }
  }
}
resource "aws_s3_bucket_policy" "policy" {
bucket = aws_s3_bucket.s3bucket.id
policy = data.aws_iam_policy_document.s3_policy.json
}





locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_distribution" "webcloud" {
  origin {
    domain_name = "${aws_s3_bucket.s3bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
    s3_origin_config{
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled = true
  is_ipv6_enabled     = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"
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
resource "null_resource" "wepip"  {
 provisioner "local-exec" {
     command = "echo  ${aws_instance.first_instance.public_ip} > publicip.txt"
   }
}
 






resource "tls_private_key" "mykey" {
  algorithm = "RSA"
}
resource "aws_key_pair" "generated_key" {
  key_name = "my_key"
  public_key = tls_private_key.mykey.public_key_openssh

depends_on = [
   tls_private_key.mykey
        ]
}

resource "local_file" "keyfile" {
  content = tls_private_key.mykey.private_key_pem

 filename = "mykey.pem"
depends_on=[aws_key_pair.generated_key]

         }





resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  /*vpc_id      = "aws_vpc.main.id"*/

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "SSH"
    from_port   =22
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

  tags = {
    Name = "allow_tls1"
  }
}


resource "aws_instance" "first_instance" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  security_groups = [ "allow_tls" ]
  key_name = aws_key_pair.generated_key.key_name

  tags = {
    Name = "myfirstos"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install git httpd php -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo setenforce 0"
     
    ]
  }
 connection {
    type     = "ssh"
    user     = "ec2-user"
     
    private_key = tls_private_key.mykey.private_key_pem
    host     = aws_instance.first_instance.public_ip
  }
 depends_on =[
	local_file.keyfile
	]
}


resource "aws_ebs_volume" "ebs_volume" {
depends_on = [
    aws_instance.first_instance,
  ]
  availability_zone = aws_instance.first_instance.availability_zone
  size              = 1

  tags = {
    Name = "ebs1"
  }
}

resource "aws_volume_attachment" "ebs_att" {
depends_on = [
    aws_ebs_volume.ebs_volume
   ]
  device_name = "/dev/xvdh"
  force_detach = true
  volume_id   = aws_ebs_volume.ebs_volume.id
  instance_id = aws_instance.first_instance.id
}



resource "null_resource" "format_and_mount" {
depends_on = [
    aws_volume_attachment.ebs_att
   ]

    provisioner "remote-exec" {

inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      " sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/dipuyadav/multicloud.git /var/www/html "
    ]

  }
/*connection {                                                                                                        
    type     = "ssh"
    user     = "ec2-user"
     password = file("C:/Users/deepanshu yadav/Downloads/mykey1111.pem")
    private_key  = file("C:/Users/deepanshu yadav/Downloads/mykey1111.pem")
    host     = aws_instance.first_instance.public_ip
  }*/
 connection {
    type     = "ssh"
    user     = "ec2-user"
     
    private_key = tls_private_key.mykey.private_key_pem
    host     = aws_instance.first_instance.public_ip
  }
 /*depends_on =[
	local_file.keyfile
	]*/
 
}





resource "null_resource" "nulllocal1" {
depends_on = [
    null_resource.format_and_mount
      ]
provisioner "local-exec" {
    command = "start chrome www.yahoo.com"
  }
}

