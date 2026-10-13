import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

export interface PublishResult {
  success: boolean;
  instagramMediaId?: string;
  instagramPermalink?: string;
  error?: string;
}

export class InstagramPublishService {
  private igAccountId: string;
  private accessToken: string;
  private graphApiVersion = 'v20.0';

  constructor() {
    this.igAccountId = process.env.INSTAGRAM_ACCOUNT_ID || '';
    this.accessToken = process.env.INSTAGRAM_ACCESS_TOKEN || '';

    if (!this.igAccountId || !this.accessToken) {
      console.warn('⚠️ Warning: INSTAGRAM_ACCOUNT_ID or INSTAGRAM_ACCESS_TOKEN is missing in .env');
    }
  }

  /**
   * Publishes a video URL as an Instagram Reel on the brand account.
   * @param videoUrl The public HTTPS URL of the video (from Supabase Storage)
   * @param caption The caption text to accompany the Reel
   */
  async publishReel(videoUrl: string, caption: string): Promise<PublishResult> {
    try {
      console.log(`[Instagram] Step 1: Creating Reel container for video: ${videoUrl}`);

      // 1. Create Media Container
      const createContainerUrl = `https://graph.facebook.com/${this.graphApiVersion}/${this.igAccountId}/media`;
      const containerResponse = await axios.post(
        createContainerUrl,
        null,
        {
          params: {
            media_type: 'REELS',
            video_url: videoUrl,
            caption: caption,
            access_token: this.accessToken,
          },
        }
      );

      const creationId = containerResponse.data?.id;
      if (!creationId) {
        throw new Error('Failed to obtain creation_id container from Meta Graph API');
      }

      console.log(`[Instagram] Container created (ID: ${creationId}). Step 2: Waiting for Meta encoding...`);

      // 2. Poll until container status is FINISHED (Instagram transcode process)
      await this.pollContainerStatus(creationId);

      console.log(`[Instagram] Encoding finished! Step 3: Publishing Reel to feed...`);

      // 3. Publish Media Container
      const publishUrl = `https://graph.facebook.com/${this.graphApiVersion}/${this.igAccountId}/media_publish`;
      const publishResponse = await axios.post(
        publishUrl,
        null,
        {
          params: {
            creation_id: creationId,
            access_token: this.accessToken,
          },
        }
      );

      const publishedMediaId = publishResponse.data?.id;
      console.log(`[Instagram] ✅ Reel published successfully! Media ID: ${publishedMediaId}`);

      // 4. Retrieve Permalink
      const permalink = await this.getMediaPermalink(publishedMediaId);

      return {
        success: true,
        instagramMediaId: publishedMediaId,
        instagramPermalink: permalink,
      };
    } catch (error: any) {
      const errorMsg = error.response?.data?.error?.message || error.message;
      console.error(`[Instagram] ❌ Publishing failed: ${errorMsg}`);
      return {
        success: false,
        error: errorMsg,
      };
    }
  }

  /**
   * Polls Meta container status until it becomes FINISHED or errors out.
   */
  private async pollContainerStatus(creationId: string): Promise<void> {
    const statusUrl = `https://graph.facebook.com/${this.graphApiVersion}/${creationId}`;
    const maxAttempts = 30; // Max 2.5 minutes (30 * 5s)
    let attempts = 0;

    while (attempts < maxAttempts) {
      await new Promise((resolve) => setTimeout(resolve, 5000)); // wait 5 seconds

      const res = await axios.get(statusUrl, {
        params: {
          fields: 'status_code,status',
          access_token: this.accessToken,
        },
      });

      const statusCode = res.data?.status_code;
      console.log(`[Instagram] Container status check (${attempts + 1}/${maxAttempts}): ${statusCode}`);

      if (statusCode === 'FINISHED') {
        return;
      }

      if (statusCode === 'ERROR') {
        throw new Error(`Meta media encoding failed: ${JSON.stringify(res.data)}`);
      }

      attempts++;
    }

    throw new Error('Timed out waiting for Instagram Reel container encoding');
  }

  /**
   * Retrieves the public permalink (https://www.instagram.com/reel/...)
   */
  private async getMediaPermalink(mediaId: string): Promise<string> {
    try {
      const url = `https://graph.facebook.com/${this.graphApiVersion}/${mediaId}`;
      const res = await axios.get(url, {
        params: {
          fields: 'permalink',
          access_token: this.accessToken,
        },
      });
      return res.data?.permalink || '';
    } catch {
      return '';
    }
  }
}
