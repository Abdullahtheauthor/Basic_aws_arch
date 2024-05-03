#!bin/bash
# Declaring value
# The aws profile is in the region in eu-central-1 -> Frankfurt
AWS_PROFILE="***"       # Add your AWS profile here
export AWS_PROFILE
PC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
DemoDBSubnetGroup="DemoDBSubnetGroup"

create_vpc(){
echo "Creating new VPC"
check_vpc=$(aws ec2 describe-vpcs --region eu-central-1 --filters "Name=tag:Name,Values=devops-vpc" | jq -r '.Vpcs[0].VpcId')
if [ "$check_vpc" == "null" ]; then

    vpc_output=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 --region eu-central-1 \
    --tag-specification ResourceType=vpc,Tags="[{Key=Name,Value=devops-vpc}]" \
    --output json)
    echo $vpc_output

    VPC_ID=$(echo $vpc_output | jq -r '.Vpc.VpcId')

    if [ "$VPC_ID" == "" ]; then
        echo "Error creating VPC"
        exit 1
    fi
        echo "The VPC is created."
        echo "================================================="

else

    VPC_ID=$check_vpc
    echo "VPC is already there and it is id is $VPC_ID"
    echo "================================================="
    
fi
}

# echo "================================================="

#Creating a function to create subnet
# $1 subnet number, $2 az(a,b,c), $3 public or private
create_subnet()
{
check_vpc=$(aws ec2 describe-subnets --region eu-central-1 --filters Name=tag:Name,Values=subnet-$3-$1 | jq -r '.Subnets[0].SubnetId')


if [ "$check_vpc" == "null" ]; then

 
        subnet_Op=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --availability-zone eu-central-1$2 \
        --cidr-block 10.0.$1.0/24 \
        --tag-specifications ResourceType=subnet,Tags="[{Key=Name,Value=subnet-$3-$1}]" \
        --output json )

        echo $subnet_Op
        SUBNET_ID=$(echo $subnet_Op | jq -r '.Subnet.SubnetId')
        echo "Subnet is created"

        if [ "$SUBNET_ID" == "" ]; then

            echo "Error in creating the subnet $1"
            echo "================================================="
            exit 1
        fi
  
####
else
    SUBNET_ID=$check_vpc
    echo "This subnet is already there and it ID is $SUBNET_ID"
    echo "================================================="
fi
}

# echo "Creating Subnets"
# create_subnet 1 a public
# SUBENTID_1=$SUBNET_ID
# create_subnet 2 b public
# SUBENTID_2=$SUBNET_ID
# create_subnet 3 a private
# SUBENTID_3=$SUBNET_ID
# create_subnet 4 b private
# SUBENTID_4=$SUBNET_ID

# echo "================================================="

create_IGW(){


check_IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=devops-igw"  | jq -r '.InternetGateways[0].InternetGatewayId')

if [ "$check_IGW" == "null" ]; then
    echo "Creating Internet Gateway"
    IGW_op=$(aws ec2 create-internet-gateway \
        --tag-specifications ResourceType=internet-gateway,Tags="[{Key=Name,Value=devops-igw}]")

    IGW_ID=$(echo $IGW_op | jq -r '.InternetGateway.InternetGatewayId')
    echo "the Inetenet GW is created and its ID is $IGW_ID"
    echo "================================================="

    if [ "$IGW_ID" == "" ]; then

        echo "Error in creating the Inetenet GW"
        exit 1
    fi
else
    IGW_ID=$check_IGW
    echo "the Inetenet GW is already there and its ID is $IGW_ID"
    echo "================================================="



fi
}


# echo "================================================="
# Attaching Internet GW to the VPC
attach_IGW_VPC(){
check_IGW_Attachment=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=devops-igw" | jq -r '.InternetGateways[0].Attachments[0].VpcId')

if [ "$check_IGW_Attachment" != "$VPC_ID" ]; then
    Attachment_op=$(aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID)

    if [ "$Attachment_op" == ""  ]; then
        echo "Attachment of Internet Gw to the vpc is successful"
        echo "================================================="
    else
        echo "Attachment is failed"
    fi

else

    echo "This Internet GW is already attached"
    echo "================================================="
fi
}



# echo "================================================="
# Creating route tables and create routes to public ip for public tables only
# $1 (String -> public or private)
create_RT() {
check_RT=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=$1-devops-RT" | jq -r '.RouteTables[0].RouteTableId')    
    # echo "first arg is $1"
if [ "$check_RT" == "null" ]; then
    RT_OP=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications ResourceType=route-table,Tags="[{Key=Name,Value=$1-devops-RT}]")

    echo $RT_OP
    RT_ID=$(echo $RT_OP | jq -r '.RouteTable.RouteTableId')


    if [ "$RT_ID" == "null" ]; then
        echo "Error in creating the Route-table $1-devops-RT"
        exit 1
    fi
        echo "Route table is successfully created and it ID is $RT_ID"
        echo "================================================="
        

