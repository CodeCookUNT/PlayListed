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

## Account deletion compliance backend

This app now relies on a Firebase Cloud Function auth trigger to remove user
data from Firestore after the auth account is deleted.

Function entrypoint:

- `functions/index.js` (`cleanupOnAuthDelete`)

Deploy steps:

1. `cd functions`
2. `npm install`
3. `cd ..`
4. `firebase deploy --only functions`
