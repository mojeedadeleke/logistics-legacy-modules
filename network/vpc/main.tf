resource "aws_vpc" "log_legacy_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_vpc_ipv6_cidr_block_association" "log_legacy_vpc_ipv6_cidr" {
  vpc_id                           = aws_vpc.log_legacy_vpc.id
  assign_generated_ipv6_cidr_block = true
}

resource "aws_internet_gateway" "log_legacy_igw" {
  vpc_id = aws_vpc.log_legacy_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "web" {
  for_each = zipmap(var.azs, var.tier_subnet_cidrs["web"])

  vpc_id            = aws_vpc.log_legacy_vpc.id
  availability_zone = each.key
  cidr_block        = each.value

  # Derive ipv6 /64 subnets from amazon provided /56 
  # with "cidrsubnet(base_cidr, newbit, netnum)" function
  ipv6_cidr_block = cidrsubnet(
    aws_vpc_ipv6_cidr_block_association.log_legacy_vpc_ipv6_cidr.ipv6_cidr_block,
    8,
    local.ipv6_tier_offsets["web"] + index(var.azs, each.key)
  )

  assign_ipv6_address_on_creation = true

  map_public_ip_on_launch = true # i.e, only the internet-facing tier

  tags = {
    Name = "${var.project_name}-${each.key}-web-subnet"
    Tier = "web"
  }
}

resource "aws_subnet" "app" {
  for_each = zipmap(var.azs, var.tier_subnet_cidrs["app"])

  vpc_id            = aws_vpc.log_legacy_vpc.id
  availability_zone = each.key
  cidr_block        = each.value

  ipv6_cidr_block = cidrsubnet(
    aws_vpc_ipv6_cidr_block_association.log_legacy_vpc_ipv6_cidr.ipv6_cidr_block,
    8,
    local.ipv6_tier_offsets["app"] + index(var.azs, each.key)
  )

  assign_ipv6_address_on_creation = true

  tags = {
    Name = "${var.project_name}-${each.key}-app-subnet"
    Tier = "app"
  }
}

resource "aws_subnet" "db" {
  for_each = zipmap(var.azs, var.tier_subnet_cidrs["db"])

  vpc_id            = aws_vpc.log_legacy_vpc.id
  availability_zone = each.key
  cidr_block        = each.value

  ipv6_cidr_block = cidrsubnet(
    aws_vpc_ipv6_cidr_block_association.log_legacy_vpc_ipv6_cidr.ipv6_cidr_block,
    8,
    local.ipv6_tier_offsets["db"] + index(var.azs, each.key)
  )

  assign_ipv6_address_on_creation = true

  tags = {
    Name = "${var.project_name}-${each.key}-db-subnet"
    Tier = "db"
  }
}

resource "aws_subnet" "mgmt" {
  for_each = zipmap(var.azs, var.tier_subnet_cidrs["mgmt"])

  vpc_id            = aws_vpc.log_legacy_vpc.id
  availability_zone = each.key
  cidr_block        = each.value

  ipv6_cidr_block = cidrsubnet(
    aws_vpc_ipv6_cidr_block_association.log_legacy_vpc_ipv6_cidr.ipv6_cidr_block,
    8,
    local.ipv6_tier_offsets["mgmt"] + index(var.azs, each.key)
  )

  assign_ipv6_address_on_creation = true

  tags = {
    Name = "${var.project_name}-${each.key}-mgmt-subnet"
    Tier = "mgmt"
  }
}

# Do not allocate anything into Reserved subnet yet, add another tier if needed
resource "aws_subnet" "reserved" {
  for_each = zipmap(var.azs, var.tier_subnet_cidrs["reserved"])

  vpc_id            = aws_vpc.log_legacy_vpc.id
  availability_zone = each.key
  cidr_block        = each.value

  ipv6_cidr_block = cidrsubnet(
    aws_vpc_ipv6_cidr_block_association.log_legacy_vpc_ipv6_cidr.ipv6_cidr_block,
    8,
    local.ipv6_tier_offsets["reserved"] + index(var.azs, each.key)
  )

  assign_ipv6_address_on_creation = true

  tags = {
    Name = "${var.project_name}-${each.key}-reserved-subnet"
    Tier = "reserved"
  }
}

# Bring the default route table under Terraform management,
# for the safety of the private subnets from being exposed to internet
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.log_legacy_vpc.default_route_table_id # This is the ID of the VPC default route table, so Terraform adopts it instead of creating a new one
  route                  = []                                            # (The default local route survives this) declare "no routes", so a hand-added internet route shows as drift and is removed on apply

  tags = {
    Name = "${var.project_name}-main-rt-locked"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.log_legacy_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.log_legacy_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.log_legacy_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "web_public_rt" {
  for_each = aws_subnet.web

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}



resource "aws_network_acl" "log_legacy_web_subnets_nacl" {
  vpc_id     = aws_vpc.log_legacy_vpc.id
  subnet_ids = values(aws_subnet.web)[*].id

  # ----- Inbound -----

  # HTTP from all ipv4
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # HTTPS from all ipv4
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # HTTP from all ipv6
  ingress {
    rule_no         = 120
    protocol        = "tcp"
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 80
    to_port         = 80
  }

  # HTTPS from all ipv6
  ingress {
    rule_no         = 130
    protocol        = "tcp"
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 443
    to_port         = 443
  }

  # Ephemeral ports of responses to outbound connections (requests), ipv4.
  # i.e, all high ports are open at the NACL layer,
  # the security group is what blocks unsolicited connections
  ingress {
    rule_no    = 150
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Ephemeral ports of responses to outbound connections (requests), ipv6.connection
  # i.e, all high ports are open at the NACL layer,
  # the security group is what blocks unsolicited connections
  ingress {
    rule_no         = 160
    protocol        = "tcp"
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 1024
    to_port         = 65535
  }

  # Path MTU discovery: lets "packet too big" messages on ipv4 reach the server
  # Security group side: No ICMP rule is needed, tracked connections can receive PMTUD responses. -AWS
  ingress {
    rule_no    = 170
    protocol   = "1" # ICMP protocol number
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    icmp_type  = 3 #  "destination unreachable" the "fragmentation needed" subtype, the one PMTUD depends on
    icmp_code  = 4
    to_port = 0
    from_port = 0
  }

  # Path MTU discovery: lets "packet too big" messages on ipv6 reach the server
  # Security group side: No ICMP rule is needed, tracked connections can receive PMTUD responses. -AWS
  ingress {
    rule_no         = 180
    protocol        = "58" # ICMPv6 protocol number
    action          = "allow"
    ipv6_cidr_block = "::/0"
    icmp_type       = 2 #  "packet too big", the ipv6 equivalent
    icmp_code       = 0
    to_port = 0
    from_port = 0
  }

# (No traceroute rule (ICMP Time Exceeded, type 11 code 0): 
# add only if ops needs outbound path diagnosis.)


  # ----- Outbound --------     ALLOW ALL

  # ipv4
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # ipv6
  egress {
    rule_no         = 110
    protocol        = "-1"
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
  }


  tags = {
    Name = "${var.project_name}-web-subnets-nacl"
  }
}


