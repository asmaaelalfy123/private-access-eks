#!/bin/bash

REGION="us-east-1"

# Get all non-default VPC IDs
VPC_IDS=$(aws ec2 describe-vpcs --region $REGION \
  --filters "Name=isDefault,Values=false" \
  --query 'Vpcs[*].VpcId' --output text)

for VPC_ID in $VPC_IDS; do
  echo "Processing VPC: $VPC_ID"
  
  # 1. Delete NAT Gateways
  NAT_GWS=$(aws ec2 describe-nat-gateways --region $REGION \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[*].NatGatewayId' --output text)
  for NAT in $NAT_GWS; do
    echo "  Deleting NAT Gateway: $NAT"
    aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $NAT
  done
  
  # 2. Terminate EC2 instances
  INSTANCES=$(aws ec2 describe-instances --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)
  if [ ! -z "$INSTANCES" ]; then
    echo "  Terminating instances: $INSTANCES"
    aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCES
  fi
  
  # 3. Delete Load Balancers (ALB/NLB)
  LBS=$(aws elbv2 describe-load-balancers --region $REGION \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
  for LB in $LBS; do
    echo "  Deleting Load Balancer: $LB"
    aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn $LB
  done
  
  # 4. Delete RDS instances
  RDS_INSTANCES=$(aws rds describe-db-instances --region $REGION \
    --query "DBInstances[?DBSubnetGroup.VpcId=='$VPC_ID'].DBInstanceIdentifier" --output text)
  for RDS in $RDS_INSTANCES; do
    echo "  Deleting RDS instance: $RDS"
    aws rds delete-db-instance --region $REGION \
      --db-instance-identifier $RDS --skip-final-snapshot
  done
  
  # Wait for NAT Gateways to delete (takes a few minutes)
  echo "  Waiting for NAT Gateways to delete..."
  sleep 60
  
  # 5. Release Elastic IPs
  EIP_ALLOCS=$(aws ec2 describe-addresses --region $REGION \
    --filters "Name=domain,Values=vpc" \
    --query 'Addresses[*].AllocationId' --output text)
  for EIP in $EIP_ALLOCS; do
    echo "  Releasing EIP: $EIP"
    aws ec2 release-address --region $REGION --allocation-id $EIP 2>/dev/null || true
  done
  
  # 6. Delete Endpoints
  ENDPOINTS=$(aws ec2 describe-vpc-endpoints --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'VpcEndpoints[*].VpcEndpointId' --output text)
  for EP in $ENDPOINTS; do
    echo "  Deleting VPC Endpoint: $EP"
    aws ec2 delete-vpc-endpoints --region $REGION --vpc-endpoint-ids $EP
  done
  
  # 7. Delete Security Groups (except default)
  SGS=$(aws ec2 describe-security-groups --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
  for SG in $SGS; do
    echo "  Deleting Security Group: $SG"
    aws ec2 delete-security-group --region $REGION --group-id $SG 2>/dev/null || true
  done
  
  # 8. Delete Network Interfaces
  ENIS=$(aws ec2 describe-network-interfaces --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)
  for ENI in $ENIS; do
    echo "  Deleting Network Interface: $ENI"
    aws ec2 delete-network-interface --region $REGION --network-interface-id $ENI 2>/dev/null || true
  done
  
  # 9. Detach and Delete Internet Gateways
  IGWS=$(aws ec2 describe-internet-gateways --region $REGION \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[*].InternetGatewayId' --output text)
  for IGW in $IGWS; do
    echo "  Detaching and deleting IGW: $IGW"
    aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW --vpc-id $VPC_ID
    aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW
  done
  
  # 10. Delete Subnets
  SUBNETS=$(aws ec2 describe-subnets --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].SubnetId' --output text)
  for SUBNET in $SUBNETS; do
    echo "  Deleting Subnet: $SUBNET"
    aws ec2 delete-subnet --region $REGION --subnet-id $SUBNET
  done
  
  # 11. Delete Route Tables (except main)
  RTS=$(aws ec2 describe-route-tables --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
  for RT in $RTS; do
    echo "  Deleting Route Table: $RT"
    aws ec2 delete-route-table --region $REGION --route-table-id $RT
  done
  
  # 12. Delete Network ACLs (except default)
  ACLS=$(aws ec2 describe-network-acls --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkAcls[?IsDefault==`false`].NetworkAclId' --output text)
  for ACL in $ACLS; do
    echo "  Deleting Network ACL: $ACL"
    aws ec2 delete-network-acl --region $REGION --network-acl-id $ACL
  done
  
  # 13. Finally, delete the VPC
  echo "  Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID
  
  echo "VPC $VPC_ID deleted successfully!"
done

echo "All non-default VPCs removed from $REGION"