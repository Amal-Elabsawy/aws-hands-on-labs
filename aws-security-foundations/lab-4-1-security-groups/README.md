# Lab 4.1: Securing VPC Resources by Using Security Groups

**Type:** Guided lab | **Services:** VPC (subnets, route tables, network ACLs), EC2, Security Groups, Systems Manager Session Manager

## Goal
Control who can reach what inside a VPC. I started from a working network with two proxy servers in public subnets and an application server in a private subnet, then tightened access step by step with security groups and a network ACL, and finally reached the private server through a bastion host and through Session Manager.

**Proof:** CLI commands in [commands.sh](commands.sh), and step-by-step screenshots in the `screenshots` folder.

## Steps
1. **Analyzed the private subnet:** In `LabVPC` (`10.0.0.0/16`) I found three subnets: `PrivateSubnet`, `PublicSubnetA` and `PublicSubnetB`. The private subnet's route table sends local traffic inside the VPC and `0.0.0.0/0` to a NAT gateway in `PublicSubnetA`. I renamed that route table from `changeme` to `Private`. `AppServer` has only a private IP, and its `AppServerSG` allows HTTP (port 80) from anywhere and all outbound traffic.
2. **Analyzed the public subnets:** The public route table sends `0.0.0.0/0` to an internet gateway. `ProxyServer1` (`ProxySG`) and `ProxyServer2` (`ProxySG2`) both have public IPs. I added an inbound HTTP rule from Anywhere-IPv4 to `ProxySG2` so both proxy groups matched.
3. **Tested HTTP through the proxies:** Opened the public IP of each proxy server. Both loaded the website that runs on `AppServer`, because both proxies forward port 80 to it.
4. **Restricted by IP address:** Changed the `AppServerSG` HTTP rule from `0.0.0.0/0` to the private IP of `ProxyServer1` with `/32`. `ProxyServer1` still worked. `ProxyServer2` timed out, since its IP was no longer allowed.
5. **Restricted by security group:** Replaced the IP rule with a rule whose source is the `ProxySG` security group, then changed `ProxyServer2` to use `ProxySG` instead of `ProxySG2`. Both proxies worked again, with no IP list to maintain.
6. **Used a network ACL:** Added inbound rule 99 on the `LabVPC` network ACL to deny HTTP, and the website timed out even though the security group allowed it. Then I added rule 98 to allow HTTP, and the website loaded, because rules are checked from the lowest number first.
7. **Connected through a bastion host with SSH:** Renamed `ProxyServer2` to `Bastion`, created `BastionSG` (SSH from Anywhere-IPv4) and attached it in place of `ProxySG`. In `AppServerSG` I added an SSH rule from the bastion's private IP with `/32`. From the lab terminal I started `ssh-agent`, added the key, connected to the bastion with `-A`, then connected from the bastion to `AppServer` and created `newfile.txt` there as proof.
8. **Connected with Session Manager:** From the EC2 console I used **Connect** and the **Session Manager** tab on `AppServer`, with no bastion and no SSH. I edited the website file with a `sed` command and reloaded the page through the proxy to see the change.

## Troubleshooting
Most of the "problems" in this lab were the expected result of a rule I had just changed. I treated each one as a check that my rule did what I meant.

**`ProxyServer2` timed out after I restricted `AppServerSG`**
- **Symptom:** The website loaded through `ProxyServer1` but did not load through `ProxyServer2`, and the browser showed a timeout after about 2 minutes.
- **What I checked:** The source of the HTTP rule in `AppServerSG`.
- **Cause:** The rule only allowed `ProxyServer1`'s private IP, so traffic from `ProxyServer2` was silently dropped. Security groups drop traffic that does not match, and a drop shows up as a timeout, not as an error.
- **Fix or result:** Changed the source to the `ProxySG` security group and moved `ProxyServer2` into it.

**Page did not change after a rule change**
- **Symptom:** A page that should have failed or changed still looked the same.
- **What I checked:** Whether the browser was showing a cached copy.
- **Cause:** I had left an earlier tab open.
- **Fix or result:** A hard refresh, or a new tab, showed the real result.

**Allowed in the security group but blocked anyway**
- **Symptom:** After rule 99 (deny HTTP), the website timed out although `ProxySG` still allowed port 80.
- **What I checked:** The network ACL rules and their numbers.
- **Cause:** A request has to be allowed by both the security group and the network ACL, and the lowest-numbered matching ACL rule wins.
- **Fix or result:** Added rule 98 (allow HTTP), which is evaluated before 99, and the site loaded again.

**Tabs missing below the list in the console**
- **Symptom:** The Details and other tabs did not appear after selecting a subnet.
- **What I checked:** The checkboxes in the list.
- **Cause:** More than one item was selected, and the console only shows details for a single selected item.
- **Fix or result:** Cleared the extra checkbox.

## Quick reference: security group vs network ACL
| | Security group | Network ACL |
|---|---|---|
| Applies to | An instance's network interface | A whole subnet (here, the VPC's ACL) |
| Rules | Allow only | Allow and deny, with rule numbers |
| Order | All rules are checked together | Lowest number first, first match wins |
| State | Stateful: replies are allowed automatically | Stateless: return traffic needs its own rule |
| In this lab | `ProxySG`, `AppServerSG`, `BastionSG` | Rule 99 deny HTTP, rule 98 allow HTTP |

How access to `AppServer` changed during the lab:

| Stage | `AppServerSG` allows | Result |
|---|---|---|
| Start | HTTP from `0.0.0.0/0` | Both proxies reach it |
| Task 4 | HTTP from `ProxyServer1` IP `/32` | Only `ProxyServer1` reaches it |
| Task 5 | HTTP from the `ProxySG` group | Both proxies reach it, and new proxies would too |
| Task 7 | Plus SSH from the bastion IP `/32` | I could SSH to it through the bastion |

## Reflection
What surprised me is that blocked traffic never showed an error. It just timed out, so I had to work out which layer (security group, network ACL, or the instance) dropped it. I also did not expect rule numbers in a network ACL to matter so much: a deny at 99 was overridden by an allow at 98.

In production I would not allow SSH from Anywhere-IPv4 on a bastion, as `BastionSG` does in this lab. I would restrict it to my own IP, or drop the bastion and use Session Manager, which needs no open inbound port and logs sessions through CloudTrail. I would always reference security groups as sources instead of IP addresses, so new servers get access just by joining the group. I would leave gaps between network ACL rule numbers (10, 20, 30) so I can add rules later without renumbering, and I would keep SSH keys on my own machine and use agent forwarding, as in this lab, instead of copying keys to a bastion host.

