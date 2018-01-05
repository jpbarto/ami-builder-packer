## Purpose

This project aims to demonstrate how AWS services can be used to help customers create an Amazon Machine Image (AMI) maintained as code.  The project will demonstrate how to create an AMI using Hashicorp Packer and Ansible as well as how to enforce usage of these AMIs in your environment using AWS Lambda for autocompliance.

The project is made up of a CloudFormation template which will provision resources in your AWS account.  It also provides a sample AMI source project that can be checked into a Git repository hosted by AWS CodeCommit.  Once the source code for the AMI is committed AWS CodePipeline will build the source code using AWS CodeBuild to generate an AMI.  The CodeBuild project will further cryptographically sign the AMI after it is generated.  Using CloudWatch Events and AWS Lambda a rule is also created so that no EC2 instances can be created in your environment that are not using your signed, managed AMIs.

![Packer AMI Builder Diagram](images/ami-builder-diagram.png)

## Source code structure

```bash
|
├── cloudformation                          <-- Cloudformation to create entire pipeline
│   └── pipeline.yaml
├── ami_source                              <-- Source code for AMI
|   ├── packer_cis.json                     <-- Packer template for Pipeline
|   ├── buildspec.yml                       <-- CodeBuild spec 
│   └── post_build.sh                       <-- Shell script for post-AMI build processing
│   └── ansible
│       ├── playbook.yaml                   <-- Ansible playbook file
│       ├── requirements.yaml               <-- Ansible Galaxy requirements containing additional Roles to be used (CIS, Cloudwatch Logs)
│       └── roles
│           └── common                      <-- Upgrades all packages through ``yum``
└── compliance_lambda
    ├── lambda.py                           <-- Lambda function to enforce compliance with managed AMIs
    ├── build-deps.sh                       <-- Shell script called by deployment package script which builds Lambda-compatible Python dependency modules
    ├── create-deployment-package.sh        <-- Shell script to create Lambda deployment package
    └── requirements.txt                    <-- Python requirements file for Lambda function
```


## Cloudformation template

Cloudformation will create the following resources as part of the AMI Builder for Packer:

* ``cloudformation/pipeline.yaml``
    + AWS CodeCommit - Git repository
    + AWS CodeBuild - Downloads Packer and run Packer to build AMI 
    + AWS CodePipeline - Orchestrates pipeline and listen for new commits in CodeCommit
    + Amazon SNS Topic - AMI Builds Notification via subscribed email
    + Amazon Cloudwatch Events Rule - Custom Event for AMI Builder that will trigger SNS upon AMI completion
    + Amazon Cloudwatch Events Rule - Custom event for EC2 launch that will trigger the compliance-enforcing Lambda function


## HOWTO

### Deployment overview
- cd comopliance_lambda && sh create-deployment-package.sh
- aws cloudformation package --template-file cloudformation/pipeline.yaml --s30bucket bucket-for-hosting-lambda-deployment-package --output-template-file cloudformation/pipeline-package.yaml
- Generate a Base64 encoded public and private key for signing created AMIs, a convenience script, `generate_keys.sh` is provided
- From the console create a CloudFormation stack using pipeline-package.yaml
- On the CloudWatch Rules console, disable the newly created rule
- Checkout the resulting CodeCommit repo
- Copy the ami_source directory to the cloned repository and check in the new files
- Let CodePipeline build the AMI and sign the AMI
- Re-enable the CloudWatch Rule when the AMI is built
- Update the CodeCommit project's `packer_cis.json` file to use approved signed images to build future images

**Before you start**

* Install [GIT](https://git-scm.com/downloads) if you don't have it
* Make sure AWS CLI is configured properly
* [Configured AWS CLI and Git](http://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-unixes.html) to connect to AWS CodeCommit repositories
* Clone this GitHub repository to your local working directory
* Install Docker locally to build the Compliance Lambda function

**Launch the Cloudformation stack**
1. From your local command line change into the ``compliance_lambda`` directory
2. Execute the ``create-deployment-package.sh`` shell script
3. Package the Cloudformation template to upload the Lambda deployment package to S3 and prepare the Cloudformation template to reference the uploaded ZIP file
```bash
aws cloudformation package --template-file cloudformation/pipeline.yaml --s3bucket "YOUR-S3-BUCKET-NAME-HERE" --output-=template-file cloudformation/pipeline-packaged.yaml
```
4. Generate a Base64-encoded public / private keypair for signing created AMIs
```bash
sh ./generate_keys.sh
```
5. From the AWS Management Console, open the AWS CloudFormation console and click ``Create Stack``
6. Provide the ``pipeline-package.yaml`` file and enter in your Parameters to include the Base64-encoded public and private keys generated at step 4

**To clone the AWS CodeCommit repository (console)**

1.  From the AWS Management Console, open the AWS CloudFormation console.
2.  Choose the AMI-Builder-Blogpost stack, and then choose Output.
3.  Make a note of the Git repository URL.
4.  Use git to clone the repository.
For example: git clone https://git-codecommit.eu-west-1.amazonaws.com/v1/repos/AMI-Builder_repo

**To clone the AWS CodeCommit repository (CLI)**

```bash
# Retrieve CodeCommit repo URL
git_repo=$(aws cloudformation describe-stacks --query 'Stacks[0].Outputs[?OutputKey==`GitRepository`].OutputValue' --output text --stack-name "AMI-Builder-Blogpost")

# Clone repository locally
git clone ${git_repo}
```

Next, we need to copy all files in the ``ami_source`` directory into the newly cloned Git repository:

* Extract and copy the contents to the Git repo

Lastly, commit these changes to your AWS CodeCommit repo and watch the AMI being built through the AWS CodePipeline Console:

```bash
git add .
git commit -m "SHIP THIS AMI"
git push origin master
```

![AWS CodePipeline Console - AMI Builder Pipeline](images/ami-builder-pipeline.png)

**Confirm compliance enforcement**
1. Open the AWS Management Console and navigate to CloudWatch Rules
2. Find the rule named 'ComplianceEvent' and enable it
3. With the rule enabled launch two EC2 instances, one using the approved, signed AMI, and a second with AWS Amazon Linux
4. While the EC2 instances are launching the signed, approved image should be allowed to launch while the other EC2 instance should be stopped before it reaches a 'Running' state

## Known issues

* Currently, Packer doesn't work with ECS IAM Roles (also used by CodeBuild)
    - That's why we build a credentials file that leverages temporary credentials in the ``buildspec``
    - When Packer supports this feature, this will no longer be necessary
* If Build process fails and within AWS CodeBuild Build logs you find the following line ``Timeout waiting for SSH.``, it means either
    - A) You haven't chosen a VPC Public Subnet, and therefore Packer cannot connect to the instance
    - B) There may have been a connectivity issue between Packer and EC2; retrying the build step within AWS CodePipeline should work just fine 

## Next steps
* Incorporate Inspector reports as a part of the build pipeline [Golden AMI Vulnerability Assessments](https://aws.amazon.com/blogs/security/how-to-set-up-continuous-golden-ami-vulnerability-assessments-with-amazon-inspector/)
