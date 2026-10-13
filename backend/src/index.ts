import admin from 'firebase-admin';
import { cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import * as dotenv from 'dotenv';
import { InstagramPublishService } from './instagramService';

dotenv.config();

// Initialize Firebase Admin
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
    const serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
    admin.initializeApp({
      credential: cert(serviceAccount),
    });
  } else {
    admin.initializeApp();
  }
} catch (e) {
  console.log('Firebase Admin initialized or waiting for credentials');
}

const db = getFirestore();
const igService = new InstagramPublishService();

/**
 * Watches Firestore for new videos with status: 'ready_for_instagram'
 * and automatically publishes them as Instagram Reels.
 */
export function startInstagramAutoPublisher() {
  console.log('🚀 Instagram Auto-Publisher Engine is running. Listening for approved videos...');

  db.collection('videos')
    .where('status', '==', 'ready_for_instagram')
    .onSnapshot((snapshot) => {
      snapshot.docChanges().forEach(async (change) => {
        if (change.type === 'added' || change.type === 'modified') {
          const doc = change.doc;
          const data = doc.data();

          console.log(`\n📢 New video found for publishing! Video ID: ${doc.id}`);

          // Set status to publishing to prevent duplicate processing
          await doc.ref.update({
            status: 'publishing_to_instagram',
            publishStartedAt: FieldValue.serverTimestamp(),
          });

          // Call Instagram Graph API
          const result = await igService.publishReel(
            data.videoUrl,
            data.caption || 'Community Video Reel'
          );

          if (result.success) {
            await doc.ref.update({
              status: 'published_on_instagram',
              instagramMediaId: result.instagramMediaId,
              instagramPermalink: result.instagramPermalink,
              publishedAt: FieldValue.serverTimestamp(),
            });
            console.log(`🎉 Successfully published video ${doc.id} to Instagram!`);
          } else {
            await doc.ref.update({
              status: 'instagram_publish_failed',
              instagramError: result.error,
            });
            console.error(`⚠️ Failed to publish video ${doc.id}: ${result.error}`);
          }
        }
      });
    });
}

// Entrypoint
if (require.main === module) {
  startInstagramAutoPublisher();
}
