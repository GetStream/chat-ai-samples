import type { Restaurant } from './restaurant-data.ts';
import {
  formatReservationTime,
  type BookingSubmissionContext,
} from './restaurant.ts';

/**
 * A2UI v0.9 versions of the restaurant surfaces built in `restaurant.ts`.
 *
 * Clients that render v0.9 (e.g. the Android sample) read the `a2ui_v09` message field.
 */

/**
 * Set `A2UI_PROTOCOL=v0.9` to send the v0.9 payload (`a2ui_v09`) instead of v0.8 (`a2ui`).
 * Only one is sent, because both together exceed Stream's 5 KB message custom data limit.
 */
export const useA2uiV09 = process.env.A2UI_PROTOCOL === 'v0.9';

const VERSION = 'v0.9';
const BASIC_CATALOG_ID =
  'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

const LIST_SURFACE_ID = 'restaurant-finder';
const BOOKING_FORM_SURFACE_ID = 'restaurant-booking-form';
const BOOKING_CONFIRM_SURFACE_ID = 'restaurant-booking-confirmation';
const FALLBACK_IMAGE_URL = 'https://picsum.photos/seed/booking/800/600';

const RESTAURANT_LIST_COMPONENTS: Array<Record<string, unknown>> = [
  {
    id: 'root',
    component: 'Column',
    children: ['title-heading', 'restaurant-list'],
  },
  {
    id: 'title-heading',
    component: 'Text',
    variant: 'h2',
    text: { path: '/title' },
  },
  {
    id: 'restaurant-list',
    component: 'List',
    direction: 'vertical',
    children: { componentId: 'restaurant-card', path: '/items' },
  },
  {
    id: 'restaurant-card',
    component: 'Card',
    child: 'restaurant-card-body',
  },
  {
    id: 'restaurant-card-body',
    component: 'Row',
    children: ['restaurant-image', 'restaurant-details'],
  },
  {
    id: 'restaurant-image',
    component: 'Image',
    weight: 1,
    url: { path: 'imageUrl' },
    fit: 'cover',
    variant: 'smallFeature',
  },
  {
    id: 'restaurant-details',
    component: 'Column',
    weight: 2,
    children: [
      'restaurant-name',
      'restaurant-rating',
      'restaurant-detail',
      'restaurant-link',
      'restaurant-book-button',
    ],
  },
  {
    id: 'restaurant-name',
    component: 'Text',
    variant: 'h4',
    text: { path: 'name' },
  },
  {
    id: 'restaurant-rating',
    component: 'Text',
    text: { path: 'rating' },
  },
  {
    id: 'restaurant-detail',
    component: 'Text',
    text: { path: 'detail' },
  },
  {
    id: 'restaurant-link',
    component: 'Text',
    text: { path: 'infoLink' },
  },
  {
    id: 'restaurant-book-button',
    component: 'Button',
    child: 'book-now-text',
    variant: 'primary',
    action: {
      event: {
        name: 'book_restaurant',
        context: {
          restaurantName: { path: 'name' },
          address: { path: 'address' },
          imageUrl: { path: 'imageUrl' },
        },
      },
    },
  },
  {
    id: 'book-now-text',
    component: 'Text',
    text: 'Book Now',
  },
];

const BOOKING_FORM_COMPONENTS: Array<Record<string, unknown>> = [
  {
    id: 'root',
    component: 'Column',
    children: [
      'booking-title',
      'booking-image',
      'booking-address',
      'booking-party',
      'booking-time',
      'booking-dietary',
      'booking-submit',
    ],
  },
  {
    id: 'booking-title',
    component: 'Text',
    variant: 'h2',
    text: { path: '/title' },
  },
  {
    id: 'booking-image',
    component: 'Image',
    url: { path: '/imageUrl' },
    fit: 'cover',
    variant: 'mediumFeature',
  },
  {
    id: 'booking-address',
    component: 'Text',
    text: { path: '/address' },
  },
  {
    id: 'booking-party',
    component: 'TextField',
    label: 'Party size',
    variant: 'number',
    value: { path: '/partySize' },
  },
  {
    id: 'booking-time',
    component: 'DateTimeInput',
    label: 'Reservation time',
    enableDate: true,
    enableTime: true,
    value: { path: '/reservationTime' },
  },
  {
    id: 'booking-dietary',
    component: 'TextField',
    label: 'Dietary requirements',
    value: { path: '/dietary' },
  },
  {
    id: 'booking-submit',
    component: 'Button',
    child: 'booking-submit-text',
    variant: 'primary',
    action: {
      event: {
        name: 'submit_booking',
        context: {
          restaurantName: { path: '/restaurantName' },
          address: { path: '/address' },
          imageUrl: { path: '/imageUrl' },
          partySize: { path: '/partySize' },
          reservationTime: { path: '/reservationTime' },
          dietary: { path: '/dietary' },
        },
      },
    },
  },
  {
    id: 'booking-submit-text',
    component: 'Text',
    text: 'Confirm reservation',
  },
];

