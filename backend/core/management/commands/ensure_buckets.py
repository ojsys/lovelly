import time

import boto3
from botocore.exceptions import ClientError, EndpointConnectionError
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Create the private photo and evidence buckets if they are missing."

    def handle(self, *args, **options):
        opts = settings.STORAGES["default"]["OPTIONS"]
        s3 = boto3.client(
            "s3",
            endpoint_url=opts["endpoint_url"],
            aws_access_key_id=opts["access_key"],
            aws_secret_access_key=opts["secret_key"],
        )
        for bucket in (opts["bucket_name"], settings.S3_BUCKET_EVIDENCE):
            self._ensure(s3, bucket)

    def _ensure(self, s3, bucket, attempts=30):
        for _ in range(attempts):
            try:
                s3.head_bucket(Bucket=bucket)
                self.stdout.write(f"bucket {bucket}: exists")
                return
            except ClientError as e:
                if e.response["Error"]["Code"] not in ("404", "NoSuchBucket"):
                    raise
                s3.create_bucket(Bucket=bucket)
                self.stdout.write(f"bucket {bucket}: created")
                return
            except EndpointConnectionError:
                time.sleep(1)
        raise CommandError(f"object storage unreachable while creating {bucket}")
