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

The app writes a `deletion_requests/{uid}` document before removing auth
credentials. A separate admin worker script then deletes Firestore user data in
the background.

Worker entrypoint:

- `admin_cleanup/process_deletion_requests.js`

Run steps:

1. `cd admin_cleanup`
2. `npm install`
3. Set `GOOGLE_APPLICATION_CREDENTIALS` to your Firebase Admin service account JSON path
4. `node process_deletion_requests.js`

Run the worker periodically (Task Scheduler/cron/GitHub Actions) to process new
deletion requests.
