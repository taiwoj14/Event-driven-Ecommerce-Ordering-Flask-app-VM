from flask import Flask, render_template, request, redirect, url_for
import boto3
import json

app = Flask(__name__)

# Initialize SNS client
sns = boto3.client('sns', region_name='eu-west-2')  # Update with your region

TOPIC_ARN = 'arn:aws:sns:eu-west-2:335871625378:order-notifications-topic'  # Replace with your SNS topic ARN

@app.route('/')
def index():
    # Get query parameters for displaying messages
    success_message = request.args.get('success')
    error_message = request.args.get('error')
    email = request.args.get('email')
    
    return render_template('index.html', success=success_message, error=error_message, email=email)

@app.route('/submit_order', methods=['POST'])
def submit_order():
    order_id = request.form.get('order_id')
    customer_email = request.form.get('customer_email')
    items = []

    # Extract item details from the form
    for i in range(len(request.form.getlist('items[0][item_id]'))):
        item_id = request.form.get(f'items[{i}][item_id]')
        quantity_str = request.form.get(f'items[{i}][quantity]')

        # Skip empty or invalid item entries
        if not item_id or not quantity_str:
            continue

        try:
            quantity = int(quantity_str)
            items.append({
                'item_id': item_id,
                'quantity': quantity
            })
        except ValueError as e:
            # Log the error and return an error message
            app.logger.error(f"Invalid quantity format: {quantity_str} - {e}")
            return redirect(url_for('index', error='Invalid quantity format'))

    # Create order message
    order_message = {
        'order_id': order_id,
        'customer_email': customer_email,
        'items': items
    }

    # Publish message to SNS
    try:
        sns.publish(
            TopicArn=TOPIC_ARN,
            Message=json.dumps(order_message)
        )
        return redirect(url_for('index', success='Order submitted successfully!', email=customer_email))
    except Exception as e:
        app.logger.error(f"Error submitting order: {e}")
        return redirect(url_for('index', error='Failed to submit order'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
