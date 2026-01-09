export type Restaurant = {
  id: string;
  name: string;
  detail: string;
  imageUrl: string;
  rating: string;
  infoLink: string;
  address: string;
  cuisines: string[];
  neighborhood: string;
};

export const RESTAURANTS: Restaurant[] = [
  {
    id: 'xian-famous-foods',
    name: "Xi'an Famous Foods",
    detail: 'Hand-pulled noodles and bold Xi’an-style spices served fast.',
    imageUrl:
      'https://images.unsplash.com/photo-1559050019-6c1d1a20f86b?auto=format&fit=crop&w=900&q=80',
    rating: '4.7 / 5',
    infoLink: 'https://www.xianfoods.com/',
    address: '81 St Marks Pl, New York, NY 10003',
    cuisines: ['chinese', 'sichuan', 'noodles'],
    neighborhood: 'East Village',
  },
  {
    id: 'han-dynasty',
    name: 'Han Dynasty',
    detail: 'Classic Sichuan dishes with a cult following for peppercorn heat.',
    imageUrl:
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
    rating: '4.6 / 5',
    infoLink: 'https://handynasty.net/',
    address: '90 3rd Ave, New York, NY 10003',
    cuisines: ['chinese', 'sichuan'],
    neighborhood: 'East Village',
  },
  {
    id: 'redfarm',
    name: 'RedFarm',
    detail: 'Modern Chinese small plates with playful presentation.',
    imageUrl:
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80&sat=-20',
    rating: '4.5 / 5',
    infoLink: 'https://redfarmnyc.com/',
    address: '529 Hudson St, New York, NY 10014',
    cuisines: ['chinese', 'dim sum', 'modern'],
    neighborhood: 'West Village',
  },
  {
    id: 'mott-32',
    name: 'Mott 32',
    detail: 'Upscale Cantonese dining with dramatic interiors and cocktails.',
    imageUrl:
      'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=900&q=80',
    rating: '4.8 / 5',
    infoLink: 'https://mott32.com/newyork/',
    address: '387 Park Ave S, New York, NY 10016',
    cuisines: ['chinese', 'cantonese', 'fine dining'],
    neighborhood: 'Midtown',
  },
  {
    id: 'hwa-yuan',
    name: 'Hwa Yuan Szechuan',
    detail: 'Historic hot spot famous for sesame noodles and banquet menus.',
    imageUrl:
      'https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=900&q=80',
    rating: '4.4 / 5',
    infoLink: 'https://hwayuannyc.com/',
    address: '42 E Broadway, New York, NY 10002',
    cuisines: ['chinese', 'szechuan'],
    neighborhood: 'Chinatown',
  },
  {
    id: 'cafe-china',
    name: 'Cafe China',
    detail: 'Art-deco dining room with refined takes on Sichuan staples.',
    imageUrl:
      'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=900&q=80',
    rating: '4.6 / 5',
    infoLink: 'https://cafechinanyc.com/',
    address: '59 W 37th St, New York, NY 10018',
    cuisines: ['chinese', 'sichuan'],
    neighborhood: 'Midtown',
  },
];
