Author: Oghenekaro Oboido

Explanation of the Application:

Our Application is a highly scalable Flask Based orders taking Application installed on an EC2 configured with an Autoscaling group, ensuring Customers or users get notification for successful orders, we implement an event driven system where the orderes placed by the user gets sent to an SNS topic, which then sends the message to an SQS Queue(SQS is subscribed to the Topic), once the message is in the SQS Message Queue, Our Lambda Function gets triggered and processes the message in the Queue, Once the message gets processed, the Lambda function then updates our DynamoDB tables(count, inventory, processed orders). DynamoDB is a NOSQL Database, the Lambda function also helps us to send email confirmation to each customers using SES for successful orders, we used custom networking for the app deployment, the app itself is deployed in a private subnet. we also use ACM for ssl termination for our domain which we use to access the app. We also configure a WAF infront of our Load Balancer for protecttion against DDOS Attack. See architectural diagram herein attached.

![image](https://github.com/user-attachments/assets/5ef3b484-33f7-4e78-8a90-d04dd5987d4b)

KEY RESOURCES USED in setting this up and what they do

Networking: We create a Custom network infrastructure where the app is deployed into our private subnets (VPC, Public and Private Subnets, IGW, NAT GW, Public and Private Route Tables, and Route table assosciations for the respective route tables and subnets)

EC2: We will deploy our Flask ordering app on an EC2 Virtual machine, When an Order is made from the UI, a notification gets sent to the SNS Topic for onward sqs queue,  

SNS Topic: Represents the event of an order being placed. When an order is placed, a message is published to this topic.

SQS Queue: Receives the message from the SNS topic. The queue ensures that even if the processing is slow or the Lambda function fails, the message remains in the queue for future retries.

SES: Simple Email Service will be used as our Email Server in this scenario

Lambda Function: Processes the order by:

Updating the order status in the DynamoDB table. Reducing the inventory counts in the DynamoDB inventory table. Sending a confirmation email to the customer.

DynamoDB Table: DynamoDB table will be used for storing our Orders and Inventory count

Cloudwatch: Cloudwatch will be used for monitoring and troubleshooting incase there is issue, our Lambda function is configured to send Logs to Lambda

ASG: for high availability and scalability

WAF: to protect our App from DDOS Attacks/Threats


REAL-WORLD Use Case

In a real-world e-commerce platform, this architecture ensures reliable and scalable order processing. Even if the inventory service or email service is temporarily unavailable, the system continues to function without losing orders. Each step in the processing pipeline can be independently scaled and managed.

Let's Test our Example then

To test our example, we will make an order from our website, this will publish a message to the SNS topic from the App Gui, when the order is placed. 

![image](https://github.com/user-attachments/assets/b514cb83-76a2-45ae-b92c-86e37ef49828)


![image](https://github.com/user-attachments/assets/a49b0d0f-1b43-49b7-b317-9da676b88429)


NOTE: In our Scenario, we must verify both our Sender Email and Recipient Email, See Note below

Sandbox Restrictions:

SES accounts start in a sandbox mode by default. In this mode, we can only send emails to and from verified email addresses. This includes any recipient email addresses. This restriction is in place to prevent spam and to help you test your email sending capabilities without risk of sending unsolicited emails.

Email Verification:

SES requires you to verify each email address (both sender and recipient) to ensure that the emails are being sent to willing recipients, even during testing. Verification involves Amazon SES sending a confirmation email to the specified address, and the recipient must click the link in the email to verify it.

Moving Out of the Sandbox:

Once you’re ready to send emails to unverified recipients, you can request to have your account moved out of the sandbox. When your account is in production mode, you no longer need to verify recipient emails, although sender emails must still be verified.

Implications for our Scenario as we are using SES in sandbox mode for our e-commerce order processing system:

All customer emails that we want to send order confirmations to must be verified. To avoid verification for each customer, we would need to apply to move our SES account out of sandbox mode. Once our account is out of the sandbox, we can send emails to any address without verifying it first.

How to Move SES Out of the Sandbox To lift these restrictions and send emails to unverified recipients:

Request Production Access:

In the AWS SES console, navigate to “Service Quotas” and request production access. we will need to provide some information about our use case, the volume of emails we intend to send, and how we handle unsubscribe requests, among other things.

Approval:

AWS reviews the request and, if approved, we can send emails to any address without prior verification.

Summary for our USE CASE When using SES in the sandbox, verifying customer emails ensures that our testing does not unintentionally send emails to unauthorized recipients. Moving out of the sandbox allows us to send emails to any customer without needing to verify each email address first.

