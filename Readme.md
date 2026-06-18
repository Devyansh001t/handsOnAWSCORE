> **Note:** Please refer to the initial project requirements in the [itcs6190_aws_core_services.pdf](https://github.com/ITCS6190-Summer2026/Hands-on-AWS-Core-Services/blob/main/itcs6190_aws_core_services.pdf) file before proceeding with the configurations below.

## AWS Core Services Assignment Guide

### 1. S3 Bucket Setup & Structure
* **Global Uniqueness:** S3 bucket names must be globally unique across all AWS accounts. Append a unique identifier, such as your student ID or initials (e.g., `itcs6190-raw-data-[yourinitials]`).
* **Recommended Structure:** Create either two separate buckets or one main bucket with two folders:
  * `raw-data/` -> Upload your downloaded Kaggle CSV here.
  * `processed-data/` -> Designate this for Athena query results.

### 2. IAM Role Configuration
To give your Glue Crawler permission to access your data, create an IAM Role with the following parameters:
* **Trusted Entity Type:** AWS Service
* **Service:** `Glue`
* **Permissions Policies to Attach:**
  * `AWSGlueServiceRole` (Provides basic crawler permissions)
  * `AmazonS3ReadOnlyAccess` (Allows the crawler to read data from your S3 bucket)

### 3. Glue Crawler Navigation (AWS Console)
Because the AWS Console UI updates frequently, use the search bar at the top of the AWS Console to find **AWS Glue**:
1. In the left sidebar, click on **Crawlers** under the *Data Catalog* section.
2. Click **Create crawler**.
3. Name your crawler and specify the S3 path to your `raw-data/` folder as the data store.
4. Assign the IAM role created in the previous step.
5. Configure the output to point to a database (create a new database if you don't have one yet).
