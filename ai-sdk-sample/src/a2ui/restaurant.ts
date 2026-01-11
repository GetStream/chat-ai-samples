import type {
  FinalMessageAugmentor,
  FinalMessageAugmentorContext,
} from '@stream-io/chat-ai-sdk';
import { RESTAURANTS, type Restaurant } from './restaurant-data.ts';

const SURFACE_ID = 'restaurant-finder';
const ROOT_COMPONENT_ID = 'restaurant-root';
const DEFAULT_RESULT_LIMIT = 4;
const RESTAURANT_KEYWORDS = [
  'restaurant',
  'restaurants',
  'dining',
  'table',
  'reservation',
  'book a table',
  'place to eat',
  'food spot',
];

const RESTAURANT_COMPONENTS: Array<Record<string, unknown>> = [
  {
    id: ROOT_COMPONENT_ID,
    component: {
      Column: {
        children: {
          explicitList: ['title-heading', 'restaurant-list'],
        },
      },
    },
  },
  {
    id: 'title-heading',
    component: {
      Text: {
        usageHint: 'h2',
        text: { path: 'title' },
      },
    },
  },
  {
    id: 'restaurant-list',
    component: {
      List: {
        direction: 'vertical',
        children: {
          template: {
            componentId: 'restaurant-card',
            dataBinding: '/items',
          },
        },
      },
    },
  },
  {
    id: 'restaurant-card',
    component: {
      Card: {
        child: 'restaurant-card-body',
      },
    },
  },
  {
    id: 'restaurant-card-body',
    component: {
      Row: {
        children: {
          explicitList: ['restaurant-image', 'restaurant-details'],
        },
      },
    },
  },
  {
    id: 'restaurant-image',
    weight: 1,
    component: {
      Image: {
        url: { path: 'imageUrl' },
        fit: 'cover',
        usageHint: 'smallFeature',
      },
    },
  },
  {
    id: 'restaurant-details',
    weight: 2,
    component: {
      Column: {
        children: {
          explicitList: [
            'restaurant-name',
            'restaurant-rating',
            'restaurant-detail',
            'restaurant-link',
            'restaurant-book-button',
          ],
        },
      },
    },
  },
  {
    id: 'restaurant-name',
    component: {
      Text: {
        usageHint: 'h4',
        text: { path: 'name' },
      },
    },
  },
  {
    id: 'restaurant-rating',
    component: {
      Text: {
        text: { path: 'rating' },
      },
    },
  },
  {
    id: 'restaurant-detail',
    component: {
      Text: {
        text: { path: 'detail' },
      },
    },
  },
  {
    id: 'restaurant-link',
    component: {
      Text: {
        text: { path: 'infoLink' },
      },
    },
  },
  {
    id: 'restaurant-book-button',
    component: {
      Button: {
        child: 'book-now-text',
        primary: true,
        action: {
          name: 'book_restaurant',
          context: [
            { key: 'restaurantName', value: { path: 'name' } },
            { key: 'address', value: { path: 'address' } },
            { key: 'imageUrl', value: { path: 'imageUrl' } },
          ],
        },
      },
    },
  },
  {
    id: 'book-now-text',
    component: {
      Text: {
        text: { literalString: 'Book Now' },
      },
    },
  },
];

const extractLatestUserText = (
  messages: FinalMessageAugmentorContext['messages'],
): string | undefined => {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const message = messages[i];
    if (message.role !== 'user') continue;
    const content = message.content;
    if (typeof content === 'string') {
      const trimmed = content.trim();
      if (trimmed.length) {
        return trimmed;
      }
      continue;
    }
    if (Array.isArray(content)) {
      const joined = content
        .map((part) =>
          typeof part === 'string'
            ? part
            : typeof part === 'object' && 'text' in part && typeof part.text === 'string'
              ? part.text
              : '',
        )
        .join(' ')
        .trim();
      if (joined.length) {
        return joined;
      }
    }
  }
  return undefined;
};

const isRestaurantIntent = (text: string): boolean => {
  const normalized = text.toLowerCase();
  return RESTAURANT_KEYWORDS.some((keyword) => normalized.includes(keyword));
};

const clampCount = (value: number): number => {
  return Math.min(Math.max(value, 1), RESTAURANTS.length);
};

const extractRequestedCount = (text: string): number => {
  const match = text.match(/\b(\d{1,2})\b/);
  if (!match) {
    return DEFAULT_RESULT_LIMIT;
  }
  const parsed = Number.parseInt(match[1] ?? '', 10);
  if (Number.isNaN(parsed)) {
    return DEFAULT_RESULT_LIMIT;
  }
  return clampCount(parsed);
};

const LOCATION_REGEX = /\b(?:in|around|near)\s+([a-z\s]+?)(?:[.,!?]|$)/i;

const extractLocation = (text: string): string | undefined => {
  const match = LOCATION_REGEX.exec(text);
  if (!match) return undefined;
  const raw = match[1]?.trim();
  if (!raw) return undefined;
  return raw
    .split(/\s+/)
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(' ');
};

