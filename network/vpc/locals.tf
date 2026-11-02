locals {
  ipv6_tier_offsets = { # Six slots per tier, currently using four, two are to accommodate 2 new AZs
    web      = 0
    app      = 6
    db       = 12
    mgmt     = 18
    reserved = 24
  }

  ipv4_slash22_subnet_newbits = 22 - tonumber(split("/", var.vpc_cidr)[1]) # i.e, 22 -16 = 6

  # Lists every /22 the VPC can hold   "cidrsubnets()" returns a list of subnets, one per newbit value
  vpc_ipv4_slash22_subnet_cidr_blocks_list = cidrsubnets(
    var.vpc_cidr,
    [for i in range(pow(2, local.ipv4_slash22_subnet_newbits)) :
    local.ipv4_slash22_subnet_newbits]...
  ) #  "..." unpacks the list of 64 sixes into separate newbit arguments
}