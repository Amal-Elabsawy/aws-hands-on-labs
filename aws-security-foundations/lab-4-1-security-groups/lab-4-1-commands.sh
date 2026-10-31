#!/bin/bash
# Lab 4.1: commands from the lab (Tasks 7 and 8).
# Everything else in this lab was done in the console (VPC, EC2, security groups, network ACL).
# Tasks 7 ran in the lab's built-in Ubuntu terminal, so no PuTTY is needed.
# "# Expected:" is what the lab says the result looks like. Replace it with the real output
# from your terminal if you want to show it.
#
# Replace these with the values from the lab's "AWS Details" panel:
#   BASTION_PUBLIC_IP       the BastionPublicIP value
#   APPSERVER_PRIVATE_IP    the AppServerPrivateIP value (starts with 10.0.)

# ===== Task 7: connect to the AppServer through the bastion host =====

# 1. Start the SSH agent and add the lab key to it (in the lab's Ubuntu terminal)
exec ssh-agent bash
ssh-add ~/.ssh/labsuser.pem
# Expected: "Identity added: /home/.../.ssh/labsuser.pem"

# 2. Connect to the bastion host, forwarding the agent with -A (answer "yes" to the first-connection prompt)
ssh -i ~/.ssh/labsuser.pem -A ec2-user@BASTION_PUBLIC_IP
# Expected: the prompt changes to [ec2-user@bastion]

# --- now on the bastion ---

# 3. Connect from the bastion to the AppServer in the private subnet (answer "yes" again)
ssh ec2-user@APPSERVER_PRIVATE_IP
# Expected: the prompt changes to [ec2-user@appserver]

# --- now on the AppServer ---

# 4. Create a file that proves I connected (the lab checks for it when you submit)
touch newfile.txt
# Expected: no output.

# 5. Leave the AppServer, then leave the bastion
exit
# Expected: the prompt goes back to [ec2-user@bastion]
exit
# Expected: the prompt goes back to the Ubuntu terminal (@runweb), outside the AWS account.

# ===== Task 8: connect with Session Manager (no SSH, no bastion) =====
# In the EC2 console: Instances > AppServer > Connect > Session Manager tab > Connect.
# A browser tab opens with a "sh-4.2" prompt on the AppServer. Run this in that session:

# 6. Change the website text on the AppServer
sudo sed -i 's/instance!/instance! Session manager was used to edit this file./g' /var/www/html/index.html
# Expected: no output. Reload the ProxyServer1 public IP in the browser (hard refresh) and the page
# now says "Session manager was used to edit this file."
