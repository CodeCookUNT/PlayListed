# playlisted

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Account deletion compliance worker (no Blaze required)

The app writes a deletion request before removing auth credentials. It first
tries `deletion_requests/{uid}`, and falls back to
`users/{uid}/deletion_requests/request` for stricter Firestore rulesets. If
both are blocked, it marks `users/{uid}.deletionRequested = true` as a final
fallback. A separate admin worker script then deletes Firestore user data in
the background.

If all request paths are blocked by rules, the app still completes auth account
deletion/sign-out (so the user cannot log back in) and cleanup must be handled
manually/admin-side.

Worker entrypoint:

- `admin_cleanup/process_deletion_requests.js`

Run steps:

1. `cd admin_cleanup`
2. `npm install`
3. Set `GOOGLE_APPLICATION_CREDENTIALS` to your Firebase Admin service account JSON path
4. `node process_deletion_requests.js`

Run the worker periodically (Task Scheduler/cron/GitHub Actions) to process new
deletion requests.
