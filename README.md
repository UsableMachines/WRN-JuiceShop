# First Step

This manifest will deploy OWASP Juiceshop to AWS infrastructure. 

It's necessary for you to have AWS CLI installed, and an AWS profile configured. If no profile is configured, let's configure one. Have your AWS key and secret handy. Open a terminal and run these commands:

```aws configure --profile PROFILE_NAME```

You will be prompted for a the following:

```AWS access key ID: YOUR_AWS_KEY```

```AWS Secret Access Key: YOUR_AWS_SECRET```

```Default region name: YOUR_DEFAULT_AWS_REGION (e.g. us-east-1)```

```Default output format: JSON```

This README will be using OpenTofu commands, which is a fork of opensource Terraform. If you're using Terraform, simply interchange ```tofu``` commands with ```terraform``` .

# Main.tf Set Up

This will deploy an OWASP Juiceshop docker image from bkimminich/juice-shop to AWS ECS, sitting behind an application load balancer. The main.tf relies on a variables.tf and a terrafrom.tfvars files, plus a S3 bucket for remote state storage.

There is a ```not_tfvars``` file that contains two key/value pairs, ```aws_profile``` and ```aws_shared_credentials_file```. Enter the AWS CLI profile name and the path to the credentials file. In linux and Mac, the default path is ```/home/USER_NAME/.aws/credentials```. With the values updated, rename the file to ```terrafrom.tfvars```. This file will be automatically read by main.tf and consume the variables for the provider and remote state file.

The main.tf is setup to store a remote state file in AWS S3. The name of the bucket is declared in variables.tf file. The variable defaults to a bucket called ```wrn-demo```. Change the bucket name to your bucket name, and ensure that the bucket has appropriate permissions for the remote state file. The permissions can be found in the file ```s3_permissions.json```. The json is structured as an AWS bucket policy and can be copy/pasted to apply only the minimum set of permissions necessary. 

## Ready to Deploy

With the main.tf setup completed, run ```tofu init``` to initialize the manifest. Once initiated, you can plan a deployment to see what resources will be created with ```tofu plan -o=plan```. The command will print to screen the projected resources to be deployed and create a plan file called ' plan'. To deploy from that plan, enter this command: ```tofu apply plan```. Run the command ```tofu show``` after deployment to see what the final URL will be for the Juiceshop. Look for this at the end, 

```Outputs:
Outputs:
juice_shop_url = "http://juice-shop-alb-0000000000.us-east-1.elb.amazonaws.com"
```

The Juiceshop will not be immediately available. Give it a few minutes for post processing and keep refreshing the URL.

# (In)security Design

The infrastructure design has less than ideal security to provide additional attack surfaces for a pen test environment. Here are known vulnerabilities of this deployment from a Trivy scan: 

```AVD-AWS-0053 (HIGH): Load balancer is exposed publicly.
AVD-AWS-0053 (HIGH): Load balancer is exposed publicly.
═════════════════════════════════════════════════════════════════════════════════
There are many scenarios in which you would want to expose a load balancer to the wider internet, but this check exists as a warning to prevent accidental exposure of internal assets. You should ensure that this resource should be exposed publicly.


See https://avd.aquasec.com/misconfig/avd-aws-0053
─────────────────────────────────────────────────────────────────────────────────
 main.tf:117
   via main.tf:115-122 (aws_lb.main)
─────────────────────────────────────────────────────────────────────────────────
 115   resource "aws_lb" "main" {
 116     name               = "juice-shop-alb"
 117 [   internal           = false            
 118     load_balancer_type = "application"
 119     security_groups    = [aws_security_group.alb.id]
 120     subnets           = aws_subnet.public[*].id
 121     drop_invalid_header_fields = true
 122   }
─────────────────────────────────────────────────────────────────────────────────
```

```AVD-AWS-0054 (CRITICAL): Listener for application load balancer does not use HTTPS.
AVD-AWS-0054 (CRITICAL): Listener for application load balancer does not use HTTPS.
═════════════════════════════════════════════════════════════════════════════════
Plain HTTP is unencrypted and human-readable. This means that if a malicious actor was to eavesdrop on your connection, they would be able to see all of your data flowing back and forth.
You should use HTTPS, which is HTTP over an encrypted (TLS) connection, meaning eavesdroppers cannot read your traffic.


See https://avd.aquasec.com/misconfig/avd-aws-0054
─────────────────────────────────────────────────────────────────────────────────
 main.tf:142-151
─────────────────────────────────────────────────────────────────────────────────
 142 ┌ resource "aws_lb_listener" "main" {
 143 │   load_balancer_arn = aws_lb.main.arn
 144 │   port              = "80"
 145 │   protocol          = "HTTP"
 146 │ 
 147 │   default_action {
 148 │     type             = "forward"
 149 │     target_group_arn = aws_lb_target_group.juice_shop.arn
 150 │   }
 151 └ }
─────────────────────────────────────────────────────────────────────────────────
```

