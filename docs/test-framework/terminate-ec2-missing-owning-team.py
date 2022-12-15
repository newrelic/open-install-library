import json
import boto3
import os

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    instance_count = 0
    response = ec2.describe_regions()
    summary = ''
    print('Region response:'+json.dumps(response))
    for region in response['Regions']:
        region_name = region['RegionName']
        # print('Processing region:'+json.dumps(region_name))
        
        ec2r = boto3.resource('ec2', region_name=region_name)

        all_running_instances = [i for i in ec2r.instances.filter(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])]
        # print('All running instances:'+json.dumps(len(all_running_instances)))

        instances = [i for i in ec2r.instances.filter(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}, {'Name':'tag:owning_team', 'Values':['*']}])]
        # print('With owning_team instances:'+json.dumps(len(instances)))

        instances_to_delete = [to_del for to_del in all_running_instances if to_del.id not in [i.id for i in instances]]
        # print('Delta instances:'+json.dumps(len(instances_to_delete)))
        
        if len(instances_to_delete) > 0:
            for instance in instances_to_delete:
                instance_count = instance_count+1
                text = 'Deleting from region:' +region_name +' instance with ID:' +str(instance.id) +" having tags:" +json.dumps(instance.tags) +' key_name:' +instance.key_name +' launch_time:' +str(instance.launch_time)
                instance.terminate()
                summary = summary +text +'\n'
                print(text)

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

    return {
        'statusCode': 200,
        'body': json.dumps('Terminated ' +str(instance_count) +' instances')
    }
