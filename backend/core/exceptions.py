from rest_framework import status
from rest_framework.exceptions import APIException, Throttled
from rest_framework.views import exception_handler


class ApiError(APIException):
    """A business-rule failure with a stable machine-readable `code` for the app."""

    status_code = status.HTTP_400_BAD_REQUEST

    def __init__(self, code: str, detail: str, status_code: int | None = None, **extra):
        super().__init__(detail=detail, code=code)
        self.error_code = code
        self.extra = extra
        if status_code:
            self.status_code = status_code


def api_exception_handler(exc, context):
    """Every error body carries `code` and `detail` (plus extras like `retry_after`)."""
    response = exception_handler(exc, context)
    if response is None:
        return None
    if isinstance(exc, ApiError):
        response.data = {"code": exc.error_code, "detail": str(exc.detail), **exc.extra}
    elif isinstance(exc, Throttled):
        response.data = {"code": "throttled", "detail": str(exc.detail), "retry_after": exc.wait}
    elif isinstance(response.data, dict) and "detail" in response.data:
        response.data = {"code": getattr(exc, "default_code", "error"), **response.data}
    else:
        response.data = {"code": "invalid", "detail": "Invalid input.", "fields": response.data}
    return response
