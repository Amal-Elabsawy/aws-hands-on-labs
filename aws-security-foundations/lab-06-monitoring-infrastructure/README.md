# Lab 06: Monitoring Infrastructure

**Type:** Guided lab | **Services:** CloudWatch (Agent, Logs, Metrics, Alarms), Systems Manager (Run Command, Parameter Store), SNS, EventBridge, AWS Config

## Goal
Set up monitoring for a web server from four angles: ship its logs and system metrics to CloudWatch, raise an alarm when the logs show too many errors, get a notification when an instance is stopped, and check compliance with AWS Config rules.

**Proof:** Optional read-only CLI commands and real output in [commands.sh](commands.sh), and step-by-step screenshots in the `screenshots` folder.

## Steps
1. **Installed the CloudWatch Agent:** Used Systems Manager Run Command with the `AWS-ConfigureAWSPackage` document to install `AmazonCloudWatchAgent` on the Web Server, and checked the command output said the package installed successfully.
2. **Saved the agent configuration:** Stored a JSON config in Parameter Store as `Monitor-Web-Server`. It collects the two Apache logs (access and error) and CPU, disk, memory and swap metrics every 10 seconds.
3. **Started the agent with that configuration:** Ran the `AmazonCloudWatch-ManageAgent` document with action `configure`, mode `ec2`, source `ssm`, and the parameter name, so the agent read its settings from Parameter Store.
4. **Generated and read logs:** Opened the web server's IP, then a page that does not exist (`/start`) to cause a 404. In CloudWatch Logs, the `HttpAccessLog` group showed the request with status 404.
5. **Created a metric filter:** On `HttpAccessLog`, a filter pattern that matches only lines with `status_code=404`, tested it on real log data, and saved it as the metric `404Errors` in the `LogMetrics` namespace.
6. **Created an alarm and tested it:** An alarm on `404Errors` that fires at 5 or more in 1 minute and sends an email through a new SNS topic. I confirmed the email subscription, requested missing pages at least 5 times, and the alarm moved from `INSUFFICIENT DATA` to `ALARM` and sent an email.
7. **Explored instance metrics:** Compared the built-in EC2 metrics (CPU, disk, network, seen from outside the VM) with the `CWAgent` metrics (disk space and memory, seen from inside).
8. **Created a real-time notification:** An EventBridge rule, `Instance_Stopped_Terminated`, that matches EC2 state-change events for `stopped` and `terminated` and sends them to the `Default_CloudWatch_Alarms_Topic` SNS topic. I stopped the Web Server to test it and got the notification.
9. **Checked compliance with AWS Config:** Turned on AWS Config, then added two managed rules: `ec2-volume-inuse-check` (finds EBS volumes not attached to an instance) and `required-tags` with `tag1Key = project`. The Web Server was compliant for tags, and the results also showed non-compliant resources and one unattached volume.

## Troubleshooting
> TODO: Write it in four parts: **Symptom** (the exact error or behavior), **What I checked** (in order), **Cause**, and **Fix or result**. If something stayed unresolved, say so and write what you would check next.
>
> Things that can go wrong in this lab, if one happened to you: the log groups `HttpAccessLog` and `HttpErrorLog` not appearing (wait a minute, check that the Run Command status was Success, and check the log file paths in the config), the alarm staying in `INSUFFICIENT DATA` (it needs new 404 requests inside the 1-minute period), no alarm email (the SNS subscription was not confirmed), no notification after stopping the instance (check the rule's event pattern and the SNS topic subscription), or Config showing "No resources in scope" (it is still scanning, wait a few minutes).
>
> If nothing went wrong, write what you checked while waiting, and why.

## Quick reference: which service answers which question
Each tool answers a different question, and I used all of them in this lab.

| Question | Tool | In this lab |
|---|---|---|
| What is happening inside the server (memory, disk, logs)? | CloudWatch Agent | Installed with Run Command, configured from Parameter Store |
| What did the application write? | CloudWatch Logs | `HttpAccessLog` and `HttpErrorLog` |
| How often did a specific thing appear in the logs? | Metric filter | Counts 404 responses as `404Errors` |
| Tell me when it gets bad | CloudWatch alarm + SNS | 5 or more 404s in 1 minute sends an email |
| Tell me when the infrastructure changes | EventBridge rule + SNS | Instance stopped or terminated |
| Does my setup follow our rules? | AWS Config rules | Missing `project` tag, unattached EBS volumes |

## Reflection
> TODO: One sentence about what surprised you, for example that the default EC2 metrics have no memory or disk space, or how quickly the alarm changed state after the 5th bad request.

In production I would not alarm on one log pattern with a hand-picked number. I would set thresholds from normal traffic, send alarms to a team channel or on-call tool as well as email, and add alarms on things that hurt users, such as 5xx errors, latency and disk space. I would include the agent install and configuration in the instance's launch template or a CloudFormation template (see Lab 08), so every new server is monitored from its first minute. I would turn on AWS Config in every Region I use, with rules that match the company's tagging and security policy, and set log retention on the log groups so storage costs do not grow forever.

