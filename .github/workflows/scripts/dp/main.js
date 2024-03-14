const fs = require('fs')
const {SQSClient, SendMessageCommand} = require('@aws-sdk/client-sqs')
const {DynamoDBClient, QueryCommand} = require('@aws-sdk/client-dynamodb')
const {unmarshall} = require('@aws-sdk/util-dynamodb')

const AWS_REGION = process.env.AWS_REGION
const SQS_URL = process.env.SQS_URL
const DYNAMO_TABLE = process.env.DYNAMO_TABLE
const AWS_CREDS = {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
};

const sqs = new SQSClient({region: AWS_REGION, credentials: AWS_CREDS})
const dynamodb = new DynamoDBClient({region: AWS_REGION, credentials: AWS_CREDS})


function queryForDeploymentStatus(messageId) {
    const query_params = {
        TableName: DYNAMO_TABLE,
        KeyConditionExpression: 'id = :id',
        FilterExpression: 'completed = :completed',
        ExpressionAttributeNames: {
            '#id': 'id',
            '#completed': 'completed',
            '#status': 'status',
            '#message': 'message',
        },
        ExpressionAttributeValues: {
            ':id': {
                S: messageId,
            },
            ':completed': {
                BOOL: true,
            },
        },
        ProjectionExpression: '#id, #completed, #status, #message',
        ScanIndexForward: false,  //returns items by descending timestamp
    }
    return new QueryCommand(query_params)
}

async function isDeploymentSuccessful(deploymentId, retries, waitSeconds) {
    for (let i = 0; i < retries; i++) {

        try {
            const response = await dynamodb.send(queryForDeploymentStatus(deploymentId))
            for (let i = 0; i < response.Items.length; i++) {
                const item = unmarshall(response.Items[i])
                if (item.completed) {
                    if (item.status === 'FAILED') {
                        console.error(`::error:: Deployment failed: ${item.message}`)
                        return false
                    }

                    return true
                }
            }

            console.log(`Deployment pending, sleeping ${waitSeconds} seconds...`)
            await sleep(waitSeconds * 1000)

        } catch (err) {
            console.log(`Error querying table: ${err}`)
        }
    }
    return false
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms))
}

async function main() {
    let messageId
    let configJson = fs.readFileSync(`${process.env.GITHUB_WORKSPACE}/${JSON.parse(process.env.MATRIX).testDefinitionFile}`)
    try {
        const command = new SendMessageCommand({
            QueueUrl: SQS_URL,
            MessageBody: configJson,
        })
        data = await sqs.send(command);
        messageId = data.MessageId
        console.log(`Message sent: ${messageId}`)
    } catch (err) {
        console.log(err.message)
        throw new Error('Failed sending message to SQS queue');
    }

    // Initial sleep since fargate takes time to spin up deployer
    await sleep(120 * 1000)

    // Execute the query with retries/sleeps
    let RETRIES = 50, WAIT_SECONDS = 30
    const success = await isDeploymentSuccessful(messageId, RETRIES, WAIT_SECONDS)
    if (!success) {
        throw new Error(`Deployment failed for ${messageId} after ${RETRIES} retries`);
    }

    console.log(`Successfully install New Relic for instanceId ${messageId}!`)
}

if (require.main === module) {
    main().then(() => {
        console.log('::set-output name=exit_status::0')
    }).catch((err) => {
        console.error(`::error::${err}`)
        console.error('::set-output name=exit_status::1')
    })
}