const selectRestaurants = (query: string, limit: number): Restaurant[] => {
  const normalized = query.toLowerCase();
  const cuisineMatches = RESTAURANTS.filter((restaurant) =>
    restaurant.cuisines.some((cuisine) => normalized.includes(cuisine)),
  );
  const source = cuisineMatches.length ? cuisineMatches : RESTAURANTS;
  return source.slice(0, clampCount(limit));
};

const buildDataModelContents = (
  restaurants: Restaurant[],
  title: string,
): Array<Record<string, unknown>> => {
  const contents: Array<Record<string, unknown>> = [
    { key: 'title', valueString: title },
    {
      key: 'items',
      valueMap: restaurants.map((restaurant, index) => ({
        key: `item${index + 1}`,
        valueMap: [
          { key: 'id', valueString: restaurant.id },
          { key: 'name', valueString: restaurant.name },
          { key: 'detail', valueString: restaurant.detail },
          { key: 'rating', valueString: restaurant.rating },
          { key: 'infoLink', valueString: restaurant.infoLink },
          { key: 'imageUrl', valueString: restaurant.imageUrl },
          { key: 'address', valueString: restaurant.address },
          { key: 'neighborhood', valueString: restaurant.neighborhood },
        ],
      })),
    },
  ];
  return contents;
};

const buildRestaurantMessages = (
  restaurants: Restaurant[],
  title: string,
): Array<Record<string, unknown>> => {
  return [
    {
      beginRendering: {
        surfaceId: SURFACE_ID,
        root: ROOT_COMPONENT_ID,
        styles: {
          primaryColor: '#D84315',
          font: 'Roboto',
        },
      },
    },
    {
      surfaceUpdate: {
        surfaceId: SURFACE_ID,
        components: RESTAURANT_COMPONENTS,
      },
    },
    {
      dataModelUpdate: {
        surfaceId: SURFACE_ID,
        path: '/',
        contents: buildDataModelContents(restaurants, title),
      },
    },
  ];
};

const buildRestaurantPayload = (
  restaurants: Restaurant[],
  title: string,
  query: string,
): Record<string, unknown> => ({
  version: '0.8',
  surfaceId: SURFACE_ID,
  intent: 'restaurant_recommendation',
  metadata: {
    title,
    query,
    total_results: restaurants.length,
  },
  messages: buildRestaurantMessages(restaurants, title),
});

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

const BOOKING_FORM_SURFACE_ID = 'restaurant-booking-form';
const BOOKING_CONFIRM_SURFACE_ID = 'restaurant-booking-confirmation';
const BOOKING_PRIMARY_COLOR = '#D84315';

const BOOKING_FORM_COMPONENTS: Array<Record<string, unknown>> = [
  {
    id: 'booking-form-root',
    component: {
      Column: {
        spacing: 'large',
        children: {
          explicitList: [
            'booking-title',
            'booking-image',
            'booking-address',
            'booking-party',
            'booking-time',
            'booking-dietary',
            'booking-submit',
          ],
        },
      },
    },
  },
  {
    id: 'booking-title',
    component: {
      Text: {
        usageHint: 'h2',
        text: { path: 'title' },
      },
    },
  },
  {
    id: 'booking-image',
    component: {
      Image: {
        url: { path: 'imageUrl' },
        fit: 'cover',
        usageHint: 'feature',
      },
    },
  },
  {
    id: 'booking-address',
    component: {
      Text: {
        text: { path: 'address' },
      },
    },
  },
  {
    id: 'booking-party',
    component: {
      TextField: {
        label: 'Party size',
        inputType: 'number',
        dataBinding: '/partySize',
      },
    },
  },
  {
    id: 'booking-time',
    component: {
      DateTimeInput: {
        label: 'Reservation time',
        dataBinding: '/reservationTime',
      },
    },
  },
  {
    id: 'booking-dietary',
    component: {
      TextField: {
        label: 'Dietary requirements',
        dataBinding: '/dietary',
      },
    },
  },
  {
    id: 'booking-submit',
    component: {
      Button: {
        child: 'booking-submit-text',
        primary: true,
        action: {
          name: 'submit_booking',
          context: [
            { key: 'restaurantName', value: { path: 'restaurantName' } },
            { key: 'address', value: { path: 'address' } },
            { key: 'imageUrl', value: { path: 'imageUrl' } },
            { key: 'partySize', value: { path: 'partySize' } },
            { key: 'reservationTime', value: { path: 'reservationTime' } },
            { key: 'dietary', value: { path: 'dietary' } },
          ],
        },
      },
    },
  },
  {
    id: 'booking-submit-text',
    component: {
      Text: {
        text: { literalString: 'Confirm reservation' },
      },
    },
  },
];

