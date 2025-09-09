region      = "us-east-1"
name_prefix = "orders"

# Paths to your repo’s lambda folders
publisher_src_dir    = "../../lambdas/publisher"
ddb_consumer_src_dir = "../../lambdas/ddb-consumer"
s3_consumer_src_dir  = "../../lambdas/s3-archive-consumer"

# If your handlers differ, change these:
runtime           = "python3.12"
publisher_handler = "app.lambda_handler"
ddb_handler       = "app.lambda_handler"
s3_handler        = "app.lambda_handler"

# Demo credentials (env vars in Lambda)
client_id     = "demo-client-id"
client_secret = "demo-client-secret"

tags = {
  Project   = "orders-pipeline"
  ManagedBy = "terraform"
}
