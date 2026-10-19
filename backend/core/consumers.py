from channels.generic.websocket import AsyncJsonWebsocketConsumer


class RealtimeConsumer(AsyncJsonWebsocketConsumer):
    """The single authenticated websocket at /ws/. Event handlers arrive from M2 onward."""

    async def connect(self):
        if not self.scope["user"].is_authenticated:
            await self.close(code=4401)
            return
        await self.accept()

    async def receive_json(self, content, **kwargs):
        await self.send_json({"type": "error", "detail": "unknown event"})
