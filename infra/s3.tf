resource "aws_s3_bucket" "nb-quest-reports" {
  bucket = "nb-quest-reports"
  tags = {
    "Name" = "nb-quest-report"
  }
}

resource "aws_s3_bucket_public_access_block" "nb-quest-deny-access" {
  bucket = aws_s3_bucket.nb-quest-reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}