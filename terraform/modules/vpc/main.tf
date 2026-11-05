# 1. Look up available Availability Zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# 2. Main VPC Resource
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-vpc"
    }
  )
}

# 3. Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw"
    }
  )
}

# 4. Subnets (Computed dynamically across az_count using cidrsubnet)
resource "aws_subnet" "public" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-subnet-${count.index + 1}"
      # Required for AWS Load Balancer Controller to discover public subnets for Internet-facing ALBs
      "kubernetes.io/role/elb" = "1"
    },
    # Conditionally add cluster discovery tag if cluster_name is defined
    var.cluster_name != "" ? { "kubernetes.io/cluster/${var.cluster_name}" = "shared" } : {}
  )
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-subnet-${count.index + 1}"
      # Required for AWS Load Balancer Controller to discover subnets for Internal ALBs
      "kubernetes.io/role/internal-elb" = "1"
    },
    # Conditionally add cluster discovery tag if cluster_name is defined
    var.cluster_name != "" ? { "kubernetes.io/cluster/${var.cluster_name}" = "shared" } : {}
  )
}

# 5. Elastic IP(s) for NAT Gateway(s)
# If single_nat_gateway is true, create only 1 EIP. Otherwise, create one per AZ.
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : var.az_count
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-eip-${count.index + 1}"
    }
  )
}

# 6. NAT Gateway(s) placed in the first public subnet(s)
resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[0].id # Shared NAT lives in public subnet 1; multi-NAT maps 1:1 per AZ index

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-gw-${count.index + 1}"
    }
  )
}

# 7. Route Tables & Routes
# Public Route Table (All public subnets share one route table pointing to IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-rt"
    }
  )
}

# Private Route Table(s)
# If single NAT is used, all private subnets share 1 route table. If multi-NAT, each gets a dedicated table pointing to its local NAT.
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : var.az_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-rt-${count.index + 1}"
    }
  )
}

# 8. Route Table Associations
resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  # Associates with route table index 0 if single NAT, or matches AZ index if multi-NAT
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# 9. Optional S3 Gateway Endpoint (Free service that routes S3 traffic directly inside AWS network, bypassing NAT)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_availability_zones.available.zone_ids[0] != "" ? "us-east-1" : "us-east-1"}.s3" # Automatically adapts to region
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], aws_route_table.private[*].id)

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-s3-endpoint"
    }
  )
}