# Creating routing association to public IGW in case that the subnet is public
    if [ "$1" == "public" ]; then
        route_result=$(aws ec2 create-route --route-table-id $RT_ID \
        --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID | jq -r '.Return')
        echo $route_result

        if [ "$route_result" == "true" ]; then
            echo "Route rule association is successfully created"
            aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBENTID_1
            aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBENTID_2
        else
            echo "Error: Route asssociation failed"
            exit 1    
        fi
    else
        aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBENTID_3
        aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBENTID_4
   
    # elif [ "$1" == "private" ]; then
    #     route_result=$(aws ec2 create-route --route-table-id $RT_ID \ 
    #     --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID)

    #     if [ "$route_result" == true ]; then
    #         echo "Route association is successfully created"
    #     fi
    #     echo "Error: Route asssociation failed"
    #     exit 1

    fi 
else
    RT_ID=$check_RT
    echo "Route table whose ID: $RT_ID is already created"
    echo "================================================="



fi   


# echo "================================================="
}
# # Creating public route
# echo "Creating Public subnet and associate it forward traffic to IGW if neded to go to 0.0.0.0/0 i.e internet"
# create_RT public
# # Creating public route
# create_RT private



#Create NACL
create_NACL(){
check_NACL=$(aws ec2 describe-network-acls \
 --filters "Name=tag:Name,Values=devops-NACL" | jq -r '.NetworkAcls[0].NetworkAclId') 

if [ "$check_NACL" == "null" ]; then
    NACL_OP=$(aws ec2 create-network-acl --vpc-id $VPC_ID \
    --tag-specifications ResourceType=network-acl,Tags="[{Key=Name,Value=devops-NACL}]")
    

    NACL_ID=$(echo "$NACL_OP" | jq -r '.NetworkAcl.NetworkAclId')

    if [ "$NACL_ID" == "" ]; then
        echo "Creation of NACL is failed"
    else
        echo "Successfully created NACL and its ID is $NACL_ID"
        echo "================================================="
        # create NACL entry to y IP
        NACL_ENTRY_OP=$(aws ec2 create-network-acl-entry --network-acl-id $NACL_ID \
        --ingress --rule-number 100 --protocol -1 --cidr-block $PC_IP/32 --rule-action allow)
        # This line was written to allow LB to access the instance
        aws ec2 create-network-acl-entry --network-acl-id $NACL_ID \
        --ingress --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow)
    if [ "$NACL_ENTRY_OP" == "" ]; then
        echo "NACL entry is successful"
        echo "================================================="
    else
        echo "NACL entry creation failed"
    fi
    fi


else
    # elif [ "$check_NACL" == "$VPC_ID" ]; then


    NACL_ID=$check_NACL
    echo "This NACL table is already created and its ID is $NACL_ID"
    echo "================================================="

fi
}
# to bring the default NACL
# aws ec2 describe-network-acls --query "NetworkAcls[?IsDefault"]

# Getting the Association id of the default NACL
# Association_ID=$(aws ec2 describe-network-acls \
# --query "NetworkAcls[?IsDefault"] | jq -r '.[0].Associations[0].NetworkAclAssociationId')
# echo $Association_ID
# echo $NACL_ID

# aws ec2 replace-network-acl-association --association-id $Association_ID --network-acl-id $NACL_ID

attach_subnets_to_NACL() {

NW_AS_IDS=$(aws ec2 describe-network-acls --query "NetworkAcls[?IsDefault"] | jq -r '.[0].Associations[].NetworkAclAssociationId')
if [ "$NW_AS_IDS" == "" ]; then
    echo "There are no NACL attached to default NACL"
    echo "================================================="
else 
for NW_AS_ID in ${NW_AS_IDS[*]}; do
   echo "$NW_AS_ID"
   aws ec2 replace-network-acl-association --association-id $NW_AS_ID --network-acl-id $NACL_ID
done
fi

}


#Calling functions
create_vpc
echo "Creating Subnets"
create_subnet 1 a public
SUBENTID_1=$SUBNET_ID
create_subnet 2 b public
SUBENTID_2=$SUBNET_ID
create_subnet 3 a private
SUBENTID_3=$SUBNET_ID
create_subnet 4 b private
SUBENTID_4=$SUBNET_ID
create_IGW
attach_IGW_VPC
# Creating public route
echo "Creating Public subnet and associate it forward traffic to IGW if neded to go to 0.0.0.0/0 i.e internet"
create_RT public
# Creating public route
create_RT private
create_NACL
attach_subnets_to_NACL
echo ""
echo ""
echo "                                    =====================Done============================                                    "

















