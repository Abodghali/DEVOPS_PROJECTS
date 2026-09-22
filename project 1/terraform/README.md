# Private AWS Backup Storage

Terraform provisions a private S3 bucket with versioning, AES-256 server-side encryption, public access blocking and a policy denying non-TLS access. No IAM users or static credentials are created.

## Validate and plan

Install Terraform 1.6+ and AWS CLI. Authenticate using your own AWS SSO/profile and verify the target account with `aws sts get-caller-identity`. From this directory:

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit bucket_name to a globally unique name.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=backup.tfplan
```

Review the account, region and plan before running `terraform apply backup.tfplan`. AWS storage and requests can incur charges. Commit the generated `.terraform.lock.hcl` after initialization; do not commit state, plans or credentials.

## Verify after apply

Use `terraform output -raw bucket_name` as BUCKET below:

```sh
aws s3api get-public-access-block --bucket BUCKET
aws s3api get-bucket-versioning --bucket BUCKET
aws s3api get-bucket-encryption --bucket BUCKET
aws s3api get-bucket-policy --bucket BUCKET
```

The runtime backup identity should receive only `s3:PutObject` on its backup prefix. A separate recovery identity can receive `s3:GetObject`, `s3:GetObjectVersion` and narrowly scoped listing permissions. This project leaves identity assignment to your account setup. Optionally upload an archive and checksum from the automation project with `aws s3 cp`.

## Cleanup and limits

Run `terraform plan -destroy` and review it before `terraform destroy`. The bucket deliberately refuses destruction when nonempty. Versioned objects and delete markers must be reviewed and removed explicitly if you intend to delete all backups. There is no automatic retention expiry, replication or remote state backend in this lab.

Reference: [AWS provider public access block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block).
