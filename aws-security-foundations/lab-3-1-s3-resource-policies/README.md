# Lab 3.1: Using Resource-Based Policies to Secure an S3 Bucket

**Type:** Guided lab with a challenge | **Services:** IAM (users, groups, roles, policies), S3 bucket policies, AWS STS, EC2

## Goal
Understand who can do what in AWS by testing it. I signed in as a limited IAM user, hit Access Denied on purpose, read the policies to find out why, then assumed an IAM role and saw how a role's own policy and a bucket policy work together to allow access.

**Proof:** Step-by-step screenshots in the `screenshots` folder. This lab was done entirely in the console, so there is no `commands.sh`.

## Steps
1. **Signed in as `devuser`:** Used the IAM user sign-in URL from the lab details (not the normal console link), so every action ran with `devuser`'s permissions.
2. **Tried read access:** In EC2 I got "You are not authorized to perform this operation" on the dashboard, the instances list and the key pair list. In S3 all three lab buckets showed "Insufficient permissions".
3. **Read the identity-based policy:** In IAM, `devuser` is in `DeveloperGroup`, which has the policy `DeveloperGroupPolicy`. It allows no EC2 actions, many read-only IAM actions, and only bucket-level S3 actions with no object actions. I saved a copy as `DeveloperGroupPolicy.json`.
4. **Tried write access:** I could create a new S3 bucket, but uploading `DeveloperGroupPolicy.json` to it failed with Access Denied. The policy allows creating buckets but not `s3:PutObject`.
5. **Tried the lab buckets as `devuser`:** Downloading `Image2.jpg` from bucket1 and `Image1.jpg` from bucket2 both failed with `AccessDenied`.
6. **Assumed `BucketsAccessRole`:** Used Switch role with the account ID and the role name. I could now download `Image2.jpg` from bucket1, but the IAM User groups page stopped working because the role has no `iam:ListGroups` permission. Switching back to `devuser` restored it.
7. **Read the role's policies:** `ListAllBucketsPolicy` allows `s3:ListAllMyBuckets` on every resource. `GrantBucket1Access` allows `s3:GetObject`, `s3:ListObjects` and `s3:ListBucket` only on bucket1 and its objects. The trust relationship names `devuser` in this account as the entity allowed to assume the role. I saved a copy as `GrantBucket1Access.json`.
8. **Uploaded to bucket2 with the role:** With the role assumed, I uploaded `Image2.jpg` to bucket2 and it worked, even though `GrantBucket1Access` says nothing about bucket2.
9. **Found the reason in the bucket policy:** The policy on bucket2 has two statements: `S3Write` (allows `s3:GetObject` and `s3:PutObject` for `BucketsAccessRole`) and `ListBucket` (allows `s3:ListBucket` for the same role). That resource-based policy is what allowed the upload.

## Challenge: upload `Image2.jpg` to bucket3
- **Problem:** Upload `Image2.jpg` to bucket3.
- **What I tried:** As `devuser` with no role, the upload failed and I could not view the bucket policy. After assuming `BucketsAccessRole`, I could view bucket3's bucket policy, but `BucketsAccessRole` was not allowed to upload to bucket3.
- **How I found it:** I read the bucket3 policy. The statement that references the `devuser` ID names a different role, `OtherBucketAccessRole`, as the principal that is allowed to write to the bucket.
- **Fix:** I switched from `BucketsAccessRole` to `OtherBucketAccessRole` (Switch role, with the account ID and that role name) and uploaded `Image2.jpg` to bucket3. The upload worked.
- **What it showed:** Which role I assume matters. Bucket3's resource-based policy allows only the principal it names, so I had to read the policy to find out which role to use.

## Troubleshooting
In this lab the errors were the point, so I treated each one as a question: which policy allows or denies this action?

**Upload to my own new bucket failed**
- **Symptom:** "Upload failed", then `Access Denied` under the Error column, right after creating the bucket successfully.
- **What I checked:** The S3 section of `DeveloperGroupPolicy` against the Service Authorization Reference, which lists the S3 actions.
- **Cause:** The policy allows `s3:CreateBucket` but not `s3:PutObject`.
- **Fix or result:** Nothing to fix, it is the expected behavior. Uploading needs a permission the user does not have.

**Downloads from bucket1 and bucket2 returned `AccessDenied`**
- **Symptom:** `AccessDenied` as `devuser` on both buckets.
- **What I checked:** The group policy for object-level S3 actions.
- **Cause:** `DeveloperGroupPolicy` has no object access, and the buckets have no policy that allows `devuser`.
- **Fix or result:** Assuming `BucketsAccessRole`, which has `GrantBucket1Access`, made the bucket1 download work.

**The role could write to bucket2 without a matching role policy**
- **Symptom:** The upload to bucket2 worked, although `GrantBucket1Access` only covers bucket1.
- **What I checked:** The bucket policy on bucket2.
- **Cause:** The resource-based policy `S3Write` allows `BucketsAccessRole` to `GetObject` and `PutObject` on bucket2. Access can come from either the identity's policy or the resource's policy.
- **Fix or result:** Not a problem, but it showed me why I must check both places when I debug access.

## Quick reference: what was allowed and why
| Action | As | Result | Why |
|---|---|---|---|
| Open EC2 instances list | `devuser` | Denied | `DeveloperGroupPolicy` has no EC2 actions |
| Create a bucket | `devuser` | Allowed | `DeveloperGroupPolicy` allows bucket-level S3 actions |
| Upload an object to my bucket | `devuser` | Denied | No `s3:PutObject` in the policy |
| Download `Image2.jpg` from bucket1 | `devuser` | Denied | No object access, no bucket policy allowing it |
| Download `Image2.jpg` from bucket1 | `BucketsAccessRole` | Allowed | `GrantBucket1Access` allows `s3:GetObject` on bucket1 |
| View IAM user groups | `BucketsAccessRole` | Denied | No `iam:ListGroups` on the role |
| Upload `Image2.jpg` to bucket2 | `BucketsAccessRole` | Allowed | Bucket policy `S3Write` on bucket2 |
| Upload `Image2.jpg` to bucket3 | `BucketsAccessRole` | Denied | Bucket3's policy does not name this role |
| Upload `Image2.jpg` to bucket3 | `OtherBucketAccessRole` | Allowed | Bucket3's policy names this role |

Three kinds of policy were involved: an identity-based policy on the group (`DeveloperGroupPolicy`) and on the role (`GrantBucket1Access`, `ListAllBucketsPolicy`), a resource-based policy on the bucket (the bucket2 policy), and a trust policy that says who may assume the role.

## Reflection
What surprised me is that the role had no permission for bucket2 in its own policies and could still write to it. A bucket policy can grant access by itself, so the real answer to "who can access this?" is in both the identity policies and the resource policy.

In production I would start every permission from "deny" and grant only the specific actions and resources needed, and avoid `*` wildcards on actions and resources. I would give people roles that give temporary credentials instead of long-lived permissions, and require MFA to assume sensitive roles. I would keep bucket policies specific to named principals, leave S3 Block Public Access on, and test changes with the IAM Policy Simulator or IAM Access Analyzer before applying them. I would also use CloudTrail to review denied calls, because every attempt in this lab, allowed or not, is recorded as an API call.