const BOOKING_CONFIRM_COMPONENTS: Array<Record<string, unknown>> = [
  {
    id: 'root',
    component: 'Column',
    children: [
      'booking-confirm-title',
      'booking-confirm-image',
      'booking-confirm-details',
      'booking-confirm-note',
    ],
  },
  {
    id: 'booking-confirm-title',
    component: 'Text',
    variant: 'h2',
    text: { path: '/title' },
  },
  {
    id: 'booking-confirm-image',
    component: 'Image',
    url: { path: '/imageUrl' },
    fit: 'cover',
    variant: 'mediumFeature',
  },
  {
    id: 'booking-confirm-details',
    component: 'Text',
    text: { path: '/bookingDetails' },
  },
  {
    id: 'booking-confirm-note',
    component: 'Text',
    text: { path: '/note' },
  },
];

const buildSurfaceMessages = (
  surfaceId: string,
  components: Array<Record<string, unknown>>,
  data: Record<string, unknown>,
): Array<Record<string, unknown>> => [
  {
    version: VERSION,
    createSurface: { surfaceId, catalogId: BASIC_CATALOG_ID },
  },
  {
    version: VERSION,
    updateComponents: { surfaceId, components },
  },
  {
    version: VERSION,
    updateDataModel: { surfaceId, path: '/', value: data },
  },
];

const buildPayload = (
  surfaceId: string,
  components: Array<Record<string, unknown>>,
  data: Record<string, unknown>,
): Record<string, unknown> => ({
  version: VERSION,
  surfaceId,
  messages: buildSurfaceMessages(surfaceId, components, data),
});

/**
 * The form's default time: "today at 7 PM" as an ISO 8601 local time without an offset
 * (e.g. `2026-10-14T19:00:00`), so each client shows 7 PM in its own time zone. The date is
 * the server's current UTC date, so it can differ by a day from the client's date.
 */
const defaultReservationTime = (): string =>
  `${new Date().toISOString().slice(0, 10)}T19:00:00`;

export const buildRestaurantPayloadV09 = (
  restaurants: Restaurant[],
  title: string,
): Record<string, unknown> =>
  buildPayload(LIST_SURFACE_ID, RESTAURANT_LIST_COMPONENTS, {
    title,
    items: restaurants.map((restaurant) => ({
      id: restaurant.id,
      name: restaurant.name,
      detail: restaurant.detail,
      rating: restaurant.rating,
      infoLink: restaurant.infoLink,
      imageUrl: restaurant.imageUrl,
      address: restaurant.address,
      neighborhood: restaurant.neighborhood,
    })),
  });

export const buildBookingFormPayloadV09 = (
  details: BookingSubmissionContext,
): Record<string, unknown> =>
  buildPayload(BOOKING_FORM_SURFACE_ID, BOOKING_FORM_COMPONENTS, {
    title: `Reserve a table at ${details.restaurantName}`,
    restaurantName: details.restaurantName,
    address: details.address || 'Address unavailable',
    imageUrl: details.imageUrl || FALLBACK_IMAGE_URL,
    partySize: details.partySize ?? '2',
    reservationTime: defaultReservationTime(),
    dietary: details.dietary ?? 'None',
  });

export const buildBookingConfirmationPayloadV09 = (
  details: BookingSubmissionContext,
): Record<string, unknown> =>
  buildPayload(BOOKING_CONFIRM_SURFACE_ID, BOOKING_CONFIRM_COMPONENTS, {
    title: `Reservation confirmed for ${details.restaurantName}`,
    bookingDetails: `Table for ${details.partySize ?? '2'} on ${formatReservationTime(details.reservationTime) ?? 'your selected date'} with dietary notes: ${details.dietary ?? 'None'}.`,
    imageUrl: details.imageUrl || FALLBACK_IMAGE_URL,
    note: 'We have shared your booking details with the restaurant. Expect a confirmation email shortly.',
  });
