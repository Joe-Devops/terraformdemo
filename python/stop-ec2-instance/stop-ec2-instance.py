import os
import boto3
region = os.environ['AWS_REGION']
instance = os.environ['InstanceId']
instances = [instance]
ec2 = boto3.client('ec2', region_name=region)

def stopec2instance(event, context):
    ec2.stop_instances(InstanceIds=instances)
    print('stopped your instances: ' + str(instances))