const BOOKING_CONFIRM_COMPONENTS: Array<Record<string, unknown>> = [
  {
    id: 'booking-confirm-root',
    component: {
      Column: {
        spacing: 'large',
        children: {
          explicitList: [
            'booking-confirm-title',
            'booking-confirm-image',
            'booking-confirm-details',
            'booking-confirm-note',
          ],
        },
      },
    },
  },
  {
    id: 'booking-confirm-title',
    component: {
      Text: {
        usageHint: 'h2',
        text: { path: 'title' },
      },
    },
  },
  {
    id: 'booking-confirm-image',
    component: {
      Image: {
        url: { path: 'imageUrl' },
        fit: 'cover',
        usageHint: 'feature',
      },
    },
  },
  {
    id: 'booking-confirm-details',
    component: {
      Text: {
        text: { path: 'bookingDetails' },
      },
    },
  },
  {
    id: 'booking-confirm-note',
    component: {
      Text: {
        text: { path: 'note' },
      },
    },
  },
];

const buildBookingFormMessages = (
  details: BookingSubmissionContext,
): Array<Record<string, unknown>> => [
  {
    beginRendering: {
      surfaceId: BOOKING_FORM_SURFACE_ID,
      root: 'booking-form-root',
      styles: {
        primaryColor: BOOKING_PRIMARY_COLOR,
        font: 'Roboto',
      },
    },
  },
  {
    surfaceUpdate: {
      surfaceId: BOOKING_FORM_SURFACE_ID,
      components: BOOKING_FORM_COMPONENTS,
    },
  },
  {
    dataModelUpdate: {
      surfaceId: BOOKING_FORM_SURFACE_ID,
      path: '/',
      contents: [
        {
          key: 'title',
          valueString: `Reserve a table at ${details.restaurantName}`,
        },
        {
          key: 'address',
          valueString: details.address ?? 'Address unavailable',
        },
        {
          key: 'imageUrl',
          valueString: details.imageUrl ?? 'https://picsum.photos/seed/booking/800/600',
        },
        {
          key: 'partySize',
          valueString: details.partySize ?? '2',
        },
        {
          key: 'reservationTime',
          valueString: details.reservationTime ?? 'Today at 7:00 PM',
        },
        {
          key: 'dietary',
          valueString: details.dietary ?? 'None',
        },
        {
          key: 'restaurantName',
          valueString: details.restaurantName,
        },
      ],
    },
  },
];

const buildBookingConfirmationMessages = (
  details: BookingSubmissionContext,
): Array<Record<string, unknown>> => [
  {
    beginRendering: {
      surfaceId: BOOKING_CONFIRM_SURFACE_ID,
      root: 'booking-confirm-root',
      styles: {
        primaryColor: BOOKING_PRIMARY_COLOR,
        font: 'Roboto',
      },
    },
  },
  {
    surfaceUpdate: {
      surfaceId: BOOKING_CONFIRM_SURFACE_ID,
      components: BOOKING_CONFIRM_COMPONENTS,
    },
  },
  {
    dataModelUpdate: {
      surfaceId: BOOKING_CONFIRM_SURFACE_ID,
      path: '/',
      contents: [
        {
          key: 'title',
          valueString: `Reservation confirmed for ${details.restaurantName}`,
        },
        {
          key: 'bookingDetails',
          valueString: `Table for ${details.partySize ?? '2'} on ${details.reservationTime ?? 'your selected date'} with dietary notes: ${details.dietary ?? 'None'}.`,
        },
        {
          key: 'imageUrl',
          valueString: details.imageUrl ?? 'https://picsum.photos/seed/booking/800/600',
        },
        {
          key: 'note',
          valueString: 'We have shared your booking details with the restaurant. Expect a confirmation email shortly.',
        },
      ],
    },
  },
];

export const buildBookingFormPayload = (
  details: BookingSubmissionContext,
): Record<string, unknown> => ({
  version: '0.8',
  surfaceId: BOOKING_FORM_SURFACE_ID,
  intent: 'restaurant_booking_form',
  metadata: {
    title: `Booking form for ${details.restaurantName}`,
  },
  messages: buildBookingFormMessages(details),
});

export const buildBookingConfirmationPayload = (
  details: BookingSubmissionContext,
): Record<string, unknown> => ({
  version: '0.8',
  surfaceId: BOOKING_CONFIRM_SURFACE_ID,
  intent: 'restaurant_booking_confirmation',
  metadata: {
    title: `Reservation confirmed for ${details.restaurantName}`,
  },
  messages: buildBookingConfirmationMessages(details),
});

export const restaurantA2uiAugmentor: FinalMessageAugmentor = async (
  context,
) => {
  const userInput = extractLatestUserText(context.messages ?? []);
  if (!userInput || !isRestaurantIntent(userInput)) {
    return undefined;
  }

  const limit = extractRequestedCount(userInput);
  const restaurants = selectRestaurants(userInput, limit);
  if (!restaurants.length) {
    return undefined;
  }
  const requestedLocation = extractLocation(userInput);
  const resolvedTitle = requestedLocation
    ? `Top ${restaurants.length} restaurants in ${requestedLocation}`
    : `Top ${restaurants.length} restaurant picks`;

  const payload = buildRestaurantPayload(
    restaurants,
    resolvedTitle,
    userInput,
  );

  return {
    a2ui: payload,
  };
};
