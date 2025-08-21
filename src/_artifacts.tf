locals {
  data_authentication = {
    username = aws_db_instance.main.username
    password = aws_db_instance.main.password
    hostname = aws_db_instance.main.address
    port     = local.postgresql.port
  }
  data_infrastructure = {
    arn = aws_db_instance.main.arn
  }

  data_security = {
    network = {
      postgresql = {
        arn      = aws_security_group.main.arn
        port     = local.postgresql.port
        protocol = local.postgresql.protocol
      }
    }
  }
  rdbms_specs = {
    engine         = "PostgreSQL"
    engine_version = aws_db_instance.main.engine_version
    version        = aws_db_instance.main.engine_version_actual
  }
}

resource "massdriver_artifact" "authentication" {
  field    = "authentication"
  name     = "PostgreSQL Root Credentials: ${aws_db_instance.main.identifier}"
  artifact = jsonencode(
    {
      data = {
        infrastructure = local.data_infrastructure
        authentication = local.data_authentication
        security       = local.data_security
      }
      specs = {
        rdbms = local.rdbms_specs
      }
    }
  )
}
