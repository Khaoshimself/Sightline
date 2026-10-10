# Sightline validation

## Automated and integration checks

- FastAPI: 13 tests pass, covering authentication, payload validation and size limits, concurrent requests, provider errors, timeouts, disconnect cancellation, response parsing, supported thinking levels, and removal of the old speech endpoint.
- Live backend: `/describe` returned HTTP 200 and a Gemini description of a synthetic gray JPEG in about 0.95 seconds on October 10, 2026. Direct Flash-Lite image inference returned in about 1.27 seconds. These individual diagnostic calls are not a latency benchmark or accuracy evaluation.
- Swift: 27 command checks pass, including five targets, wake-word boundaries, partial commands, repeated commands, and the previously logged cumulative transcript.
- Simulator: all three UI checks pass, including accessibility audits, three Start and Stop cycles, and largest-text scene content. Dark appearance was explicitly enabled in the demo fixture, audited again, and visually verified. Delivery screenshots are in `docs/images`.
- Backend setup: the full pinned dependency set installed in a clean Python 3.12 environment; all 13 tests passed there.
- Device: the signed iPhone build succeeded and installed on Bryan’s iPhone 17. Automatic launch was blocked because the phone was locked.

## Physical iPhone checks

Use the freshly installed build. These require a person using the microphone, speaker, and VoiceOver; simulator sample content does not establish that they pass.

- Say “Sightline, find me a chair” twice, waiting for Listening between commands. Confirm one acknowledgement per command.
- Say “Sightline, describe the scene.” Confirm a progress cue, scene text, spoken output, then Listening.
- Tap Stop during speech and during an outstanding description. Confirm no late output restarts the session.
- Start, Stop, and Start again; confirm fresh recognition and capture.
- Interrupt with Siri or a call, then return. Confirm no stale command fires; Resume Voice must be available when automatic resume is not permitted.
- Disconnect headphones while active, then use Resume Voice with the new audio route.
- Enable VoiceOver. Locate and activate Start, Describe Scene, Find an Object, and Stop using their labels and hints.
- Use the largest accessibility text size in light and dark appearance. Confirm buttons and descriptions wrap and remain reachable by scrolling.

## Limits

Automated accessibility audits check properties such as labels, contrast, target size, and text layout; they cannot establish the usability of the spoken interaction for a blind user. Real user testing remains necessary. The iOS 27 deprecated input-tap API still builds; a future audio API migration is outside this completion pass.
