module "sg_alb" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.2"

  name        = "alb"
  description = "SG for Appplication balancer - HTTP allowed"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP for ALB"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS for ALB"
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      cidr_blocks = "0.0.0.0/0"
      description = "Allow outgoing traffic"
    }
  ]
}

resource "aws_alb_target_group" "nginx_ingress" {
  #checkov:skip=CKV_AWS_378: HTTP is used between ALB and backend, HTTPS terminates at ALB
  name_prefix = "nginx"
  port        = local.nginx_ingress_ports["http"]
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    path                = "/healthz"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

module "elb_logs" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.10.1"

  bucket = "${var.name_prefix}-elb-logs"
  acl    = "log-delivery-write"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  # Allow deletion of non-empty bucket
  force_destroy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        // sse-kms is not supported for ELB logs delivery
        // https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
        sse_algorithm = "AES256"
      }
    }
  }

  attach_elb_log_delivery_policy = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  attach_deny_insecure_transport_policy = true
}

resource "aws_alb" "nginx_ingress" {
  #checkov:skip=CKV2_AWS_28: do we need WAF? TODO!
  #checkov:skip=CKV_AWS_150: "Ensure that Load Balancer has deletion protection enabled": we don't want this here because we want to be able to destroy the whole stack
  name               = "nginx-ingress"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [module.sg_alb.security_group_id]

  access_logs {
    bucket  = module.elb_logs.s3_bucket_id
    prefix  = "alb"
    enabled = true
  }

  enable_deletion_protection = false // you probably want this to be `true`

  drop_invalid_header_fields = true
}

resource "aws_alb_listener" "nginx_ingress" {
  load_balancer_arn = aws_alb.nginx_ingress.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.nginx_ingress.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = module.certificate.certificate_arn

  // Standard SSL policy on AWS ELB is too permissive and does not comply with Forward Secrecy.
  // [Forward Secrecy](https://aws.amazon.com/about-aws/whats-new/2019/10/application-load-balancer-and-network-load-balancer-add-new-security-policies-for-forward-secrecy-with-more-strigent-protocols-and-ciphers/).
  // Complete list of TLS protocols and ciphers supported by that policy can be found on [AWS documentation page](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/create-tls-listener.html).
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  #   default_action {
  #     type             = "forward"
  #     target_group_arn = aws_alb_target_group.nginx_ingress.arn
  #   }

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "404"
    }
  }
}

resource "aws_alb_listener_rule" "nginx_ingress" {
  listener_arn = aws_alb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.nginx_ingress.arn
  }

  condition {
    host_header {
      values = [var.dns_zone_suffix, "*.${var.dns_zone_suffix}"]
    }
  }
}
