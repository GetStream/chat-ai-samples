import type {
  UserMessageHandler,
  UserMessageHandlerContext,
} from '@stream-io/chat-ai-sdk';
import type { MessageResponse } from 'stream-chat';
import {
  buildBookingConfirmationPayload,
  buildBookingFormPayload,
  type BookingSubmissionContext,
} from './restaurant.ts';

type InteractionPayload = {
  userAction?: {
    name?: string;
    context?: Record<string, unknown>;
  };
};

const parseInteraction = (
  message: MessageResponse,
): { actionName?: string; context?: Record<string, unknown> } | undefined => {
  const base = (message as { extraData?: Record<string, unknown> }).extraData;
  const raw = (base?.a2ui_interaction ??
    (message as unknown as Record<string, unknown>)['a2ui_interaction']) as
    | string
    | undefined;
  if (!raw || typeof raw !== 'string') {
    return undefined;
  }

  try {
    const payload = JSON.parse(raw) as InteractionPayload;
    return {
      actionName: payload.userAction?.name,
      context: payload.userAction?.context ?? undefined,
    };
  } catch (error) {
    console.warn('Failed to parse a2ui interaction payload', error);
    return undefined;
  }
};

const normalizeSubmissionContext = (
  context: Record<string, unknown> | undefined,
): BookingSubmissionContext => {
  const stringValue = (key: string, fallback = ''): string => {
    const value = context?.[key];
    if (typeof value === 'string' && value.trim().length) {
      return value.trim();
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value);
    }
    return fallback;
  };

  return {
    restaurantName: stringValue('restaurantName', 'Restaurant'),
    address: stringValue('address'),
    imageUrl: stringValue('imageUrl'),
    partySize: stringValue('partySize', '2'),
    reservationTime: stringValue('reservationTime', 'Today at 7:00 PM'),
    dietary: stringValue('dietary', 'None'),
  };
};

export const createA2uiInteractionHandler = (): UserMessageHandler => {
  return async ({ message, channel }: UserMessageHandlerContext) => {
    const interaction = parseInteraction(message);
    if (!interaction?.actionName) {
      return false;
    }

    const submissionContext = normalizeSubmissionContext(interaction.context);

    switch (interaction.actionName) {
      case 'book_restaurant': {
        const payload = buildBookingFormPayload(submissionContext);
        await channel.sendMessage({
          text: '',
          ai_generated: true,
          a2ui: payload,
        } as any);
        return true;
      }
      case 'submit_booking': {
        const payload = buildBookingConfirmationPayload(submissionContext);
        await channel.sendMessage({
          text: '',
          ai_generated: true,
          a2ui: payload,
        } as any);
        return true;
      }
      default:
        return false;
    }
  };
};
