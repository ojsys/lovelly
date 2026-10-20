from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsVerified
from matching.serializers import ChatMessageSerializer

from . import friends
from .services import serialize


class FriendSummarySerializer(serializers.Serializer):
    first_name = serializers.CharField()
    age = serializers.IntegerField(allow_null=True)
    city = serializers.CharField(allow_blank=True)
    verified = serializers.BooleanField()
    photo_url = serializers.CharField(allow_null=True)


class LastMessageSerializer(serializers.Serializer):
    body = serializers.CharField()
    kind = serializers.CharField()
    mine = serializers.BooleanField()
    sent_at = serializers.DateTimeField()


class FriendRowSerializer(serializers.Serializer):
    chat_id = serializers.UUIDField()
    friend = FriendSummarySerializer()
    online = serializers.BooleanField()
    last_message = LastMessageSerializer(allow_null=True)
    unread = serializers.IntegerField()


class FriendRequestRowSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    sender = FriendSummarySerializer()
    met_on = serializers.CharField(allow_null=True)
    created_at = serializers.DateTimeField()


class FriendsSerializer(serializers.Serializer):
    friends = FriendRowSerializer(many=True)
    requests = FriendRequestRowSerializer(many=True)


class FriendRequestCreateSerializer(serializers.Serializer):
    session_id = serializers.UUIDField(help_text="Ask the other person in this session")


class FriendRequestSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    status = serializers.CharField()


class ChatHistorySerializer(serializers.Serializer):
    friend = FriendSummarySerializer()
    messages = ChatMessageSerializer(many=True)
    more = serializers.BooleanField()


class FriendsView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(responses=FriendsSerializer)
    def get(self, request):
        return Response(friends.friends(request.user))


class FriendRequestsView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(request=FriendRequestCreateSerializer, responses={201: FriendRequestSerializer})
    def post(self, request):
        data = FriendRequestCreateSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        f = friends.request(request.user, data.validated_data["session_id"])
        return Response({"id": f.id, "status": f.status}, status=status.HTTP_201_CREATED)


class FriendRequestAcceptView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(request=None, responses=FriendRequestSerializer)
    def post(self, request, request_id):
        f = friends.accept(request.user, request_id)
        return Response({"id": f.id, "status": f.status})


class FriendRequestDeclineView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(request=None, responses={204: None})
    def post(self, request, request_id):
        friends.decline(request.user, request_id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChatMessagesView(APIView):
    """FR-15: saved history with a friend, newest first; `before` pages back."""

    permission_classes = [IsVerified]

    @extend_schema(
        parameters=[OpenApiParameter("before", str, description="ISO time: older than this")],
        responses=ChatHistorySerializer,
    )
    def get(self, request, chat_id):
        page = friends.history(request.user, chat_id, before=request.query_params.get("before"))
        return Response(
            {
                "friend": page["friend"],
                "messages": [serialize(m) for m in page["messages"]],
                "more": page["more"],
            }
        )
