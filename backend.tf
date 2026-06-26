terraform {
  backend "s3" {
    # bucket, key, region provided via -backend-config / backend.hcl
    use_lockfile = true
    encrypt      = true
  }
}
