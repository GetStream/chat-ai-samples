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
