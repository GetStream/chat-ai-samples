interface CollectedData {
  title: string;
  description: string;
  advert_type: string;
  breed: string;
  mother_breed: string;
  father_breed: string;
  number_of_males: number;
  number_of_females: number;
  date_of_birth: string;
  ready_to_leave: string;
  price: number;
  deposit_amount: number;
}

interface ListingAttribute {
  key: string;
  value: string;
}

export interface ListingPayload {
  category: string;
  title: string;
  description: string;
  price: { amount: number; currency: string };
  depositAmount: { amount: number; currency: string };
  requiredDeposit: number;
  hidePrice: boolean;
  preferredContact: string;
  location: Record<string, unknown>;
  attributes: ListingAttribute[];
  videos: string[];
  images: string[];
}

// Maps advert_type codes to listing type attribute values
const ADVERT_TYPE_TO_LISTING_TYPE: Record<string, string> = {
  'pets.dogs.forSale': 'pets.listingType.forSale',
  'pets.dogs.studDog': 'pets.listingType.studDog',
  'pets.dogs.wanted': 'pets.listingType.wanted',
  'pets.dogs.rescueRehome': 'pets.listingType.rescueRehome',
};

// Maps the forSale breed codes to the breed attribute codes
// e.g. "pets.dogs.forSale.labradorRetriever" → "pets.dogs.breed.labradorRetriever"
function toBreedAttributeValue(breedCode: string): string {
  const parts = breedCode.split('.');
  const breedName = parts[parts.length - 1];
  return `pets.dogs.breed.${breedName}`;
}

function padToLength(str: string, minLen: number, maxLen: number): string {
  let result = str.trim();
  if (result.length < minLen) {
    result = result.padEnd(minLen, '#');
  }
  if (result.length > maxLen) {
    result = result.slice(0, maxLen);
  }
  return result;
}

export function transformCollectedData(input: CollectedData, location?: Record<string, unknown>): ListingPayload {
  const title = padToLength(input.title, 5, 50);
  const description = padToLength(input.description, 100, 200);
  const breedAttr = toBreedAttributeValue(input.breed);
  const motherBreedAttr = toBreedAttributeValue(input.mother_breed);
  const fatherBreedAttr = toBreedAttributeValue(input.father_breed);
  const dobTimestamp = new Date(input.date_of_birth).toISOString();
  const readyToLeave = new Date(input.ready_to_leave).toISOString();

  const attributes: ListingAttribute[] = [
    { key: 'breed', value: breedAttr },
    { key: 'fatherBreed', value: fatherBreedAttr },
    { key: 'motherBreed', value: motherBreedAttr },
    { key: 'generation', value: 'pets.dogs.generation.f1B' },
    { key: 'listingType', value: ADVERT_TYPE_TO_LISTING_TYPE[input.advert_type] || input.advert_type },
    { key: 'numberOfFemales', value: String(input.number_of_females) },
    { key: 'numberOfMales', value: String(input.number_of_males) },
    { key: 'dateOfBirth', value: dobTimestamp },
    { key: 'readyToLeave', value: readyToLeave },
    { key: 'viewedWith', value: 'true' },
    { key: 'microchipped', value: 'true' },
    { key: 'neutered', value: 'false' },
    { key: 'isBreeder', value: 'true' },
  ];

  return {
    category: 'pets.dogs',
    title,
    description,
    price: { amount: input.price, currency: 'GBP' },
    depositAmount: { amount: input.deposit_amount, currency: 'GBP' },
    requiredDeposit: input.deposit_amount,
    hidePrice: false,
    preferredContact: 'ChatOnly',
    location: location ?? {
      coordinates: { latitude: 53.4327408, longitude: -2.313706 },
      raw: '{"address_components":[{"long_name":"M33 7WR","short_name":"M33 7WR","types":["postal_code"]},{"long_name":"Sale","short_name":"Sale","types":["postal_town"]},{"long_name":"Greater Manchester","short_name":"Greater Manchester","types":["administrative_area_level_2","political"]},{"long_name":"England","short_name":"England","types":["administrative_area_level_1","political"]},{"long_name":"United Kingdom","short_name":"GB","types":["country","political"]}],"formatted_address":"Sale M33 7WR, UK","geometry":{"location":{"lat":53.4327408,"lng":-2.313706},"viewport":{"south":53.43101671238331,"west":-2.317349345330443,"north":53.43694091055722,"east":-2.309293545625865}},"html_attributions":[]}',
      postalCode: 'M33 7WR',
      city: 'Sale',
      areaLevel2: 'Greater Manchester',
      areaLevel1: 'England',
      country: 'United Kingdom',
    },
    attributes,
    videos: [],
    images: [],
  };
}
