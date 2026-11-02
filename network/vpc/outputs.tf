output "vpc_id" {
  description = "The ID of the VPC of the infrastucture"
  value = aws_vpc.log_legacy_vpc.id
}

# NOTE: "values(map)" returns the items aphabetically ordered
output "subnet_ids_by_tier" {
  description = "Subnet IDs grouped by tier, then by AZ"
  value = {
    web      = { for k, s in aws_subnet.web : k => s.id }
    app      = { for k, s in aws_subnet.app : k => s.id }
    db       = { for k, s in aws_subnet.db : k => s.id }
    mgmt     = { for k, s in aws_subnet.mgmt : k => s.id }
    reserved = { for k, s in aws_subnet.reserved : k => s.id }
  }
}

output "igw_id" {
  description = "An EIP needs an IGW to be associated, so the EC2 EIP takes this IGW ID"  # Not wanting to output (and epose) the whole IGW resource
  value       = aws_internet_gateway.log_legacy_igw.id
}