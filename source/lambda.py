import json
import ast
import os
import boto3
import sys
from botocore.vendored import requests
import decimal
from boto3.dynamodb.conditions import Key, Attr
from botocore.exceptions import ClientError

def handler(event, context):
    # ### Initializations
    region_name = 'us-east-1'
    tvdb_page_number = 1
    tvdb_series_id = '70600'
    nbc_page_size = '4'
    nbc_url = 'https://api.nbc.com/v3.14/videos?filter[published]=1&filter[entitlement]=free&sort=-airdate&filter[show]=a1b2acc5-6d4d-4dcc-9355-6523b7cae422&page[size]=' + nbc_page_size
    topic_arn = os.environ['topicArn']
    secret_arn = os.environ['secretArn']
    table_name = os.environ['tableName']

    # Get the the last <nbc_page_size> episodes from the NBC api
    try:
        response = requests.get(nbc_url)
    except requests.exceptions.RequestException as e:
        raise
        sys.exit(1)
    else:
        if(response.ok):
            nbc_episodes = json.loads(response.content)
        else:
            # If response code is not ok then print the response and exit
            response.raise_for_status()
            sys.exit(1)

    # Get the TVDB api keys from the secret and then obtain an auth token from the TVDB api
    secret = get_secret(secret_arn, region_name)
    auth_data = {"apikey": secret['apikey'], "userkey": secret['userkey'], "username": secret['username']}
    auth_token = get_tvdb_token(auth_data)

    # Get the first page of episodes from the TVDB api
    episode_page = get_tvdb_page(tvdb_series_id, tvdb_page_number, auth_token)

    # Pull out the episode data and last page count from the episode page
    episode_data = episode_page['data']
    tvdb_last_page = episode_page['links']['last']

    # For each of the episodes from NBC find the episode in the TVDB list to get the season and episode number
    # Then add the episode to the DynamoDB table and send an SMS message
    # If the episode already exists in the DynamoDB table then do nothing
    for episode in nbc_episodes['data']:
        while True:
            out = next((item for item in episode_data if item.get("episodeName") and item["episodeName"].lower() == episode['attributes']['title'].lower()), None)
            if out:
                # The episode was found in TheTVDB
                episode_filename = 'Dateline NBC - S' + str(out['airedSeason']).zfill(2) + 'E' + str(out['airedEpisodeNumber']).zfill(2) + ' - ' + out['episodeName']
                print(episode_filename)
                send = True
            elif tvdb_last_page == tvdb_page_number:
                # Not found in TVDB at all
                episode_filename = 'Dateline NBC - S??E?? - ' + out['episodeName']
                print(episode_filename)
                send = True
            else:
                # Not found in the current page, so get the next page of episodes
                # Add the new episode_data list to the existing list so that it can be reused for subsequent loops
                tvdb_page_number += 1
                episode_page = get_tvdb_page(tvdb_series_id, tvdb_page_number, auth_token)
                episode_data = episode_data + episode_page['data']

            # add to the db and send a notification if there is an episode found
            if send == True:
                result = dynamo_put_episode(table_name, episode, region_name)
                if result == "success":
                    sns_message = episode_filename + '\n' + episode['attributes']['fullUrl']
                    sms_send_message(topic_arn, sns_message, region_name)
                elif result == "failure":
                    pass
                elif result == "exists":
                    pass
                else:
                    pass
                break

def dynamo_put_episode(table, episode, region_name):
    dynamodb = boto3.resource("dynamodb", region_name=region_name)

    table = dynamodb.Table(table)

    try:
        table.put_item(
            Item={
                'title': episode['attributes']['title'],
                'updated': episode['attributes']['updated'],
                'fullUrl': episode['attributes']['fullUrl'],
                'description': episode['attributes']['description'],
                'internalId': str(episode['attributes']['internalId'])
            },
            ConditionExpression='attribute_not_exists(internalId)'
        )
    except ClientError as e:
        # Ignore the ConditionalCheckFailedException, bubble up other exceptions.
        print('exists in the DynamoDB')
        if e.response['Error']['Code'] != 'ConditionalCheckFailedException':
            result = "exists"
            raise
        else:
            result = "failed"
    else:
        print('success')
        result = "success"
    return result

def sms_send_message(topic_arn, body, region_name):
    # Create an SNS client
    client = boto3.client("sns", region_name)

    # Publish a message.
    client.publish(Message=body, TopicArn=topic_arn)

def get_tvdb_token(auth_data):
    response = requests.post('https://api.thetvdb.com/login', json=auth_data)
    token = json.loads(response.content)
    return token

def get_tvdb_page(series_id, page_number, auth_token):

    headers = {"Authorization" : "Bearer " + auth_token['token']}
    
    response = requests.get('https://api.thetvdb.com/series/' + series_id + '/episodes?page=' + str(page_number), headers=headers)
    episode_data =  json.loads(response.content)

    return episode_data

def get_secret(secret_name, region_name):

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name,
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            print("The requested secret " + secret_name + " was not found")
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            print("The request was invalid due to:", e)
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            print("The request had invalid params:", e)
    else:
        secret = ast.literal_eval(get_secret_value_response['SecretString'])
        return secret