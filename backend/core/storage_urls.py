from django.conf import settings


def signed_url(store, key: str, expires: int = 300) -> str:
    """A browser- or app-reachable signed URL for a private object (S3), or the storage's
    own URL (tests). Signed against S3_PUBLIC_ENDPOINT_URL: Django uploads inside Docker,
    clients download from outside it."""
    bucket = getattr(store, "bucket_name", None)
    if bucket is None:
        return store.url(key)
    import boto3

    client = boto3.client(
        "s3",
        endpoint_url=settings.S3_PUBLIC_ENDPOINT_URL,
        aws_access_key_id=store.access_key,
        aws_secret_access_key=store.secret_key,
        region_name="us-east-1",
    )
    return client.generate_presigned_url(
        "get_object", Params={"Bucket": bucket, "Key": key}, ExpiresIn=expires
    )
