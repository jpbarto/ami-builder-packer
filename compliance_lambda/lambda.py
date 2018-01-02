"""
Lambda to ensure all EC2 Instances are using an approved AMI to launch from
"""

import logging
import boto3
import json
from Crypto.PublicKey import RSA
from Crypto.Signature import PKCS1_PSS
from Crypto.Hash import SHA256, SHA
import base64

logger = logging.getLogger ('lambda.handler')
logger.setLevel (logging.DEBUG)

ec2_client = None

def stopInstance (instance_id):
    ec2_client.stop_instances (InstanceIds=[instance_id])

def handler(event, context):
    global ec2_client 

    logger.info ("Handling event: {0}".format (json.dumps(event)))

    instance_id = event['detail']['instance-id']
    region = event['region']

    # The EC2 may not be running in the same region as the Lambda function
    ec2_client = boto3.client('ec2', region_name=region)
    # The Lambda assumes it is in the same region as its SSM Parameter Store
    ssm_client = boto3.client ('ssm')

    instance_info = ec2_client.describe_instances (InstanceIds = [instance_id])
    instance_info = instance_info['Reservations'][0]['Instances'][0]
    if instance_info['InstanceId'] != instance_id:
        return {"Error": "Instance {0} not found: {1}".format (instance_id, instance_info)}
    logger.info ("Retrieved details for instance: {0}".format (instance_info))

    image_id = instance_info['ImageId']
    # ensure the instance's image is approvied for use (is signed)
    image_tags = ec2_client.describe_tags (Filters = [{"Name": "resource-id", "Values": [image_id]}, {"Name": "resource-type", "Values": ["image"]}])
    sig_part1 = None
    sig_part2 = None
    for tag in image_tags['Tags']:
        if tag['Key'] == "compliance:signature:part1":
            sig_part1 = tag['Value']
        if tag['Key'] == "compliance:signature:part2":
            sig_part2 = tag['Value']

    image_approved = False
    if sig_part1 is not None and sig_part2 is not None:
        public_key_param = ssm_client.get_parameter (Name='compliance.signature.publicKey')
        if 'Parameter' in public_key_param:
            public_key_str = public_key_param['Parameter']['Value']
            public_key_pem = base64.b64decode (public_key_str)
            public_key = PKCS1_PSS.new (public_key_pem)

            signature = base64.b64decode (sig_part1 + sig_part2)

            cipher = PKCS1_PSS.new (public_key)
            digest = SHA256.new ("{}:{}".format (region, image_id))

            image_approved = cipher.verify (digest, signature)
        else:
            logger.error ("No parameter returned by SSM")

    if not image_approved:
        stopInstance (instance_id)

    return {"instance": instance_id, "approved_image": image_approved}