# **Terraform State Management Runbook**

Standard Operating Procedures for remote backend lifecycle, locking mechanisms, disaster recovery, and operational guardrails.

# **Overview**

This runbook provides step-by-step procedures for managing Terraform remote state, bootstrapping state infrastructure from scratch, handling stuck locks safely, executing state rollbacks, and establishing anti-patterns to prevent state corruption across cloud environments.

# **1\. Bootstrapping State Infrastructure from Scratch**

Follow these steps when setting up state infrastructure for a brand-new AWS environment or organization.

1. **Navigate to the Bootstrap Directory**

```
cd terraform/bootstrap
```

2. **Initialize Local Terraform**  
   Ensure `versions.tf` contains no `backend "s3"` block (using local state initially to avoid chicken-and-egg bootstrap issues).

```
terraform init
```

3. **Provision the Remote State S3 Bucket**

```
terraform apply
```

*Verification:* Ensure the output displays the created S3 bucket name in the format `<project>-tfstate-<account-id>-<region>`.

4. **Configure Downstream Environments (`dev`, `staging`, `prod`)**  
   In each environment directory (e.g., `terraform/envs/dev/`):  
* Ensure `versions.tf` defines `backend "s3" {}`.  
* Create a local `backend.hcl` containing:

```
bucket       = "<project>-tfstate-<account-id>-<region>"
key          = "dev/terraform.tfstate"
region       = "<aws-region>"
use_lockfile = true
```

* Initialize and link to the S3 backend:

```
terraform init -backend-config=backend.hcl
```

# **2\. Force-Unlocking a Stuck Lock Safely**

State locks can occasionally remain active if a `terraform apply` or `terraform plan` process was forcefully killed or crashed midway.

## **Safety Warning**

Never force-unlock a state file without confirming that no active CI/CD pipeline, automated runner, or teammate is currently running a Terraform operation against the environment. Force-unlocking an active operation can lead to severe state corruption.

## **Step-by-Step Resolution**

1. **Identify the Lock ID**  
   When a lock collision occurs, Terraform outputs an error containing details similar to:

```
Error: Error acquiring the state lock
Lock Info:
  ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Path:      dev/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
```

2. **Verify Process Inactivity**  
   Confirm with your team or check CI/CD pipeline runs to ensure the process holding `ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890` is truly dead.  
3. **Execute Force Unlock**  
   Run the force-unlock command passing the specific Lock ID:

```
terraform force-unlock a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

*Verification:* Confirm Terraform responds with `Local state unlocked.` and subsequent `terraform plan` operations execute cleanly without lock errors.

# **3\. Restoring a Previous State Version**

If a state file becomes corrupted or out of sync with real-world infrastructure, you can restore a historical version from S3 versioning.

1. **List Object Versions in S3**  
   Use the AWS CLI to locate the target state file's version history:

```
aws s3api list-object-versions \
  --bucket <project>-tfstate-<account-id>-<region> \
  --prefix dev/terraform.tfstate
```

Identify the `VersionId` of the last known good state.

2. **Retrieve the Historical State File**  
   Download the target version to a local temporary file:

```
aws s3api get-object \
  --bucket <project>-tfstate-<account-id>-<region> \
  --key dev/terraform.tfstate \
  --version-id "<OLD_VERSION_ID>" \
  recovered_state.tfstate
```

3. **Inspect the Recovered State File**  
   Verify the local JSON structure:

```
terraform show recovered_state.tfstate
```

4. **Push the Recovered State Remote**  
   Push the recovered state file back into your S3 backend:

```
terraform state push recovered_state.tfstate
```

*Verification:* Run `terraform plan` to confirm Terraform reads the restored state file cleanly without schema mismatches. Remove the local `recovered_state.tfstate` file once verified.

# **4\. What NOT to Do (Forbidden Anti-Patterns)**

## **Strict Rules & Anti-Patterns**

Adhere to these rules strictly to prevent unrecoverable data loss or infrastructure outages:

* **NEVER Edit State Files By Hand:** State files are machine-generated JSON documents with complex dependency lineages and resource serials. Editing them directly risks syntax errors, checksum mismatches, and orphan resources. Use `terraform state mv`, `terraform state rm`, or `terraform import` instead.  
* **NEVER Delete the Remote State Bucket or Key:** Deleting state objects breaks Terraform's connection to your live infrastructure. The live resources will remain active in AWS, but Terraform will lose all record of them, creating high risk during future deployments.  
* **NEVER Disable S3 Bucket Versioning:** Versioning is your primary fail-safe against state corruption and accidental overwrites.  
* **NEVER Commit `.tfstate` Files to Git Repositories:** State files can contain sensitive raw data (passwords, private keys, connection strings). Keep all `.tfstate` files strictly covered under `.gitignore`.

