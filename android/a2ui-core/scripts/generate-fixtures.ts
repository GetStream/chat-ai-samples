/**
 * Writes the A2UI v0.9 payloads of the ai-sdk-sample backend as JSON test fixtures.
 *
 * Run from `android/a2ui-core` (needs `npm install` in `ai-sdk-sample` first):
 *
 *   node --import ../../ai-sdk-sample/ts-esm-loader.mjs scripts/generate-fixtures.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { RESTAURANTS } from '../../../ai-sdk-sample/src/a2ui/restaurant-data.ts';
import {
  buildBookingConfirmationPayloadV09,
  buildBookingFormPayloadV09,
  buildRestaurantPayloadV09,
} from '../../../ai-sdk-sample/src/a2ui/restaurant-v09.ts';

const outDir = new URL('../src/test/resources/fixtures/', import.meta.url);
mkdirSync(outDir, { recursive: true });

const write = (name: string, payload: unknown) => {
  writeFileSync(new URL(name, outDir), `${JSON.stringify(payload, null, 2)}\n`);
};

const restaurants = RESTAURANTS.slice(0, 3);
const [first] = restaurants;

write(
  'restaurant-list.json',
  buildRestaurantPayloadV09(restaurants, 'Top 3 restaurants in New York'),
);
write(
  'booking-form.json',
  buildBookingFormPayloadV09({
    restaurantName: first.name,
    address: first.address,
    imageUrl: first.imageUrl,
  }),
);
write(
  'booking-confirmation.json',
  buildBookingConfirmationPayloadV09({
    restaurantName: first.name,
    address: first.address,
    imageUrl: first.imageUrl,
    partySize: '4',
    reservationTime: '2026-10-02T19:00:00+01:00',
    dietary: 'Vegetarian',
  }),
);