```AVD-AWS-0104 (CRITICAL): Security group rule allows egress to multiple public internet addresses.
AVD-AWS-0104 (CRITICAL): Security group rule allows egress to multiple public internet addresses.
═════════════════════════════════════════════════════════════════════════════════
Opening up ports to connect out to the public internet is generally to be avoided. You should restrict access to IP addresses or ranges that are explicitly required where possible.


See https://avd.aquasec.com/misconfig/aws-vpc-no-public-egress-sgr
─────────────────────────────────────────────────────────────────────────────────
 main.tf:87
   via main.tf:82-88 (egress)
    via main.tf:69-89 (aws_security_group.alb)
─────────────────────────────────────────────────────────────────────────────────
  69   resource "aws_security_group" "alb" {
  ..   
  87 [     cidr_blocks = ["0.0.0.0/0"]
  ..   
  89   }
──────────────────────────────────────────────────────────────────────────────────
```

```AVD-AWS-0104 (CRITICAL): Security group rule allows egress to multiple public internet addresses.
AVD-AWS-0104 (CRITICAL): Security group rule allows egress to multiple public internet addresses.
═════════════════════════════════════════════════════════════════════════════════
Opening up ports to connect out to the public internet is generally to be avoided. You should restrict access to IP addresses or ranges that are explicitly required where possible.


See https://avd.aquasec.com/misconfig/aws-vpc-no-public-egress-sgr
─────────────────────────────────────────────────────────────────────────────────
 main.tf:109
   via main.tf:104-110 (egress)
    via main.tf:91-111 (aws_security_group.ecs)
──────────────────────────────────────────────────────────────────────────────────
  91   resource "aws_security_group" "ecs" {
  ..   
 109 [     cidr_blocks = ["0.0.0.0/0"]
 ...   
 111   }
─────────────────────────────────────────────────────────────────────────────────
```

```AVD-AWS-0164 (HIGH): Subnet associates public IP address.
AVD-AWS-0164 (HIGH): Subnet associates public IP address.
═════════════════════════════════════════════════════════════════════════════════
You should limit the provision of public IP addresses for resources. Resources should not be exposed on the public internet, but should have access limited to consumers required for the function of your application.


See https://avd.aquasec.com/misconfig/aws-vpc-no-public-ingress-sgr
─────────────────────────────────────────────────────────────────────────────────
 main.tf:42
   via main.tf:37-47 (aws_subnet.public[0])
─────────────────────────────────────────────────────────────────────────────────
  37   resource "aws_subnet" "public" {
  38     count             = 2
  39     vpc_id            = aws_vpc.main.id
  40     cidr_block        = "10.0.${count.index + 1}.0/24"
  41     availability_zone = data.aws_availability_zones.available.names[count.index]
  42 [   map_public_ip_on_launch = true
  43   
  44     tags = {
  45       Name = "juice-shop-public-${count.index + 1}"
  ..   
─────────────────────────────────────────────────────────────────────────────────
```

```AVD-AWS-0178 (MEDIUM): VPC does not have VPC Flow Logs enabled.
AVD-AWS-0178 (MEDIUM): VPC does not have VPC Flow Logs enabled.
═════════════════════════════════════════════════════════════════════════════════
VPC Flow Logs provide visibility into network traffic that traverses the VPC and can be used to detect anomalous traffic or insight during security workflows.


See https://avd.aquasec.com/misconfig/aws-autoscaling-enable-at-rest-encryption
─────────────────────────────────────────────────────────────────────────────────
 main.tf:27-35
─────────────────────────────────────────────────────────────────────────────────
  27 ┌ resource "aws_vpc" "main" {
  28 │   cidr_block           = "10.0.0.0/16"
  29 │   enable_dns_hostnames = true
  30 │   enable_dns_support   = true
  31 │ 
  32 │   tags = {
  33 │     Name = "juice-shop-vpc" 
  34 │   }
  35 └ }
─────────────────────────────────────────────────────────────────────────────────
```

# Cleaning Up

Deleting the environment is one command: ```tofu destroy```. It will delete all deployed resources from main.tf. You will be prompted to answer yes or no to the deletion.