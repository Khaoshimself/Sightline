import asyncio
import unittest

import httpx

from main import APIError, Settings, call_provider, create_app


class LifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def test_removed_speech_endpoint_never_contacts_provider(self):
        def fail(_request):
            self.fail("Removed speech endpoint contacted a provider")

        app = create_app(Settings("test-key", "test-token"), httpx.MockTransport(fail))
        async with app.router.lifespan_context(app):
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(app=app), base_url="http://test"
            ) as client:
                response = await client.post("/speech", json={"text": "Hello"})
                self.assertEqual(response.status_code, 404)

    async def test_disconnect_cancels_description_provider(self):
        started = asyncio.Event()
        canceled = asyncio.Event()

        async def provider(_request):
            started.set()
            try:
                await asyncio.sleep(60)
            finally:
                canceled.set()

        app = create_app(Settings("test-key", "test-token"), httpx.MockTransport(provider))
        async with app.router.lifespan_context(app):
            class RequestStub:
                async def is_disconnected(self):
                    await started.wait()
                    return True

            request = RequestStub()
            request.app = app
            with self.assertRaises(APIError) as error:
                await call_provider(request, "https://test", {}, {})
            self.assertEqual(error.exception.status, 499)
            self.assertTrue(canceled.is_set())


if __name__ == "__main__":
    unittest.main()
