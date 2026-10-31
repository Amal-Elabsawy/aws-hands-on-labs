#!/bin/bash
# Lab 07: commands run on the Command Host over SSH.
# The only console steps were removing the Environment tag from two instances (challenge)
# and checking the instances in the EC2 console.
# Replace the placeholder values, and paste the real output under each command as a comment
# before committing.

# 1. Connect to the Command Host (Windows users did this step in PuTTY with labsuser.ppk)
chmod 400 labsuser.pem
ssh -i labsuser.pem ec2-user@COMMAND_HOST_PUBLIC_IP

# --- Now on the Command Host ---

# 2. Find all instances of the ERPSystem project (long output, keep only the top in the file)
aws ec2 describe-instances --filter "Name=tag:Project,Values=ERPSystem"
# Output:

# 3. Only the instance IDs
aws ec2 describe-instances --filter "Name=tag:Project,Values=ERPSystem" --query 'Reservations[*].Instances[*].InstanceId'
# Output:

# 4. ID and Availability Zone
aws ec2 describe-instances --filter "Name=tag:Project,Values=ERPSystem" --query 'Reservations[*].Instances[*].{ID:InstanceId,AZ:Placement.AvailabilityZone}'
# Output:

# 5. ID, zone and all three tag values
aws ec2 describe-instances --filter "Name=tag:Project,Values=ERPSystem" --query 'Reservations[*].Instances[*].{ID:InstanceId,AZ:Placement.AvailabilityZone,Project:Tags[?Key==`Project`] | [0].Value,Environment:Tags[?Key==`Environment`] | [0].Value,Version:Tags[?Key==`Version`] | [0].Value}'
# Output:

# 6. Only the development instances of ERPSystem (expect two)
aws ec2 describe-instances --filter "Name=tag:Project,Values=ERPSystem" "Name=tag:Environment,Values=development" --query 'Reservations[*].Instances[*].{ID:InstanceId,AZ:Placement.AvailabilityZone,Project:Tags[?Key==`Project`] | [0].Value,Environment:Tags[?Key==`Environment`] | [0].Value,Version:Tags[?Key==`Version`] | [0].Value}'
# Output:

# 7. Read the script that changes the Version tag, then run it
cat change-resource-tags.sh
./change-resource-tags.sh
# Output:

# 8. Check that only the development instances changed to 1.1 (same query as step 5)
aws ec2 describe-instances --filter "Name=tag:Project,Values=ERPSystem" --query 'Reservations[*].Instances[*].{ID:InstanceId,AZ:Placement.AvailabilityZone,Project:Tags[?Key==`Project`] | [0].Value,Environment:Tags[?Key==`Environment`] | [0].Value,Version:Tags[?Key==`Version`] | [0].Value}'
# Output:

# 9. Stop the ERPSystem development instances by tag, then check the EC2 console
cd aws-tools
cat stopinator.php
./stopinator.php -t"Project=ERPSystem;Environment=development"
# Output:

# 10. Start them again with -s, then check the EC2 console
./stopinator.php -t"Project=ERPSystem;Environment=development" -s
# Output:

# --- Challenge: tag-or-terminate ---
# First remove the Environment tag from two private instances in the EC2 console.
# Use the Availability Zone without its last letter as REGION (for example us-west-2a -> us-west-2)
# and the Subnet ID of the private subnet as SUBNET_ID.

# 11. Read the script, then run it
cat terminate-instances.php
./terminate-instances.php -region REGION -subnetid SUBNET_ID
# Output:
