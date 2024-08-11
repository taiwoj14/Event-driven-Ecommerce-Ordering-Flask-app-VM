import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
ses = boto3.client('ses')

ORDER_TABLE = os.environ['ORDER_TABLE']
INVENTORY_TABLE = os.environ['INVENTORY_TABLE']
PROCESSED_ORDERS_TABLE = os.environ['PROCESSED_ORDERS_TABLE']

def lambda_handler(event, context):
    for record in event['Records']:
        sns_message = json.loads(record['body'])  # Load the SQS body
        order = json.loads(sns_message['Message'])  # Load the actual order from the SNS message

        # Check if 'order_id' is present and not empty
        order_id = order.get('order_id')
        if not order_id:
            print(f"Error: 'order_id' not found or is empty in the order: {order}")
            continue  # Skip this record

        # Check if this order has already been processed
        if has_order_been_processed(order_id):
            print(f"Order {order_id} has already been processed. Skipping.")
            continue  # Skip this record

        # Process order: store in DynamoDB
        store_order_in_db(order)

        # Send confirmation email
        send_confirmation_email(order.get('customer_email', ''), order_id)

        # Update inventory
        update_inventory(order.get('items', []))

        # Mark the order as processed
        mark_order_as_processed(order_id)

    return {
        'statusCode': 200,
        'body': json.dumps('Order processed successfully!')
    }

def has_order_been_processed(order_id):
    table = dynamodb.Table(PROCESSED_ORDERS_TABLE)
    response = table.get_item(Key={'order_id': order_id})
    return 'Item' in response

def mark_order_as_processed(order_id):
    table = dynamodb.Table(PROCESSED_ORDERS_TABLE)
    table.put_item(Item={'order_id': order_id})

def store_order_in_db(order):
    table = dynamodb.Table(ORDER_TABLE)
    table.put_item(Item=order)

def send_confirmation_email(customer_email, order_id):
    response = ses.send_email(
        Source='karooboido@gmail.com',  # Replace with a verified SES email
        Destination={
            'ToAddresses': [customer_email]
        },
        Message={
            'Subject': {
                'Data': 'Order Confirmation'
            },
            'Body': {
                'Text': {
                    'Data': f'Thank you for your order. Your order ID is {order_id}.'
                }
            }
        }
    )

def update_inventory(items):
    table = dynamodb.Table(INVENTORY_TABLE)
    for item in items:
        if not item.get('item_id') or item.get('quantity') is None:
            print(f"Skipping invalid item entry: {item}")
            continue
        try:
            response = table.update_item(
                Key={'item_id': item['item_id']},
                UpdateExpression="SET quantity = if_not_exists(quantity, :start) - :val",
                ExpressionAttributeValues={
                    ':val': item['quantity'],
                    ':start': 0  # Default start value if quantity doesn't exist
                },
                ReturnValues="UPDATED_NEW"
            )
        except Exception as e:
            print(f"Error updating inventory for item {item}: {e}")
