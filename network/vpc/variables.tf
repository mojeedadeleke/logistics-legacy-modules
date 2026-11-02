variable "project_name" {
  description = "Name of the project"
  type        = string
}
variable "vpc_cidr" {
  description = "Base CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "AZ names to deploy into, in order - position N here corresponds to position N in the tier's CIDR list below"
  type        = list(string)
}

# NOTE: Adding a new tier means editing four place:
# The validation's tier list, the subnet resources, the ipv6 offset map local and the subnet IDs output.
variable "tier_subnet_cidrs" { # Six CIDRS per tier: four in use plus two spare, as ipv6 offset local does
  description = "Explicit CIDR block per tier, each in one AZ, same order as in var.azs"
  type        = map(list(string))

  validation { #  The subnet resources look up each tier by name.
    # A missing key errors there, and an extra key is silently ignored.
    # Update this validation block as you add new tier

    condition     = toset(keys(var.tier_subnet_cidrs)) == toset(["web", "app", "db", "mgmt", "reserved"])
    error_message = "var.tier_subnet_cidrs must have exactly these keys: web, app, db, mgmt, reserved. If they do already, check the keys in the subnet resources' blocks"
  }

  validation { # "zipmap()" is used in the subnet resources block in main.tf, and this gives clearer error message when the lengths of the two lists aren't identical
    condition = alltrue([
      for cidrs in values(var.tier_subnet_cidrs) : length(cidrs) == length(var.azs)
    ])
    error_message = "Every tier needs exactly one CIDR per AZ in var.azs, so length of CIDR list in each tier in var.tier_subnet must be same as length of var.azs"
  }


  # ----- To avoid errors during apply when creating subnets,
  # most especially if the mistake occurs when the infra is already existing -----

  #validation {   #  Subnets can't be resized in place, so a wrong prefix is painful to undo
  #condition = alltrue([for cidr in flatten(values(var.tier_subnet_cidrs)) : can(cidrhost(cidr, 0)) && endswith(cidr, "/22")])
  #error_message = "Every subnet CIDR must be a valid IPv4 CIDR with a /22 prefix"
  #}    "Its functions are performed by the next validation block (within vpc cidr check)"

  validation { # Why: a subnet outside the VPC range is rejected by AWS only at apply time, which can leave a half-built network.
    condition = alltrue([for cidr in flatten(values(var.tier_subnet_cidrs)) :
      contains(local.vpc_ipv4_slash22_subnet_cidr_blocks_list, cidr) # Lists every /22 the VPC can hold and check membership
    ])
    error_message = "Every subnet CIDR must fall inside var.vpc_cidr"
  }

  validation { # e.g "10.16.5.0/22" isn't on a /22 boundary, so it's almost certainly a typo for an adjacent slot.
    condition = alltrue([
      for cidr in flatten(values(var.tier_subnet_cidrs)) : cidrhost(cidr, 0) == split("/", cidr)[0]
    ])
    error_message = "Each subnet CIDR must start at its network address (i.e CIDR must align to its prefix boundary (e.g., 10.0.4.0/22, not 10.0.5.0/22)"
  }

  validation { # Spots a duplicate CIDR, depends on "/22" validation check
    condition = (
      length(flatten(values(var.tier_subnet_cidrs))) ==
      length(distinct(flatten(values(var.tier_subnet_cidrs))))
    )
    error_message = "Subnet CIDRs overlap. Each CIDR must appear only once across all tiers."
  }
}