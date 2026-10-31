#!/bin/bash
# Lab 06: optional read-only CLI proof.
# This lab was done in the console (Run Command, Parameter Store, CloudWatch, EventBridge, Config).
# These commands only READ what the console created. The lab role may block some of them,
# so keep only the ones that work, run them in the same Region as the lab (do not change it),
# and paste the real output under each command as a comment before committing.
# If none of them work in your lab, delete this file and rely on the screenshots.

# 1. The agent configuration saved in Parameter Store
aws ssm get-parameter --name Monitor-Web-Server --query 'Parameter.Value' --output text
# Output:

# 2. The Run Command jobs (install the agent, then configure it)
aws ssm list-commands --query 'Commands[].{Document:DocumentName,Status:Status}'
# Output:

# 3. The log groups created by the agent (expect HttpAccessLog and HttpErrorLog)
aws logs describe-log-groups --query 'logGroups[].logGroupName'
# Output:

# 4. The 404 lines in the access log
aws logs filter-log-events --log-group-name HttpAccessLog --filter-pattern '404' --query 'events[].message' --max-items 5
# Output:

# 5. The metric filter that counts 404s
aws logs describe-metric-filters --log-group-name HttpAccessLog --query 'metricFilters[].{Name:filterName,Pattern:filterPattern,Metric:metricTransformations[0].metricName}'
# Output:

# 6. The alarm and its current state
aws cloudwatch describe-alarms --alarm-names 404Errors --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Threshold:Threshold,Period:Period}'
# Output:

# 7. The metrics the agent publishes from inside the instance
aws cloudwatch list-metrics --namespace CWAgent --query 'Metrics[].MetricName'
# Output:

# 8. The EventBridge rule for stopped or terminated instances
aws events describe-rule --name Instance_Stopped_Terminated
# Output:

# 9. AWS Config compliance for the two rules
aws configservice describe-compliance-by-config-rule --query 'ComplianceByConfigRules[].{Rule:ConfigRuleName,Compliance:Compliance.ComplianceType}'
# Output:
