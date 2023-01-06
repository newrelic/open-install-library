import json
import boto3
import os
from datetime import datetime, timedelta, timezone

region = 'ca-central-1'
keypair_name = 'gitdeployerCanada'
prefix_match = 'gitusdkr'

ec2 = boto3.client('ec2', region_name=region)

def lambda_handler(event, context):
    summary = ''
    instance_ids = []
    response = ec2.describe_instances(Filters=[
        {
            'Name': 'key-name',
            'Values': [keypair_name]
        },
        {
            'Name': 'instance-state-name',
            'Values': ['running']
        },
    ])
    if 'Reservations' in response and response['Reservations'] and len(response['Reservations']) > 0:
        for reservation in response['Reservations']:
            if 'Instances' in reservation:
                for instance in reservation['Instances']:
                    if 'Tags' in instance and len(instance['Tags']) > 0:
                        for element in instance['Tags']:
                            if 'Key' in element and element['Key'] == 'Name':
                                instance_name = element['Value']
                                launch_time = instance['LaunchTime']
                                instance_id = instance['InstanceId']
                                print('Working on name:' +instance_name +' instance_id:' +instance_id +' launch_time:' +launch_time.strftime('%m/%d/%Y'))
                                if instance_name.startswith(prefix_match):
                                    time_between = datetime.now(timezone.utc) - launch_time
                                    if time_between.days> 1:
                                        text = 'Terminating instance: ' +str(instance_name) +' with id:' +str(instance_id) +' with launch time at ' +str(launch_time) +' which was ' +str(time_between.days) +' days ago'
                                        print(text)
                                        summary = summary +text +'\n'
                                        instance_ids.append(instance_id)

    if len(instance_ids) > 0:
        print('Terminating instances:'+str(instance_ids) +"...")
        ec2.terminate_instances(InstanceIds=instance_ids)

    if summary != '':
        notificationArn = os.environ.get('SNS_TERMINATE_EC2_ARN', '')
        if notificationArn != '':
            print('Sending notification')
            client = boto3.client('sns')
            try:
                response = client.publish (
                    TargetArn = notificationArn,
                    Subject = context.function_name,
                    Message = summary,
                    MessageStructure = 'text'
                )
            except Exception as err:
                print('Error while sending notification, detail:' +err)

    print('Terminated ' +str(len(instance_ids)) +' instances')

    return {
        'statusCode': 200,
        'body': json.dumps('Terminated ' +str(len(instance_ids)) +' instances')
    }
