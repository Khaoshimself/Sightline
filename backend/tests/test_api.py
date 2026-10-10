import asyncio
import base64
import json
import unittest

import httpx
from fastapi.testclient import TestClient

from main import MAX_REQUEST_BYTES, Settings, create_app

IMAGE = base64.b64encode(b"\xff\xd8\xff\xe0test-jpeg").decode()
SETTINGS = Settings(api_key="test-provider-key", app_token="test-app-token")
HEADERS = {"Authorization": "Bearer test-app-token"}
COMPLETED = {"status": "completed", "steps": [{"type": "model_output",
    "content": [{"type": "text", "text": " A chair is on the left. "}]}]}


class APITests(unittest.TestCase):
    def client(self, handler):
        return TestClient(create_app(SETTINGS, httpx.MockTransport(handler)))

    def test_health_does_not_contact_provider(self):
        def fail(_request):
            self.fail("Health must not call Gemini")
        with self.client(fail) as client:
            self.assertEqual(client.get("/health").json(), {"status": "ok"})

    def test_existing_swift_contract_and_provider_payload(self):
        def provider(request):
            self.assertEqual(request.headers["x-goog-api-key"], "test-provider-key")
            self.assertNotIn("authorization", request.headers)
            body = json.loads(request.content)
            self.assertFalse(body["store"])
            self.assertEqual(body["input"][1]["data"], IMAGE)
            self.assertEqual(body["input"][1]["mime_type"], "image/jpeg")
            return httpx.Response(200, json=COMPLETED)
        with self.client(provider) as client:
            response = client.post("/describe", headers=HEADERS, json={"imageBase64": IMAGE})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json(), {"text": "A chair is on the left."})

    def test_unauthorized_request_never_calls_provider(self):
        def fail(_request):
            self.fail("Unauthorized request called provider")
        with self.client(fail) as client:
            for token in ["", "Bearer wrong", "Bearer test-app-token-extra"]:
                response = client.post("/describe", headers={"Authorization": token},
                                       json={"imageBase64": IMAGE})
                self.assertEqual(response.status_code, 401)
                self.assertEqual(response.json(), {"error": "Invalid app token."})

    def test_invalid_input_never_calls_provider(self):
        def fail(_request):
            self.fail("Invalid image called provider")
        with self.client(fail) as client:
            for body in [{}, {"imageBase64": 42}, {"imageBase64": "!"},
                         {"imageBase64": base64.b64encode(b"not-jpeg").decode()}]:
                response = client.post("/describe", headers=HEADERS, json=body)
                self.assertEqual(response.status_code, 400)
            response = client.post("/describe", headers=HEADERS,
                                   content="invalid-json")
            self.assertEqual(response.status_code, 415)
            response = client.post("/describe", headers={**HEADERS, "Content-Type": "application/json"},
                                   content="invalid-json")
            self.assertEqual(response.status_code, 400)

    def test_oversized_body_is_rejected_before_provider(self):
        def fail(_request):
            self.fail("Oversized image called provider")
        with self.client(fail) as client:
            response = client.post("/describe", headers=HEADERS,
                                   json={"imageBase64": "A" * MAX_REQUEST_BYTES})
            self.assertEqual(response.status_code, 413)

    def test_provider_error_mapping(self):
        for provider_status, expected_status in [(429, 503), (400, 502), (500, 502)]:
            with self.subTest(provider_status=provider_status):
                with self.client(lambda _request: httpx.Response(provider_status)) as client:
                    response = client.post("/describe", headers=HEADERS, json={"imageBase64": IMAGE})
                    self.assertEqual(response.status_code, expected_status)
                    self.assertIn("error", response.json())

    def test_timeout_has_a_readable_error(self):
        def timeout(request):
            raise httpx.ReadTimeout("timed out", request=request)
        with self.client(timeout) as client:
            response = client.post("/describe", headers=HEADERS, json={"imageBase64": IMAGE})
            self.assertEqual(response.status_code, 504)
            self.assertIn("timed out", response.json()["error"])

    def test_invalid_provider_output_is_rejected(self):
        invalid_results = [[], {"status": "in_progress", "steps": []},
                           {"status": "completed", "steps": []},
                           {"status": "completed", "steps": "bad"}]
        for result in invalid_results:
            with self.subTest(result=result):
                with self.client(lambda _request: httpx.Response(200, json=result)) as client:
                    response = client.post("/describe", headers=HEADERS, json={"imageBase64": IMAGE})
                    self.assertEqual(response.status_code, 502)

    def test_concurrent_descriptions_have_separate_results(self):
        async def provider(request):
            await asyncio.sleep(0.02)
            image = json.loads(request.content)["input"][1]["data"]
            return httpx.Response(200, json={"status": "completed", "steps": [{
                "type": "model_output", "content": [{"type": "text", "text": image}]}]})

        async def exercise():
            app = create_app(SETTINGS, httpx.MockTransport(provider))
            async with app.router.lifespan_context(app):
                async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                             base_url="http://test") as client:
                    images = [base64.b64encode(b"\xff\xd8\xff\xe0" + bytes([n])).decode()
                              for n in range(3)]
                    replies = await asyncio.gather(*[
                        client.post("/describe", headers=HEADERS, json={"imageBase64": image})
                        for image in images])
                    self.assertEqual([reply.json()["text"] for reply in replies], images)
        asyncio.run(exercise())

class DescriptionParsingTests(unittest.TestCase):
    def test_thought_text_is_never_read_as_scene_description(self):
        from main import extract_description
        self.assertEqual(extract_description({"status":"completed", "steps":[
            {"type":"thought", "content":[{"type":"text","text":"private reasoning"}]},
            {"type":"model_output", "content":[{"type":"text","text":"A bottle is ahead."}]}
        ]}), "A bottle is ahead.")

    def test_model_uses_supported_thinking_level(self):
        from main import description_payload
        self.assertEqual(description_payload(IMAGE, "gemini-3.5-flash-lite")["generation_config"]["thinking_level"], "minimal")
        self.assertEqual(description_payload(IMAGE, "gemini-3.8-flash")["generation_config"]["thinking_level"], "low")


if __name__ == "__main__":
    unittest.main()
