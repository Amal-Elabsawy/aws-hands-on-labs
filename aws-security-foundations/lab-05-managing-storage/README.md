# Lab 5.1: Encrypting Data at Rest by Using AWS KMS

**Type:** Guided lab | **Services:** AWS KMS, S3 (SSE-KMS), EBS, EC2, CloudTrail

## Goal
Encrypt data at rest with a key I control. I created a customer managed KMS key, used it to encrypt an S3 object and an EC2 root volume, checked in CloudTrail how the key was used, and then disabled the key to see that the encrypted data became unreachable.

**Proof:** Step-by-step screenshots in the `screenshots` folder. This lab was done entirely in the console, so there is no `commands.sh`.

## Steps
1. **Created the KMS key:** A symmetric customer managed key with the alias `MyKMSKey`. I set the `voclabs` role as both key administrator and key user.
2. **Uploaded an encrypted object:** In the `ImageBucket` bucket I uploaded `clock.png` with server-side encryption set to SSE-KMS and `MyKMSKey` as the key. The object's properties confirmed SSE-KMS.
3. **Tried public access:** The object URL returned `Access Denied`. I turned off Block all public access, enabled ACLs and made `clock.png` public. The URL then returned an `Invalid Argument` error instead, because requests for SSE-KMS objects must be signed (Signature Version 4). So even a public link could not show the image.
4. **Opened the object with a signed request:** Using **Open** in the S3 console, I was authenticated, so the console added the signature and the image opened. The URL had `X-Amz-...` signing parameters in it.
5. **Checked CloudTrail:** In Event history, filtered to `kms.amazonaws.com`, I found a `GenerateDataKey` event from the upload (with `MyKMSKey`'s ID and the bucket in the encryption context) and a `Decrypt` event from opening the image.
6. **Encrypted the EC2 root volume:** For `LabInstance`: stopped it, noted the volume's Availability Zone, created a snapshot tagged `Unencrypted Root Volume`, created a new volume from that snapshot with **Encrypt this volume** and `MyKMSKey`, renamed the two volumes, detached the old one, and attached the new one to the instance as `/dev/xvda`. The instance's Storage tab then showed the volume as encrypted with a KMS key ID.
7. **Disabled the key:** Starting `LabInstance` failed (it went from Pending back to Stopped), and opening `clock.png` returned `KMS.DisabledException`. In CloudTrail the `DisableKey`, `StartInstances` and `CreateGrant` events showed the sequence, and `CreateGrant` carried the error that the key was disabled. I re-enabled the key, started the instance again, and waited for it to show Running.

## Troubleshooting
The errors in this lab were the evidence that the encryption worked, so I read each one for what it said.

**`Access Denied`, then `Invalid Argument` on the object URL**
- **Symptom:** The first URL test gave `Access Denied`. After making the object public, it gave `Invalid Argument`, saying SSE-KMS requests require AWS Signature Version 4.
- **What I checked:** The bucket's Block public access setting, then the object's encryption setting.
- **Cause:** First, public access was blocked by default. After I removed that, the request was still unsigned, and S3 will not decrypt an SSE-KMS object for an unsigned request.
- **Fix or result:** Opening the object from the S3 console worked, because the console signs the request with my credentials.

**`LabInstance` would not start after I disabled the key**
- **Symptom:** The state changed from Pending to Stopped within moments.
- **What I checked:** CloudTrail events after `StartInstances`.
- **Cause:** The `CreateGrant` event had an error saying the key was disabled. EC2 needed KMS to decrypt the root volume's data key, and KMS refused.
- **Fix or result:** Re-enabled `MyKMSKey` and started the instance again. It ran.

**`KMS.DisabledException` when opening `clock.png`**
- **Symptom:** The image did not open, though the same action worked earlier.
- **What I checked:** The key state in KMS.
- **Cause:** The key was disabled, so S3 could not get the data key decrypted.
- **Fix or result:** Re-enabling the key restored access to the object.

**Encrypted volume in the wrong Availability Zone**
- **What I checked before creating it:** The volume's Availability Zone (for example `us-east-1a`), which I wrote down first.
- **Why:** An EBS volume can only attach to an instance in the same zone, so the new volume had to be created in the same one.

## Quick reference: what happened to access
| Request | Result | Why |
|---|---|---|
| Object URL, public access blocked | `Access Denied` | Block all public access is on by default |
| Object URL, object made public | `Invalid Argument` | SSE-KMS requests must be signed (Signature Version 4) |
| Open from the S3 console | Image opens | The console signs the request, and KMS decrypts the data key |
| Start `LabInstance`, key disabled | Fails, back to Stopped | EC2 cannot get the root volume's data key decrypted |
| Open `clock.png`, key disabled | `KMS.DisabledException` | S3 cannot get the data key decrypted |
| Same actions after re-enabling the key | Work again | The key can decrypt data keys again |

How the encryption works in this lab: KMS creates a data key and encrypts a copy with `MyKMSKey`. S3 (or EBS) encrypts the data with the plaintext data key and stores only the encrypted copy of that key with the data. To read the data, the service asks KMS to decrypt the data key. `MyKMSKey` itself never leaves KMS.

## Reflection
What surprised me is that a public link still could not show the image. Encryption kept the data unreadable even after the access setting was opened by mistake. I also did not expect disabling one key to stop both an S3 object and a whole EC2 instance at once.

In production I would never switch off Block all public access for a test like this, and if I did, I would turn it back on right after. I would give key administration and key use to different roles, because here the same role was both. I would turn on automatic key rotation, set up alarms on `DisableKey` and `ScheduleKeyDeletion` events, and keep a long deletion waiting period, since deleting a key makes the data permanently unreadable. I would turn on EBS encryption by default for the account, so volumes are encrypted from the start and I never need the snapshot-and-swap steps. I would also create a CloudTrail trail to keep KMS events for longer than the 90 days in Event history.

