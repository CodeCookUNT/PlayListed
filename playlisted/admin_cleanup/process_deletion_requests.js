const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function deleteCollection(colRef, batchSize = 300) {
  while (true) {
    const snap = await colRef.limit(batchSize).get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

async function deleteByQuery(query, options = {}) {
  const {
    batchSize = 300,
    beforeDeleteDoc = null,
  } = options;

  while (true) {
    const snap = await query.limit(batchSize).get();
    if (snap.empty) break;

    if (beforeDeleteDoc) {
      for (const doc of snap.docs) {
        await beforeDeleteDoc(doc);
      }
    }

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

async function cleanupDeletedUserData({uid, username}) {
  const userRef = db.collection("users").doc(uid);
  const normalizedUsername = typeof username === "string"
    ? username.toLowerCase()
    : null;

  await Promise.all([
    deleteCollection(userRef.collection("ratings")),
    deleteCollection(userRef.collection("recommendations")),
    deleteCollection(userRef.collection("friends")),
    deleteCollection(userRef.collection("incoming_requests")),
    deleteCollection(userRef.collection("outgoing_requests")),
    deleteCollection(userRef.collection("co_liked")),
    deleteByQuery(db.collection("song_reviews").where("userId", "==", uid)),
    deleteByQuery(
      db.collection("conversations").where("participants", "array-contains", uid),
      {
        beforeDeleteDoc: async (doc) => {
          await deleteCollection(doc.ref.collection("messages"));
        },
      },
    ),
    deleteByQuery(db.collectionGroup("friends").where("friendUid", "==", uid)),
    deleteByQuery(db.collectionGroup("incoming_requests").where("fromUid", "==", uid)),
    deleteByQuery(db.collectionGroup("outgoing_requests").where("toUid", "==", uid)),
  ]);

  await userRef.delete().catch(() => {});
  if (normalizedUsername) {
    await db.collection("usernames").doc(normalizedUsername).delete().catch(() => {});
  }
}

async function processQueuedDeletionRequests(limit = 25) {
  const snap = await db.collectionGroup("deletion_requests")
    .where("status", "==", "queued")
    .limit(limit)
    .get();

  if (snap.empty) {
    console.log("No queued deletion requests.");
    return;
  }

  for (const reqDoc of snap.docs) {
    const data = reqDoc.data();
    const uid = data.uid || inferUidFromPath(reqDoc.ref.path) || reqDoc.id;
    const username = data.username || null;

    console.log(`Processing deletion request for uid=${uid}`);
    await reqDoc.ref.set({
      status: "processing",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    try {
      await cleanupDeletedUserData({uid, username});
      await reqDoc.ref.set({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      console.log(`Completed deletion request for uid=${uid}`);
    } catch (error) {
      await reqDoc.ref.set({
        status: "error",
        lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        lastErrorMessage: String(error && error.message ? error.message : error),
      }, {merge: true});
      console.error(`Failed deletion for uid=${uid}`, error);
    }
  }
}

function inferUidFromPath(path) {
  // Path format example: users/{uid}/deletion_requests/request
  const parts = path.split("/");
  const usersIdx = parts.indexOf("users");
  if (usersIdx >= 0 && usersIdx + 1 < parts.length) {
    return parts[usersIdx + 1];
  }
  return null;
}

processQueuedDeletionRequests()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Fatal error while processing deletion requests", error);
    process.exit(1);
  });
