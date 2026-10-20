from drf_spectacular.utils import extend_schema
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services


class BlockRequestSerializer(serializers.Serializer):
    session_id = serializers.UUIDField(help_text="Blocks the other person in this session")


class BlockSerializer(serializers.Serializer):
    id = serializers.UUIDField()


class BlocksView(APIView):
    """SF-5: block the other person in a session."""

    @extend_schema(request=BlockRequestSerializer, responses={201: BlockSerializer})
    def post(self, request):
        data = BlockRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        block = services.block_from_session(request.user, data.validated_data["session_id"])
        return Response({"id": block.id}, status=status.HTTP_201_CREATED)


class BlockDetailView(APIView):
    @extend_schema(responses={204: None})
    def delete(self, request, block_id):
        services.unblock(request.user, block_id)
        return Response(status=status.HTTP_204_NO_CONTENT)
