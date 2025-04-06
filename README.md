# ECS Services with Terraform

Hola, como estas?

I created a terraform module to create ECS Services and everything related to them, with enough customization to help you create new environments in minutes!

Please note: To create the ECS service, your user must be permitted to create/update many resources. You can use the admin access keys of the account you want to deploy the service on.

Just click on the Access Keys link next to the account you want to use, and export all the variables to your terminal.

## Prerequisites

### Create an ECS Cluster

The ECS service runs in a cluster. Currently, there is no support for cluster creation/modification, so we need to create it manually.

In AWS, go to ECS → Clusters - Create Cluster.

Fill in the name, and make sure FARGATE is selected. No need to do anything else.

### Terraform Setup

Install Terraform. The latest version is just fine.

### Docker Image

Before we can create the service, we need a docker image.

Please build your docker image (you can do it wherever you want), and upload it to a repository of your choice. I recommend AWS ECR. If you use another repository, make sure it’s either public or that your AWS account has access to it. In a future update, I will add support for private repos.

The image MUST be built for x86. You can use `--platform linux/amd64` for that

### Environment Variables

If your container requires some environment variables, you need to create a secret in the AWS secret manager and change the `secret_arn` variable value to the ARN of the secret you created.

Follow this format:
```
{"environment_variables":
    [
        {
            "name": "<var_name>",
            "value": "<var_value>"
        },
        ...
    ]
}
```
You can have as many variables as you want.

### IAM Role

If your service requires an IAM role, here are the steps to create it:

Find all the pre-defined policies you wish to use. You can find them in the policies tab in the IAM control panel.

In Terraform, update the `tfvars` file for your service with the policies you want. See [How to Deploy](#how-to-deploy) later in this guide.

Here is an example:
```
tasks_iam_role_aws_policies = ['arn:aws:iam::aws:policy/AdministratorAccess-Amplify']
tasks_iam_role_customer_policies = {
  "CustomPolicy1" = {
    name        = "CustomPolicy1"
    description = "This is a custom policy for S3 access"
    statements  = [
      {
        sid      = "1"
        effect   = "Allow"
        actions  = ["s3:ListBucket"]
        resources = ["arn:aws:s3:::example-bucket"]
      },
      {
        sid      = "2"
        effect   = "Allow"
        actions  = ["s3:GetObject", "s3:PutObject"]
        resources = ["arn:aws:s3:::example-bucket/*"]
      }
    ]
  }
  "CustomPolicy2" = {
    name        = "CustomPolicy2"
    description = "This is a custom policy for EC2 access"
    statements  = [
      {
        sid      = "1"
        effect   = "Allow"
        actions  = ["ec2:DescribeInstances"]
        resources = ["*"]
      }
    ]
  }
}
```

If you prefer to use a pre-existing role, and you know nothing else but the service you want to migrate uses it, you can skip the steps above and use:

`tasks_iam_role_arn = "<arn_of_existing_role>"`

You also need to go into the role’s trusted policy and add under the `Service` object the `"ecs-tasks.amazonaws.com"` value. It would probably have some value in it, so change the value to a list and add both the original service and the `"ecs-tasks.amazonaws.com"` one to the list.

### Other

Please make sure your VPC has private networks, and that those are tagged with “Type=Private”, otherwise Terraform won’t be able to find them.

## How to Deploy

Follow these steps to create your very own ECS Service:

1. Clone this repo.

2. cd into the directory:
`cd /path/to/repo/ecs_service`

3. Go to AWS and get your access key:

    Click on your account -> Access Keys -> Choose correct role.

    Run what you just copied in your terminal.

    Another way is if you have the profile already configured in your terminal, just copy the session token (scroll down a bit on the page above), and run:

    `export AWS_SESSION_TOKEN="<token>"`

4. run the commands:
```
terraform init
# If creating a new service
terraform workspace new <project>-<env>
# If updating an existing service
terraform workspace select <project>-<env>
# For example: srv-svc-stg
# You can name your workspace however you want, but please try to follow the 
# convention
```

If you get an error in the first command, just back to step 3 and this time refresh the page before getting your token.

5. Create a new tfvars file and populate it with the values you want to use. All available variables can be seen in variables.tf.

    Here is an example file:

```
# service_stg.tfvars:

aws_account = "account_name"
svc_name = "service-tf-stg"
container_name = "svc_cnt"
container_image = "<url_to_image>" #If you used AWS ECR, use the ARN
s3_logs_bucket = "test-svc-bucket"
```

> Some of the values have defaults preconfigured. Make sure to change the values using this file!

6. Let’s plan for the changes:

    `terraform plan -out tfplan -var-file <file_name>.tfvars`

    > About 27 resources are supposed to be created

7. After making sure the plan doesn’t destroy anything important, let’s apply:

    `terraform apply tfplan`

    > This process can take a few minutes. Don’t worry  

8. Once the apply process is done, go to AWS and make sure the service is running.

9. Voilà! We have a running ECS Service!

## Access Logs

The ALB associated with the ECS service has access logs available. Those can be found in the S3 bucket you chose in the tfvars file, under this path:

```
ecs-<bucket_name_from_tfvars>/AWSLogs/<account_id>/elasticloadbalancing/

# For example:
# ecs-test-svc-server-bucket/AWSLogs/<account_id>/elasticloadbalancing/
```

## How to Update the Service

### New Image

You can update the image manually by uploading it to the repo, creating a new version of the task definition correlating to the service, and running an update.

### Changing Parameters

Follow all the steps above and change the parameters to the ones you want. Make sure your plan doesn’t change anything it’s not supposed to change!

### How to DESTROY

In case you want to destroy an environment:

```
terraform workspace select <project>-<env>
terraform destroy -refresh=false # If it asks for inputs, just leave empty
terraform workspace select default
terraform workspace delete <project>-<env>
```

## Next Steps

If you want to use this ECS service as a backend, copy the internal ALB DNS set this as the CNAME value of your domain.