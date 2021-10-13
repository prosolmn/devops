param(
    [Parameter(Mandatory=$true)] 
    [string] $topic
,
    [Parameter(Mandatory=$true)] 
    [string] $sqs
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking  
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

#Get Topic Arn matching name provided
$topicArns = (aws sns list-topics --query 'Topics' --output json | ConvertFrom-Json)
ForEach ($topicArn in $topicArns){
    $topicName = $topicArn.TopicArn.split(":")[-1]

    if ("$topicName" -like "$topic"){
        $myTopicArn = $topicArn.TopicArn
        break
    }
}
if ($null -eq $myTopicArn){
    Write-Host "##[warning] topic not found: $topic"
    exit 1
}else{
    Write-Host "##[debug] Topic Arn found: $myTopicArn"
}

#Get SQS Arn
$sqsUrl = (aws sqs list-queues --queue-name-prefix "$sqs" --query 'QueueUrls' --output text)
$sqsArn = (aws sqs get-queue-attributes --queue-url "$sqsUrl" --attribute-names 'QueueArn' --output text)

#Get existing SQS subscription for topic arn
$subscriptions = (aws sns list-subscriptions --query 'Subscriptions' --output json | ConvertFrom-Json)
ForEach ($subscription in $subscriptions){
    if ($subscription.TopicArn -like "$myTopicArn" -and $subscription.Protocol -like "sqs"){
        $mySubscription = $subscription
        break
    }
}
if ($null -eq $mysubscription){
    Write-Host "##[warning] SQS subscription not found for: $myTopicArn"
    exit 1
}else{
    Write-Host "##[debug] SQS subscription found:" $mySubscription.SubscriptionArn
}

if ($mySubscription.Endpoint -like "$sqsArn"){
    Write-Host "##[debug] SQS subscription already exists for:" $mySubscription.Endpoint
    exit 0
}
$subscriptionAttributes = (aws sns get-subscription-attributes --subscription-arn $mySubscription.SubscriptionArn --query 'Attributes' --output json | ConvertFrom-Json)

#Create new subscription for topic arn
$subscriptionArn = (aws sns subscribe --topic-arn "$myTopicArn" --protocol 'sqs' --notification-endpoint "$sqsArn" --output text)
if (!($subscriptionArn -like "*${topic}*")){
    Write-Host "##[warning] new subscription not created: $subscriptionArn"
    exit 1
} else {
    Write-Host "##[debug] new subscription created: $subscriptionArn"
}

$attributes = @('DeliveryPolicy','FilterPolicy','RawMessageDelivery','RedrivePolicy')
ForEach ($attribute in $subscriptionAttributes.PSObject.Properties){
    if ($attributes -contains $attribute.Name){
        aws sns set-subscription-attributes --subscription-arn "$subscriptionArn" --attribute-name $attribute.Name --attribute-value $attribute.Value
    }
}

#Remove old Subscription for Topic Arn
Write-Host "##[debug] unsubscribing from:" $mySubscription.SubscriptionArn
aws sns unsubscribe --subscription-arn $mySubscription.SubscriptionArn