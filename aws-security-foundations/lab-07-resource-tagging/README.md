# Lab 07: Managing Resources with Tagging

**Type:** Guided lab with an optional challenge | **Services:** EC2, tags, AWS CLI (`--filter`, `--query`), AWS SDK for PHP

## Goal
Use tags to find and manage groups of EC2 instances from the AWS CLI: list instances by tag, change a tag on many instances at once, stop and start a whole environment, and terminate instances that are missing a required tag.

**Proof:** CLI commands and real output in [commands.sh](commands.sh), and step-by-step screenshots in the `screenshots` folder.

## Steps
1. **Connected to the Command Host:** Logged in over SSH to the pre-built instance that has the AWS CLI configured. The 8 other instances in the private subnet each have the tags `Project`, `Version` and `Environment`.
2. **Found instances by tag:** Ran `aws ec2 describe-instances` with `--filter "Name=tag:Project,Values=ERPSystem"`, which returned seven instances with a lot of output.
3. **Shaped the output with `--query`:** Narrowed it first to instance IDs, then to ID and Availability Zone, then added the values of the `Project`, `Environment` and `Version` tags using a JMESPath expression.
4. **Narrowed to development instances:** Added a second filter, `Environment=development`, and got two instances.
5. **Changed a tag in bulk:** Read and ran `change-resource-tags.sh`, which collects the IDs of the ERPSystem development instances and runs `create-tags` to set `Version` to `1.1`. I re-ran the listing to check that only the development instances changed and the others stayed at `1.0`.
6. **Stopped and started by tag:** Read `stopinator.php` (a PHP SDK script), ran it with `-t "Project=ERPSystem;Environment=development"` and watched the two instances stop in the EC2 console. Ran it again with `-s` and they started again.
7. **Challenge, tag-or-terminate:** Removed the `Environment` tag from two instances in the console. Read `terminate-instances.php`, which compares all instances in a subnet against those that have the `Environment` tag. Ran it with my region and the subnet ID and it terminated the untagged instances.

## Troubleshooting
> TODO: Write it in four parts: **Symptom** (the exact error or behavior), **What I checked** (in order), **Cause**, and **Fix or result**. If something stayed unresolved, say so and write what you would check next.
>
> Things that can go wrong in this lab, if one happened to you: a `--query` returning `null` or empty output (a typo in the tag name or a wrong quote or backtick, since tag keys are case sensitive), the filter returning no instances (the tag value is spelled differently, for example `Development`), `stopinator.php` finding no instances (the tags in `-t` do not match), or `terminate-instances.php` needing the region without the last letter of the Availability Zone (`us-west-2a` becomes `us-west-2`).
>
> If nothing went wrong, write what you checked while waiting, and why.

## Quick reference: tag commands in this lab
The same few options did most of the work, so it helps to know what each one does.

| Option or command | What it does | Example from this lab |
|---|---|---|
| `--filter "Name=tag:Key,Values=Value"` | Selects which instances come back (done by AWS) | `Project=ERPSystem`, then also `Environment=development` |
| `--query '...'` | Shapes what is shown for each result (done by the CLI, JMESPath) | `{ID:InstanceId,Version:Tags[?Key==`Version`] \| [0].Value}` |
| `--output text` | Plain text instead of JSON, easy to pass to another command | Collecting instance IDs inside `change-resource-tags.sh` |
| `aws ec2 create-tags` | Adds a tag, or overwrites it if it exists | Set `Version` to `1.1` |
| `stopinator.php -t` / `-s` | Stops (or with `-s` starts) every instance that matches the tags | ERPSystem development instances |

Tags only help if they are applied everywhere. An instance with no `Environment` tag cannot be found by an environment filter, which is why the challenge treats it as a problem.

## Reflection
> TODO: One sentence about what surprised you, for example that one command changed the tag on several instances at once, or that the untagged instances were found by comparing two lists.

In production I would not terminate untagged instances from a script that anyone can run by hand. A mistake would delete real servers and their data. I would stop them first, or alert the owner, and only terminate after a grace period. I would prevent the problem earlier by requiring tags when instances are launched (with IAM conditions or tag policies) and by checking them continuously with the AWS Config `required-tags` rule from Lab 06. I would also use tags for cost reports and for schedules such as shutting down development servers at night, and I would keep tag names and values consistent across the company, because `Development` and `development` are different values.

