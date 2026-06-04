# GrantThrive Terraform State Management

This repo creates the shared Terraform remote-state infrastructure used by the backend and frontend repos.

## What It Creates

| Resource | Name |
|----------|------|
| Backend state bucket | `grantthrive-terraform-state-backend-547154049278` |
| Frontend state bucket | `grantthrive-terraform-state-frontend-547154049278` |
| Lock table | `grantthrive-terraform-locks` |
| Region | `ap-southeast-2` |

The S3 buckets have:

- Versioning enabled
- AES256 server-side encryption
- Public access blocked
- Lifecycle cleanup for old non-current state versions

The DynamoDB table is used by Terraform state locking so two developers cannot safely apply the same stack at the same time.

## Bootstrap Order After Clone

Run this repo first only when the state buckets/table do not already exist.

```bash
cd grantthrive-state-management
AWS_PROFILE=biglittle terraform init
AWS_PROFILE=biglittle terraform apply
```

If the buckets/table already exist, do not recreate them. Use this repo only to inspect or maintain the state-management resources.

## What To Commit

Commit the Terraform source files and documentation:

- `.gitignore`
- `README.md`
- `GrantThrive-Architecture.md`
- `main.tf`
- `outputs.tf`
- `variables.tf`
- `.terraform.lock.hcl`

Do not commit local Terraform runtime files:

- `.terraform/`
- `*.tfstate`
- `*.tfstate.*`
- `*.tfplan`
- `*.tfvars`
- crash logs or local override files

The `.terraform.lock.hcl` file is intentionally committed so every developer and CI run uses the same provider versions.

## How Backend and Frontend Use This

Backend repo:

```hcl
terraform {
  backend "s3" {
    bucket         = "grantthrive-terraform-state-backend-547154049278"
    key            = "terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = "true"
    dynamodb_table = "grantthrive-terraform-locks"
  }
}
```

Frontend repo:

```hcl
terraform {
  backend "s3" {
    bucket         = "grantthrive-terraform-state-frontend-547154049278"
    key            = "terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = "true"
    dynamodb_table = "grantthrive-terraform-locks"
  }
}
```

Both repos use Terraform workspaces:

- `uat`
- `prod`

GitHub Actions branch mapping:

- `staging` deploys UAT.
- `prod` deploys production.
- `main` is not used as an automatic production deployment branch.

Terraform stores workspace state in S3 using its default workspace prefix. With the current backend config, workspace state objects are:

| Repo | Workspace | S3 bucket | State object |
|------|-----------|-----------|--------------|
| Backend | `uat` | `grantthrive-terraform-state-backend-547154049278` | `env:/uat/terraform.tfstate` |
| Backend | `prod` | `grantthrive-terraform-state-backend-547154049278` | `env:/prod/terraform.tfstate` |
| Frontend | `uat` | `grantthrive-terraform-state-frontend-547154049278` | `env:/uat/terraform.tfstate` |
| Frontend | `prod` | `grantthrive-terraform-state-frontend-547154049278` | `env:/prod/terraform.tfstate` |

The configured `key = "terraform.tfstate"` is used by the default workspace. The GrantThrive stacks should be run from `uat` or `prod`, not from the default workspace.

## New Developer Setup

Prerequisites:

- AWS CLI configured with profile `biglittle`
- Terraform >= 1.6
- IAM permissions for S3 state buckets, DynamoDB lock table, and the AWS resources being managed

Verify access:

```bash
AWS_PROFILE=biglittle aws sts get-caller-identity
AWS_PROFILE=biglittle aws s3 ls s3://grantthrive-terraform-state-backend-547154049278/
AWS_PROFILE=biglittle aws s3 ls s3://grantthrive-terraform-state-frontend-547154049278/
AWS_PROFILE=biglittle aws dynamodb describe-table --table-name grantthrive-terraform-locks --region ap-southeast-2
```

Initialize backend Terraform:

