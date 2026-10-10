# Sightline

Sightline is an iOS prototype that identifies objects locally, accepts spoken commands prefixed with “Sightline,” and reads short camera scene descriptions aloud. It combines SwiftUI, AVFoundation, Vision, Core ML, Apple Speech, and a Python FastAPI backend with Gemini. It does not estimate distance or assess whether a walking path is safe.

## Features

- Local YOLOv3 Tiny detection across 80 model classes, with a 0.5 confidence threshold and inference at most once every 0.5 seconds.
- Find commands for chair, person, bottle, backpack, and car, with left, ahead, or right announcements relative to the camera image.
- Scene descriptions from Gemini 3.5 Flash-Lite through an authenticated backend; local object summaries when cloud requests fail.
- Native speech with microphone listening paused during spoken output, two bounded recognition recovery attempts, and cancellation when Stop is pressed.
- Large controls, Dynamic Type, VoiceOver labels and hints, and a scrollable layout.

The camera is assumed to be held upright in portrait. Recognition runs while the app is open and listening; voice commands cannot interrupt spoken output. The Stop control can interrupt it. Start and permission dialogs remain part of the initial setup. Maps and ElevenLabs are not included.

## Backend setup

Use Python 3.12 and a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey).

```sh
cd backend
uv venv --python 3.12
uv pip install --python .venv/bin/python -r requirements.lock.txt
cp .env.example .env
```

Set `GEMINI_API_KEY`, `GEMINI_MODEL`, and `SIGHTLINE_APP_TOKEN` in `.env`. Generate an app token with `python3 -c 'import secrets; print(secrets.token_urlsafe(32))'`. Use the same app token in the iOS configuration. The Gemini key stays on the backend.

```sh
.venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 3000 --reload
```

Visit `http://127.0.0.1:3000/health`; the response is `{"status":"ok"}`. Health verifies that the server is running; it does not call Gemini.

`main.py` is the implementation. `app.py` exists only as a compatibility import. Exact tested dependency versions are in `requirements.lock.txt`; `requirements.txt` lists direct dependency ranges.

## iPhone setup

1. Open `Sightline.xcodeproj` in Xcode 27 and select the Sightline scheme.
2. Select your signing team and your connected iPhone. This project currently targets iOS 27.
3. Copy `BackendConfiguration.example.plist` to `Sightline/BackendConfiguration.local.plist`.
4. In that local plist, set `AppToken` to the backend token and `BaseURL` to `http://YOUR_MAC_WIFI_IP:3000`. Find the Mac address with `ipconfig getifaddr en0`. The iPhone and Mac must share a reachable local network. Do not use localhost on the iPhone.
5. Run the app and grant camera, microphone, speech recognition, and local network permissions.
6. Tap Start Walking Mode. While the status says Listening, say “Sightline, find me a chair,” “Sightline, describe the scene,” or “Sightline, stop.”

The local plist and backend `.env` are ignored by Git. No credentials are included in the tracked Swift configuration. The local HTTP setup is intended for development. A distributed app needs HTTPS and an authentication design appropriate for multiple users; the development token is not a per-user account system.

## Architecture

Camera frames → Vision and Core ML → detected labels and positions → local find announcements.

A describe command → next camera frame → JPEG with maximum edge 1024 pixels → authenticated FastAPI `/describe` → Gemini → native speech.

The backend limits request bodies to 4 MiB and provider work to 20 seconds, rejects invalid input, and cancels provider work when the phone disconnects. Stop invalidates pending camera, recognition, speech, and description callbacks so a late result cannot restart a stopped session. Descriptions use `store=false` at the provider; images still leave the phone for scene requests. Local find commands do not send camera images to Gemini.

## Verification

```sh
cd backend
.venv/bin/python -m unittest discover -s tests
```

From the repository root, run `scripts/check-parser.sh` for command parsing, and run the Xcode test action for simulator UI and accessibility audits. The UI tests use a Debug-only `--demo` argument with explicitly labeled sample content; they do not test camera, microphone, or cloud accuracy.

See [validation](docs/VALIDATION.md) for results and remaining physical-device checks, [the demo guide](docs/DEMO.md), and [screenshots](docs/SCREENSHOTS.md).

## Existing development server

The original running backend remains in `outputs/sightline-backend` under the Codex workspace. The repository now contains the same FastAPI implementation under `backend`. To switch later, stop the old server, configure `backend/.env` from the example, and start the repository copy on port 3000. Live backend credentials were not copied into this repository.

## Model source

The bundled YOLOv3TinyFP16 model comes from [Apple’s Core ML model catalog](https://developer.apple.com/machine-learning/models/). Consult the model metadata and [upstream Darknet project](https://github.com/pjreddie/darknet) for model attribution and licensing.

## Container

```sh
cd backend
docker build -t sightline-backend .
docker run --rm --env-file .env -p 3000:3000 sightline-backend
```

The Dockerfile is provided for reproducible packaging; container runtime verification and cloud deployment are separate from the tested local backend.
