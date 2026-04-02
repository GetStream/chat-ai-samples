import { loginWith } from './login';
import { uploadImage } from './imageUpload';
import { createListing, payListingFee, publishListing } from '../graphqlClient';
import type { ListingPayload } from '../transformCollectedData';

export async function createPmgListing(
  payload: ListingPayload,
  imageUrl: string | null,
): Promise<{ id: string; slug: string }> {
  const token = await loginWith('PMG_EMAIL_USER', 'PMG_PASSWORD_USER');
  console.log('Logged in to remote server successfully');

  let finalPayload = payload;
  if (imageUrl) {
    const mediaId = await uploadImage(token, imageUrl);
    console.log('Image uploaded, mediaId:', mediaId);
    finalPayload = { ...payload, images: [mediaId] };
  }

  const { id, slug } = await createListing(token, finalPayload);
  console.log('Listing created successfully:', id, 'slug:', slug);

  try {
    const adminToken = await loginWith('PMG_ADMIN_EMAIL', 'PMG_ADMIN_PASSWORD');
    console.log('Admin logged in successfully');
    await payListingFee(adminToken, id);
    console.log('Listing fee paid successfully');
    await publishListing(adminToken, id);
    console.log('Listing published successfully');
  } catch (error) {
    console.error('Failed to pay fee or publish listing (listing still created):', error);
  }

  return { id, slug };
}
