from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken


@database_sync_to_async
def _user_for_token(raw: str):
    try:
        token = AccessToken(raw)
        return get_user_model().objects.get(id=token["user_id"], is_active=True)
    except (TokenError, KeyError, get_user_model().DoesNotExist):
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    """Authenticates websocket connections from a `?token=<access JWT>` query param."""

    async def __call__(self, scope, receive, send):
        params = parse_qs(scope.get("query_string", b"").decode())
        raw = params.get("token", [None])[0]
        scope["user"] = await _user_for_token(raw) if raw else AnonymousUser()
        return await super().__call__(scope, receive, send)
