const functions = require("firebase-functions");
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

async function cleanupDeletedUserData(uid) {
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get().catch(() => null);
  const usernameRaw = userSnap?.data()?.username;
  const username = typeof usernameRaw === "string" ? usernameRaw.toLowerCase() : null;

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
  if (username) {
    await db.collection("usernames").doc(username).delete().catch(() => {});
  }
}

exports.cleanupOnAuthDelete = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  functions.logger.info("Starting backend cleanup for deleted auth user", {uid});

  await cleanupDeletedUserData(uid);

  functions.logger.info("Completed backend cleanup for deleted auth user", {uid});
});
