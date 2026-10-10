# Sightline demo

Show how a local object finder and a cloud scene description support spoken interaction. Prepare a chair and bottle in good light, keep the iPhone upright, and start the backend before opening the app.

## Demonstration sequence

1. Open Sightline and show the large Start Walking Mode control. Explain that setup requires permission grants.
2. Start, wait for Listening, and say “Sightline, find me a chair.” Point at the chair and move it across the camera image to demonstrate left, ahead, and right. These are image positions, not measured distances.
3. After speech finishes and listening resumes, say “Sightline, find me a bottle.” Show that supported targets can change.
4. Say “Sightline, describe the scene.” The app gives a spoken progress cue, sends one snapshot, displays Gemini’s response, and reads it aloud.
5. Tap Stop during a description or speech. Confirm that output stops and the app returns to Ready. Start again to demonstrate recovery.
6. Enable VoiceOver and show labeled controls. Increase text size and show that the screen scrolls and actions remain reachable.
7. If demonstrating a cloud outage, stop the backend, request a scene description, and explain the explicitly labeled local object summary. Restart the backend afterward.

## Honest project claims

The model supports 80 classes; voice find commands currently support five. The prototype has no measured accuracy benchmark, distance estimation, persistent object tracks, maps, ElevenLabs, database, or deployed cloud service. Present model and request timings as individual observations, not a general speed guarantee.

## Simulator screenshots

In the Sightline scheme, use Debug launch argument `--demo` to inspect sample content without camera or microphone permissions. Add `--dark-demo` alongside `--demo` to inspect dark appearance. Remove both before testing the actual app. This fixture is disabled in Release builds and visibly labeled as a demo.
