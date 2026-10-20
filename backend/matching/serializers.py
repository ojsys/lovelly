from rest_framework import serializers


class OnlineCountSerializer(serializers.Serializer):
    count = serializers.IntegerField()


class PeerSerializer(serializers.Serializer):
    first_name = serializers.CharField()
    age = serializers.IntegerField(allow_null=True)
    city = serializers.CharField(allow_blank=True)
    shared_interests = serializers.ListField(child=serializers.CharField())
    shared_languages = serializers.ListField(child=serializers.CharField())
    verified = serializers.BooleanField()


class ChatMessageSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    sender_id = serializers.UUIDField()
    body = serializers.CharField()
    kind = serializers.CharField()
    sent_at = serializers.DateTimeField()
    seen_at = serializers.DateTimeField(allow_null=True)
    flagged = serializers.BooleanField()
    flag_reason = serializers.CharField(allow_blank=True)


class SessionDetailSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    mode = serializers.CharField()
    peer = PeerSerializer()
    started_at = serializers.DateTimeField()
    ended_at = serializers.DateTimeField(allow_null=True)
    end_reason = serializers.CharField(allow_blank=True)
    messages = ChatMessageSerializer(many=True)


class MediaTokenSerializer(serializers.Serializer):
    media_token = serializers.CharField()
    media_url = serializers.CharField()