```bash
cd grantthrive-platform/terraform
AWS_PROFILE=biglittle terraform init
AWS_PROFILE=biglittle terraform workspace select uat || AWS_PROFILE=biglittle terraform workspace new uat
AWS_PROFILE=biglittle terraform workspace select prod || AWS_PROFILE=biglittle terraform workspace new prod
```

Initialize frontend Terraform:

```bash
cd GrantThrive-frontend/terraform
AWS_PROFILE=biglittle terraform init
AWS_PROFILE=biglittle terraform workspace select uat || AWS_PROFILE=biglittle terraform workspace new uat
AWS_PROFILE=biglittle terraform workspace select prod || AWS_PROFILE=biglittle terraform workspace new prod
```

After initialization, always select the target workspace before plan/apply:

```bash
AWS_PROFILE=biglittle terraform workspace select uat
AWS_PROFILE=biglittle terraform plan -var-file=terraform.uat.tfvars
```

## Recreate Infrastructure From Cloned Repos

Order matters:

1. Ensure state buckets and lock table exist from this repo.
2. Apply backend UAT first because UAT owns shared VPC, ALB, and RDS.
3. Apply backend PROD because PROD reuses the UAT-owned ALB/RDS.
4. Deploy backend UAT and PROD apps.
5. Apply frontend UAT and PROD.
6. Deploy frontend UAT and PROD apps.

Backend:

```bash
cd grantthrive-platform/terraform
AWS_PROFILE=biglittle terraform init
AWS_PROFILE=biglittle terraform workspace select uat || AWS_PROFILE=biglittle terraform workspace new uat
AWS_PROFILE=biglittle terraform apply -var-file=terraform.uat.tfvars
AWS_PROFILE=biglittle terraform workspace select prod || AWS_PROFILE=biglittle terraform workspace new prod
AWS_PROFILE=biglittle terraform apply -var-file=terraform.prod.tfvars
```

Frontend:

```bash
cd GrantThrive-frontend/terraform
AWS_PROFILE=biglittle terraform init
AWS_PROFILE=biglittle terraform workspace select uat || AWS_PROFILE=biglittle terraform workspace new uat
AWS_PROFILE=biglittle terraform apply -var-file=terraform.uat.tfvars
AWS_PROFILE=biglittle terraform workspace select prod || AWS_PROFILE=biglittle terraform workspace new prod
AWS_PROFILE=biglittle terraform apply -var-file=terraform.prod.tfvars
```

Application deploy commands are documented in each app repo README.

## Inspect State

List workspaces:

```bash
AWS_PROFILE=biglittle terraform workspace list
```

List resources in selected workspace:

```bash
AWS_PROFILE=biglittle terraform state list
```

List S3 state object versions:

```bash
AWS_PROFILE=biglittle aws s3api list-object-versions \
  --bucket grantthrive-terraform-state-backend-547154049278 \
  --prefix 'env:/uat/terraform.tfstate'
```

## State Locks

Terraform normally creates and removes locks automatically.

If a Terraform run is interrupted, inspect locks:

```bash
AWS_PROFILE=biglittle aws dynamodb scan \
  --region ap-southeast-2 \
  --table-name grantthrive-terraform-locks
```

Only remove a lock after confirming no Terraform process is still running:

```bash
AWS_PROFILE=biglittle aws dynamodb delete-item \
  --region ap-southeast-2 \
  --table-name grantthrive-terraform-locks \
  --key '{"LockID":{"S":"<LOCK_ID_FROM_SCAN>"}}'
```

Prefer `terraform force-unlock <LOCK_ID>` when Terraform reports a lock ID.

## Important Rules

- Do not commit local `terraform.tfstate` files.
- Do not run applies from the default workspace.
- Do not run backend and frontend Terraform applies in parallel if both might touch DNS/certificates.
- Do not delete the state buckets unless the infrastructure is intentionally being decommissioned.
- Keep UAT backend applied before PROD backend because PROD depends on UAT-owned shared ALB/RDS.
