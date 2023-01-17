data "aws_caller_identity" "current" {}

locals {
  vpc_id = element(split("/", var.network.data.infrastructure.arn), 1)
  postgresql = {
    protocol = "tcp"
    port     = 5432
  }

  enable_enhanced_monitoring  = lookup(var.observability, "enhanced_monitoring_interval", 0) > 0
  enable_performance_insights = lookup(var.observability, "performance_insights_retention_period", 0) > 0

  # RDS refers to engine as `postgres`
  parameter_group_family = "postgres${element(split(".", var.database.engine_version), 0)}"
  parameters             = lookup(var.database, "parameters", [])

  subnet_ids = {
    "internal" = [for subnet in var.network.data.infrastructure.internal_subnets : element(split("/", subnet["arn"]), 1)]
    "private"  = [for subnet in var.network.data.infrastructure.private_subnets : element(split("/", subnet["arn"]), 1)]
  }
}

resource "random_password" "root_password" {
  length  = 10
  special = false
}

resource "random_id" "snapshot_identifier" {
  byte_length = 4
}

resource "aws_db_instance" "main" {
  allocated_storage                     = var.storage.allocated
  allow_major_version_upgrade           = false
  auto_minor_version_upgrade            = true
  backup_retention_period               = var.backup.retention_period
  copy_tags_to_snapshot                 = true
  db_subnet_group_name                  = aws_db_subnet_group.main.name
  delete_automated_backups              = var.backup.delete_automated_backups
  deletion_protection                   = var.database.deletion_protection
  enabled_cloudwatch_logs_exports       = lookup(var.observability, "enabled_cloudwatch_logs_exports", [])
  engine                                = "postgres"
  engine_version                        = var.database.engine_version
  final_snapshot_identifier             = var.backup.skip_final_snapshot ? null : "${var.md_metadata.name_prefix}-${element(concat(random_id.snapshot_identifier.*.hex, [""]), 0)}"
  identifier                            = var.md_metadata.name_prefix
  instance_class                        = var.database.instance_class
  iops                                  = var.storage.type == "io1" ? lookup(var.storage, "iops", null) : null
  kms_key_id                            = aws_kms_key.postgresql_encryption.arn
  max_allocated_storage                 = var.storage.max_allocated
  monitoring_interval                   = var.observability.enhanced_monitoring_interval
  monitoring_role_arn                   = local.enable_enhanced_monitoring ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  parameter_group_name                  = aws_db_parameter_group.main.name
  password                              = random_password.root_password.result
  performance_insights_enabled          = local.enable_performance_insights
  performance_insights_kms_key_id       = local.enable_performance_insights ? aws_kms_key.postgresql_encryption.arn : null
  performance_insights_retention_period = local.enable_performance_insights ? lookup(var.observability, "performance_insights_retention_period", 7) : null
  port                                  = local.postgresql.port
  publicly_accessible                   = false
  skip_final_snapshot                   = var.backup.skip_final_snapshot
  storage_encrypted                     = true
  storage_type                          = var.storage.type
  username                              = var.database.username
  vpc_security_group_ids                = [aws_security_group.main.id]

  # iam_database_authentication_enabled = var.iam_database_authentication_enabled
  # apply_immediately                   = var.apply_immediately
  # maintenance_window                  = var.maintenance_window
  # replicate_source_db                 = var.replicate_source_db
  # replica_mode                        = var.replica_mode
  # TODO: best way to represent this in the UI?
  # Need time-only widget: https://github.com/rjsf-team/react-jsonschema-form/tree/3ec17f1c0ff40401b7a99c5e9891ac2834a1e73f/packages/core/src/components/widgets
  # backup_window           = var.backup_window

  lifecycle {
    ignore_changes = [
      latest_restorable_time
    ]
  }
}

resource "aws_db_subnet_group" "main" {
  name        = var.md_metadata.name_prefix
  description = "For RDS PostgreSQL cluster ${var.md_metadata.name_prefix}"
  subnet_ids  = local.subnet_ids[var.networking.subnet_type]
}

resource "aws_kms_key" "postgresql_encryption" {
  description             = "PostgreSQL Encryption Key for ${var.md_metadata.name_prefix}"
  deletion_window_in_days = 30
  enable_key_rotation = true
}

resource "aws_kms_alias" "postgresql_encryption" {
  name          = "alias/${var.md_metadata.name_prefix}-postgresql-encryption"
  target_key_id = aws_kms_key.postgresql_encryption.key_id
}

resource "aws_security_group" "main" {
  vpc_id      = local.vpc_id
  name_prefix = "${var.md_metadata.name_prefix}-"
  description = "Control traffic to/from RDS PostgreSQL ${var.md_metadata.name_prefix}"
}

# Note: this rule here is to support ingress from the VPC until we add in security group support for applications in AWS
resource "aws_security_group_rule" "vpc_ingress" {
  count       = 1
  description = "From allowed CIDRs"
  type        = "ingress"
  from_port   = local.postgresql.port
  to_port     = local.postgresql.port
  protocol    = local.postgresql.protocol
  cidr_blocks = [var.network.data.infrastructure.cidr]

  security_group_id = aws_security_group.main.id
}

resource "aws_db_parameter_group" "main" {
  name_prefix = var.md_metadata.name_prefix
  description = "Parameter group for RDS PostgreSQL ${var.md_metadata.name_prefix}"
  family      = local.parameter_group_family

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", null)
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
