import type { A2uiActionProvider } from '@stream-io/chat-ai-sdk';

/**
 * Converts a raw context value of unknown shape into a plain string, mirroring
 * the extraction logic used internally by the SDK for its default fallback.
 */
const extractContextValue = (value: unknown): string | undefined => {
  if (value == null) {
    return undefined;
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return String(value);
  }
  if (Array.isArray(value)) {
    return value
      .map((item) => extractContextValue(item))
      .filter((item): item is string => Boolean(item))
      .join(', ');
  }
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return undefined;
};

/**
 * Describes restaurant A2UI actions in natural language so the LLM understands
 * what the user did when they interacted with the booking UI.
 *
 * Handles:
 * - `book_restaurant` — user tapped "Book Now" on a restaurant card
 * - `submit_booking`  — user submitted the reservation form
 *
 * Returns `undefined` for any other action so the SDK falls back to its default
 * serialisation.
 */
export const restaurantActionProvider: A2uiActionProvider = (
  actionName,
  context,
) => {
  const valueFor = (key: string): string | undefined =>
    extractContextValue(context[key]);

  switch (actionName) {
    case 'book_restaurant': {
      const restaurant = valueFor('restaurantName') ?? 'Unknown Restaurant';
      const address = valueFor('address');
      const imageUrl = valueFor('imageUrl');
      const parts = [`USER_WANTS_TO_BOOK: ${restaurant}`];
      if (address) {
        parts.push(`Address: ${address}`);
      }
      if (imageUrl) {
        parts.push(`ImageURL: ${imageUrl}`);
      }
      return parts.join(', ');
    }
    case 'submit_booking': {
      const restaurant = valueFor('restaurantName') ?? 'Unknown Restaurant';
      const partySize = valueFor('partySize') ?? 'Unknown Size';
      const reservationTime = valueFor('reservationTime') ?? 'Unknown Time';
      const dietary = valueFor('dietary') ?? 'None';
      const imageUrl = valueFor('imageUrl');
      let description = `User submitted a booking for ${restaurant} for ${partySize} people at ${reservationTime} with dietary requirements: ${dietary}`;
      if (imageUrl) {
        description += `. Image URL: ${imageUrl}`;
      }
      return description;
    }
    default:
      return undefined;
  }
};
