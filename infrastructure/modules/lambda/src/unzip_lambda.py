
import os
import zipfile
import boto3
import shutil


unzipped_dir = "/tmp/unzipped/"
unzipped_s3_prefix = "unzipped/"

#S3
s3 = boto3.client('s3')


# Download the compressed archive from the zipped/ prefix in the S3 bucket.
# Extract the archive and upload the individual files to the unzipped/ prefix in the S3 bucket.
def unzip_object(bucket, key):
    """Download a zip from S3, extract it locally, and return its file list.

    Pulls the zip at ``s3://{bucket}/{key}`` into ``/tmp/``, extracts every
    member into ``/tmp/unzipped/``, then removes the original zip from the
    Lambda ephemeral filesystem to free space.

    Args:
        bucket: Name of the S3 bucket the zip lives in.
        key: S3 object key of the zip (e.g. ``zipped/<app_uuid>.zip``).

    Returns:
        list[str]: Filenames extracted into ``/tmp/unzipped/`` (top level only).
    """
    if not os.path.exists(unzipped_dir):  # added: extractall() fails if /tmp/unzipped/ doesn't exist yet. Guarding here makes the function safe to call on a cold container without relying on the handler having created it.
        os.makedirs(unzipped_dir)         # added: create the target dir before extracting into it.

    zip_name = os.path.basename(key)
    zip_fullpath = f"/tmp/{zip_name}"
    s3.download_file(bucket, key, zip_fullpath)
    with zipfile.ZipFile(zip_fullpath, 'r') as zip_ref:
        zip_ref.extractall(unzipped_dir)
    os.remove(zip_fullpath)

    return [f for f in os.listdir(unzipped_dir) if not f.startswith('__')]  # added: filter out '__'-prefixed entries (e.g. macOS's __MACOSX folder). Without this, those junk entries get re-uploaded to S3 and can break the later file-name math.


def lambda_handler(event, context):
    # record = event['Records'][0]
    print(f"event = {event}")
    bucket = event['detail']['bucket']['name']
    key = event['detail']['object']['key']

    try:  # added: wrap the body so the finally block always runs and clears /tmp, even if a step throws.
        if os.path.exists(
                unzipped_dir):  # added: clear any leftovers from a previous warm-container run BEFORE extracting, so stale files from another applicant can't contaminate this one.
            shutil.rmtree(unzipped_dir)
        os.makedirs(unzipped_dir)  # added: recreate a clean working directory.

        # Unzip the object from the event
        files_list = unzip_object(bucket, key)

        # upload files to the unzipped location
        for file in files_list:
            s3.upload_file(unzipped_dir + file, bucket, unzipped_s3_prefix + file)
            print(f"File being uploaded is {file} to {unzipped_s3_prefix + file}")

        # retrieve app_uuid, selfie_key, license_key, and details_file and save them as variables for later use
        app_uuid = os.path.basename(key).replace(".zip", "")
        selfie_key = f"{unzipped_s3_prefix}{app_uuid}_selfie.png"
        license_key = f"{unzipped_s3_prefix}{app_uuid}_license.png"
        details_file = f"{unzipped_dir}{app_uuid}_details.csv"

        # Add print to verify your solution by checking CloudWatch logs
        print(f"app_uuid = {app_uuid}")
        print(f"selfie_key = {selfie_key}")
        print(f"license_key = {license_key}")
        print(f"details_file = {details_file}")

        return {
            "app_uuid": app_uuid
        }

        # Extract the app-uuid value from the files. This value will be used later as the DynamoDB table hash key for the customer details.
    finally:
        if os.path.exists(unzipped_dir):  # added: always wipe /tmp/unzipped/ on the way out so a warm container starts the next invocation clean and we don't slowly fill the 512MB /tmp budget.
            shutil.rmtree(unzipped_dir)

