/**
 * What the A2UI v0.8 (`restaurant.ts`) and v0.9 (`restaurant-v09.ts`) restaurant surfaces
 * share, so that both versions show the same content.
 */

export const LIST_SURFACE_ID = 'restaurant-finder';
export const BOOKING_FORM_SURFACE_ID = 'restaurant-booking-form';
export const BOOKING_CONFIRM_SURFACE_ID = 'restaurant-booking-confirmation';

const FALLBACK_IMAGE_URL = 'https://picsum.photos/seed/booking/800/600';

export interface BookingIntentContext {
  restaurantName: string;
  address?: string;
  imageUrl?: string;
}

export interface BookingSubmissionContext extends BookingIntentContext {
  partySize?: string;
  reservationTime?: string;
  dietary?: string;
}

export const bookingFormTitle = (details: BookingIntentContext): string =>
  `Reserve a table at ${details.restaurantName}`;

export const bookingConfirmationTitle = (
  details: BookingIntentContext,
): string => `Reservation confirmed for ${details.restaurantName}`;

export const bookingAddress = (details: BookingIntentContext): string =>
  details.address || 'Address unavailable';

export const bookingImageUrl = (details: BookingIntentContext): string =>
  details.imageUrl || FALLBACK_IMAGE_URL;

export const bookingDetailsText = (details: BookingSubmissionContext): string =>
  `Table for ${details.partySize ?? '2'} on ${formatReservationTime(details.reservationTime) ?? 'your selected date'} with dietary notes: ${details.dietary ?? 'None'}.`;

export const BOOKING_CONFIRMATION_NOTE =
  'We have shared your booking details with the restaurant. Expect a confirmation email shortly.';

const ISO_DATE_TIME =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?(Z|[+-]\d{2}:\d{2})?$/;

/** True if the date and time exist, e.g. not February 30 or 24:00. */
const isRealDateTime = (
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
): boolean => {
  const date = new Date(Date.UTC(year, month - 1, day, hour, minute));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day &&
    date.getUTCHours() === hour &&
    date.getUTCMinutes() === minute
  );
};

/**
 * Formats an ISO 8601 date-time from a DateTimeInput (e.g. `2026-10-02T19:00:00Z`)
 * as readable text (e.g. `Fri, Oct 2, 7:00 PM UTC`), in the time zone of the value.
 * A value without an offset is shown as written, without a time zone.
 * Other values (e.g. `Today at 7:00 PM`, or a date that doesn't exist like
 * February 30) are returned unchanged.
 */
export const formatReservationTime = (
  value: string | undefined,
): string | undefined => {
  const match = value?.match(ISO_DATE_TIME);
  if (!value || !match) {
    return value;
  }
  const [, year, month, day, hour, minute, offset] = match;
  if (!isRealDateTime(+year, +month, +day, +hour, +minute)) {
    return value;
  }
  // Without an offset, read the value as UTC and format it in UTC, so the
  // server's own time zone doesn't change the hour.
  const date = new Date(offset ? value : `${value}Z`);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZone: !offset || offset === 'Z' ? 'UTC' : offset,
    timeZoneName: offset ? 'short' : undefined,
  }).format(date);
};
