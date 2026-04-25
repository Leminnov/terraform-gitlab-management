# Outputs

## What to Output

- Resource IDs and ARNs that downstream modules or root configs will reference
- Connection strings, endpoints, and DNS names
- Anything needed to wire modules together

Do not output every attribute — only values consumers actually need.

## Naming

- Use `snake_case`
- Match the resource attribute when possible (e.g., `bucket_arn` not `s3_bucket_amazon_resource_name`)
- Prefix with the resource concept when a module creates multiple resource types (e.g., `db_endpoint`, `cache_endpoint`)

## Declarations

Every output must include `description`:

```hcl
output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}
```

- Mark sensitive outputs with `sensitive = true`
- Use `depends_on` only when Terraform cannot infer the dependency

## Ordering

Outputs in `outputs.tf` should be grouped by resource, matching the order resources appear in `main.tf`.
