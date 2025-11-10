import axios from 'axios';
import { z } from 'zod';
import type { AgentTool } from './VercelAIAgent';

interface TemperatureToolArgs {
  location: string;
  unit: 'Celsius' | 'Fahrenheit';
}

const fetchCurrentTemperature = async (location: string) => {
  const apiKey = process.env.OPENWEATHER_API_KEY;
  if (!apiKey) {
    throw new Error(
      'OpenWeatherMap API key is missing. Set it in the environment variables.',
    );
  }
  const encodedLocation = encodeURIComponent(location);
  const url = `https://api.openweathermap.org/data/2.5/weather?q=${encodedLocation}&units=metric&appid=${apiKey}`;

  const response = await axios.get(url);
  const { data } = response;
  const temperatureCelsius: number | undefined = data?.main?.temp;

  if (typeof temperatureCelsius !== 'number') {
    throw new Error('Temperature data not found in the API response.');
  }

  return temperatureCelsius;
};

export const createDefaultTools = (): AgentTool[] => [
  {
    name: 'getCurrentTemperature',
    description: 'Get the current temperature for a specific location',
    instructions:
      'Call getCurrentTemperature only when the user explicitly asks for the current temperature of a specific location.',
    parameters: z.object({
      location: z
        .string()
        .describe('The city and state, e.g., San Francisco, CA'),
      unit: z
        .enum(['Celsius', 'Fahrenheit'])
        .describe(
          "The temperature unit to use. Infer this from the user's location.",
        ),
    }),
    execute: async (args: unknown) => {
      const { location, unit } = args as TemperatureToolArgs;
      const temperatureCelsius = await fetchCurrentTemperature(location);
      const temperature =
        unit === 'Fahrenheit'
          ? (temperatureCelsius * 9) / 5 + 32
          : temperatureCelsius;
      const suffix = unit === 'Celsius' ? 'C' : 'F';
      return `${temperature.toFixed(1)}°${suffix}`;
    },
  },
];
