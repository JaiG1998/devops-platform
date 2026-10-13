# Comprehensive AWS Account Setup & Security Guide

This document summarizes the best-practice steps required to secure a brand-new AWS account, establish non-root administration, configure cost visibility, and connect the AWS CLI.

---

## Step 1: Root Account Security & Alternate Contacts

### 1. Confirm No Root Access Keys Exist
Root access keys represent a severe security risk. You must verify and ensure none exist:
1. Log in to the AWS Management Console as the **Root User**.
2. Click your account name/number in the top-right corner and select **Account** (or **My Security Credentials**).
3. Scroll down to the **Access keys** section.
4. Verify that it states **"You do not have any access keys"** (delete any if they are present).

### 2. Set Up Account Alternate Contacts
Ensure AWS sends critical alerts to the right teams instead of just the root owner's personal inbox:
* **Security Contact:** For urgent security alerts, leaked access keys, and incident notifications (e.g., `security@yourdomain.com`).
* **Billing Contact:** For invoices, payment failures, and cost warnings (e.g., `billing@yourdomain.com`).
* **Operations Contact:** For scheduled maintenance windows and infrastructure outages (e.g., `devops@yourdomain.com`).
* **How to configure:** Go to **Account** settings in the AWS console, scroll to **Alternate Contacts**, click **Edit**, and update the details.

---

## Step 2: Create a Non-Root Admin Identity (IAM Identity Center)

Preferred method: **AWS IAM Identity Center** (free, provides short-lived credentials, and is the industry standard).

1. **Enable IAM Identity Center:**
   * Select your home region in the top-right corner of the AWS console.
   * Search for **IAM Identity Center** and click **Enable**.
2. **Create a Group and User:**
   * Create a group named `platform-admins` under **Groups**.
   * Create a user under **Users**, provide your email, assign them to the `platform-admins` group, and choose the option to send an email setup link.
3. **Assign `AdministratorAccess`:**
   * Go to **AWS accounts**, select your account ID, and click **Assign users or groups**.
   * Choose the `platform-admins` group and assign the pre-defined **`AdministratorAccess`** permission set.
4. **Enable MFA:**
   * Enforce MFA on sign-in under Identity Center settings, and complete your initial setup using an authenticator app via your assigned AWS Access portal URL.

---

## Step 3: Billing Visibility & Alarms

1. **Activate IAM/SSO Access to Billing Info:**
   * Log in as Root, go to **Account** settings, scroll to **IAM user and role access to Billing information**, click **Edit**, check **Activate IAM Access**, and save.
2. **Enable Cost Explorer:**
   * Search for **Cost Management**, open **Cost Explorer**, and click **Enable Cost Explorer**.
3. **Create an AWS Budget:**
   * Navigate to **Budgets** -> **Create budget** -> **Cost budget (Recommended)**.
   * Set your periodic limit (e.g., **$20/month**).
   * Configure alert thresholds at **50%**, **80%**, and **100%** of **Actual** spend, plus **100%** of **Forecasted** spend.
   * Link it to your active email and confirm the SNS subscription.
4. **Enable Cost Anomaly Detection (Optional):**
   * Create an AWS services monitor to automatically catch unexpected cost spikes.

---

## Step 4: Connecting the AWS CLI to an IAM User

If you are using an IAM user (rather than IAM Identity Center SSO) for CLI access:

1. **Retrieve Access Keys:**
   * Go to the **IAM** console -> **Users** -> Select your user -> **Security credentials** tab -> **Access keys** -> **Create access key**.
   * Save your **Access Key ID** and **Secret Access Key** securely.
2. **Configure the CLI:**
   Open your terminal (PowerShell, Command Prompt, or bash) and run:
   ```bash
   aws configure
   ```
   * Enter your **AWS Access Key ID**.
   * Enter your **AWS Secret Access Key**.
   * Enter your default **Region name** (e.g., `us-east-1`).
   * Enter your default **Output format** (`json`).
3. **Verify Connection:**
   ```bash
   aws sts get-caller-identity
   ```
   This should return a JSON object confirming your IAM user ARN and account ID.