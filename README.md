# Dateline New Episode Notification Lambda
This project is an AWS Lambda function that checks for recently published NBC Dateline episodes on http://www.nbc.com/dateline and then sends an SMS notification with SNS.

I created this project as a way to learn how to:
* Create an AWS Lambda function that works with Secrets Manager, SNS, CloudWatch, DynamoDB, and IAM
* Create a Python script
* Create Terraform infrastructure as code
* Configure Continuous Integration/Continuous Delivery using CircleCI
* Perform local testing with Docker and the CircleCI cli

## The Lambda Function
The Lambda function does the following:
* Uses an HTTP get request to list recently published episodes from [api.nbc.com](https://api.nbc.com)
* Uses an HTTP get request to query the episode on [TheTVDB.com](https://thetvdb.com "TheTVDB") for the season and episode number
* Tries to put a new item in a DynamoDB table
    * If the item does not exist:
        * Adds the episode to the table
        * Sends an SNS notification that there is a new episode available
    * If the item exists:
        * Does nothing

## Getting Started
Before you deploy this project you need to update some of the Terraform files for your environment. Following that there are instructions for deploying locally using Terraform and for configuring the project in CircleCI.

### Terraform Modifications
Modify the following Terraform files for your environment.
#### main.tf
1. Set the **region** for the aws provider at the top of the file
1. Set the state bucket name by updating **bucket** under the resource **tf-state-bucket**
2. Set the state bucket lock table name by updating **name** under the resource **tf-state-table**

#### backend.tf
1. Update **bucket** name to match the name set in **main.tf**
2. Update **dynamodb_table** name to match the name set in **main.tf**
3. Set **region** to match the one defined in **main.tf**

#### variables.tf
1. Add or modify tags as needed
    * The **pipeline** tag is required for the **aws_resourcegroups_group** resource
2. Set your own variable default values as you see fit

### Deploy Manually
After modifying the Terraform files above, follow these instructions to deploy this project without using CircleCI for CI/CD.

#### terraform.tfvars
Create a new file in the cloned repo called terraform.tfvars to set the following variables:
```
sns_sms_endpoint = "+15555555555"
apikey = "YourTVDBApiKey"
userkey = "YourTVDBUserKey"
username = "YourTVDBUsername"
```

#### Initialize and Apply

1. Rename **backend.tf** to **backend.bak**
2. Run `terraform init`
3. Run `terraform apply`

Steps 1 to 3 deploy the project with a local backend for the state file. To move the state file to an s3 bucket created during the deployment complete steps 4 and 5.

4. Rename **backend.bak** to **backend.tf**
5. Run `terraform init -force-copy`

If you run steps 4 and 5 you will not be able to run `terraform destroy` without receiving the error ***Error: Failed to persist state to backend***. This is because destroy will remove the bucket that stores the state file. To avoid this issue you need to move the state file back to a local backend. To do that follow steps 1 and 2 again. Then you can run `terraform destroy`.

### Deploy with CircleCI
Follow these instructions to deploy the project using CircleCI.
1. Create a context with your **AWS_ACCESS_KEY_ID** and **AWS_SECRET_ACCESS_KEY**
2. Update **config.yml** to use your context
3. Create the following environment variables in your CircleCI project for your TVDB api keys and SMS phone number. (https://api.thetvdb.com/swagger)
    * TF_VAR_apikey
    * TF_VAR_userkey
    * TF_VAR_username
    * TF_VAR_sns_sms_endpoint - value format: +15555555555
4. Create a new branch called **feature/implement** and commit to it to trigger the initialization workflow.
5. Merge feature/implement to master and delete the branch

### Terraform Created Backend and Running Destroy
The state file in this project is stored on an s3 bucket created by in the project. This is achieved using a CircleCI job to create the resources and then migrate the backend to the created s3 bucket. This menas just running `terraform destroy` will result in an error because the state bucket is in use. In order to successfully run destroy you need to move the state to a local backend first. Follow these steps to move from the s3 backend to a local backend:
1. Run `terraform init` with the s3 backend
2. Rename **backend.tf** to **backend.bak**
3. Run `terraform init -force-copy`
4. Run `terraform destroy`