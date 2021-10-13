#/bin/sh

# Update DNS records in Route53

# Arguments :
# $1 : Domain name to update
# $2 : Load Balancer name to point

#profile="prophecyprod"
#region="us-east-1"

#domain_name="prophecyportal-qa.wright.com"
domain_name=$1
#lb_name="blu-frontend-alb"
lb_name=$2

#hosted_id_test="Z0884154VFAPXTISBVXY"

#echo "Profile : $profile"
#echo "Region : $region"
#echo "Hosted ID : $hosted_id_test"

echo "Domaine name : $1"
echo "Load balancer name : $2"
echo "\n"

#hosted_zone_id_temp=$(aws route53 list-hosted-zones --profile $profile --region $region | jq --arg name "$domain_name." -r '.HostedZones | .[] | select(.Name=="\($name)") | .Id')
hosted_zone_id_temp=$(aws route53 list-hosted-zones | jq --arg name "$domain_name." -r '.HostedZones | .[] | select(.Name=="\($name)") | .Id')
route53_hosted_zone_id=${hosted_zone_id_temp#"/hostedzone/"}

#elb_description=$(aws elbv2 describe-load-balancers --profile $profile | jq --arg lb_name "$lb_name" -r '.[][] | select(.LoadBalancerName==$lb_name) | .DNSName, .CanonicalHostedZoneId')
elb_description=$(aws elbv2 describe-load-balancers | jq --arg lb_name "$lb_name" -r '.[][] | select(.LoadBalancerName==$lb_name) | .DNSName, .CanonicalHostedZoneId')

elb_hosted_zone_id=$(echo $elb_description | awk -F ' ' '{print $2}')
elb_dns_name=$(echo $elb_description | awk -F ' ' '{print $1}')
target="dualstack."$elb_dns_name #return IPv4 & IPv6

echo "ELB Hosted Zone ID : $elb_hosted_zone_id"
echo "ELB DNS Name : $elb_dns_name"
echo "Route 53 Hosted Zone ID : $route53_hosted_zone_id"
echo "Route Target : $target"

echo "\n"

# Create JSON
cat > route53_update.json << EOF
{
  "Comment": "Update DNSName.",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$domain_name",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$elb_hosted_zone_id",
          "DNSName": "$target",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

echo 'Updating Route53 record '"$domain_name"' with '"$target"
cat route53_update.json


#change_id=$(aws route53 change-resource-record-sets --hosted-zone "$route53_hosted_zone_id" --change-batch "file://route53_update.json" --profile $profile | jq -r .ChangeInfo.Id | awk -F '/' '{print $3}')
change_id=$(aws route53 change-resource-record-sets --hosted-zone "$route53_hosted_zone_id" --change-batch "file://route53_update.json" | jq -r .ChangeInfo.Id | awk -F '/' '{print $3}')

echo "\n"
echo "Update done."
echo "Change Id : $change_id"

# aws route53 get-change --id $hos


