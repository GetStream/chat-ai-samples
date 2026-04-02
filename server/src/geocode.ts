export interface ResolvedLocation {
  coordinates: { latitude: number; longitude: number };
  raw: string;
  postalCode: string;
  city: string;
  areaLevel2: string;
  areaLevel1: string;
  country: string;
}

export async function reverseGeocode(
  latitude: number,
  longitude: number,
): Promise<ResolvedLocation> {
  const apiKey = process.env.GOOGLE_GEOCODING_API_KEY;
  if (!apiKey) throw new Error('GOOGLE_GEOCODING_API_KEY not set');

  const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&key=${apiKey}`;
  const res = await fetch(url);
  const data = await res.json();

  if (data.status !== 'OK' || !data.results?.length) {
    throw new Error(`Geocoding failed: ${data.status}`);
  }

  const result = data.results[0];

  const get = (type: string): string =>
    result.address_components?.find((c: any) => c.types.includes(type))?.long_name ?? '';

  return {
    coordinates: { latitude, longitude },
    raw: JSON.stringify(result),
    postalCode: get('postal_code'),
    city: get('postal_town') || get('locality'),
    areaLevel2: get('administrative_area_level_2'),
    areaLevel1: get('administrative_area_level_1'),
    country: get('country'),
  };
}
