provider "aws"{
	access_key = "AKIAW3MEBO3JD7NVYAEK"
	secret_key = "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"
	region = "eu-north-1"
}

resource "aws_vpc" "main_vpc"{
	cidr_block = "10.0.0.0/16"
	tags = {
		Name = "main-vpc"
	}
}

resource "aws_internet_gateway" "igw"{
	vpc_id = aws_vpc.main_vpc.id
	tags = {
		Name = "main-igw"
	}
}

resource "aws_subnet" "public_subnet"{
	vpc_id 					= aws_vpc.main_vpc.id
	cidr_block 				= "10.0.10.0/24"
	availability_zone 		= "eu-north-1a"
	map_public_ip_on_launch = true
	tags = {
	  Name = "public_subnet"
	}
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id 	 		= aws_vpc.main_vpc.id
  cidr_block 		= "10.0.20.0/24"
  availability_zone = "eu-north-1a"
  tags = {
	Name = "public_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id 			= aws_vpc.main_vpc.id
  cidr_block 		= "10.0.30.0/24"
  availability_zone = "eu-north-1b"
  tags = {
	Name = "public_subnet_2"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}


resource "aws_route_table_association" "public_assoc" {
  subnet_id 	 = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat_eip_1" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.private_subnet_1.id
}

resource "aws_eip" "nat_eip_2" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.private_subnet_2.id
}


resource "aws_route_table" "private_rt_1" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_1.id
  }

  tags = {
    Name = "private-route-table-1"
  }
}

resource "aws_route_table" "private_rt_2" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_2.id
  }

  tags = {
    Name = "private-route-table-2"
  }
}


resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}


resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main_vpc.id

  # Разрешить входящий HTTP трафик
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Разрешить доступ с любого IP
  }

  # Разрешить входящий HTTPS трафик
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Разрешить доступ с любого IP
  }

  # Разрешить входящий SSH трафик
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Разрешить доступ с любого IP
  }

  # Разрешить весь исходящий трафик
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

resource "aws_key_pair" "my_key" {
  key_name   = "terr-key"
  public_key = file("~/.ssh/my_new_key.pub")
}

resource "aws_instance" "web_server" {
  ami           = "ami-07c8c1b18ca66bb07"  
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_subnet.id
  security_groups = [ aws_security_group.web_sg.id ]
  key_name      = aws_key_pair.my_key.key_name

  tags = {
    Name = "web-server"
  }
}

resource "aws_db_instance" "mysql_rds" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "password"
  skip_final_snapshot  = true
  publicly_accessible  = false
  multi_az             = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "mysql-rds"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "rds-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Например, разрешаем доступ только из подсетей VPC
  }

  tags = {
    Name = "rds-security-group"
  }
}


resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "redis-subnet-group"
  }
}

resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "redis-cluster"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]

  tags = {
    Name = "redis-cluster"
  }
}

resource "aws_security_group" "redis_sg" {
  vpc_id = aws_vpc.main_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Например, разрешаем доступ только из подсетей VPC
  }

  tags = {
    Name = "redis-security-group"
  }
}