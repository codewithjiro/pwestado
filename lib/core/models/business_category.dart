import 'package:flutter/material.dart';

/// Sections of the business type picker, in display order.
enum BusinessGroup {
  food('Food & drinks'),
  everyday('Everyday needs'),
  personalCare('Personal care & fitness'),
  lifestyle('Fashion, hobbies & pets'),
  tech('Phones, gadgets & computers'),
  home('Home & building'),
  vehicles('Vehicles'),
  services('Services');

  const BusinessGroup(this.label);

  final String label;
}

/// A business type the user can plan for, mapped to a single OSM tag.
///
/// Every mapping is checked against its OpenStreetMap wiki page
/// (wiki.openstreetmap.org/wiki/Tag:key=value, read 2026-10-24). [id] is
/// stored in saved analyses and must never change for an existing
/// category. The tag is shown only in source details, never as a label.
@immutable
class BusinessCategory {
  const BusinessCategory({
    required this.id,
    required this.label,
    required this.osmTagKey,
    required this.osmTagValue,
    required this.icon,
    required this.group,
    required this.description,
    this.aliases = const [],
    this.coverageNote,
  });

  final String id;
  final String label;
  final String osmTagKey;
  final String osmTagValue;
  final IconData icon;
  final BusinessGroup group;

  /// What the map category covers, in plain words.
  final String description;

  /// Other names people search for, including Filipino terms. Matched
  /// after normalization (lowercase, no accents or punctuation).
  final List<String> aliases;

  /// A known gap between this category and what the user may expect,
  /// shown next to results and passed to AI Insights.
  final String? coverageNote;

  String get osmTag => '$osmTagKey=$osmTagValue';

  // The first release's five categories. Their ids and tags are stored in
  // saved analyses and must stay as they are.

  static const coffeeShop = BusinessCategory(
    id: 'coffee_shop',
    label: 'Coffee Shop',
    osmTagKey: 'amenity',
    osmTagValue: 'cafe',
    icon: Icons.local_cafe_outlined,
    group: BusinessGroup.food,
    description: 'Cafés, coffee shops and tea or milk tea shops.',
    aliases: [
      'cafe',
      'coffee',
      'coffee shop',
      'kapihan',
      'milk tea',
      'milktea',
      'tea shop',
      'bubble tea',
    ],
    coverageNote:
        'Milk tea and tea shops count only when they are mapped as cafés.',
  );

  static const restaurant = BusinessCategory(
    id: 'restaurant',
    label: 'Restaurant',
    osmTagKey: 'amenity',
    osmTagValue: 'restaurant',
    icon: Icons.restaurant_outlined,
    group: BusinessGroup.food,
    description: 'Sit-down restaurants, eateries and carinderias.',
    aliases: [
      'kainan',
      'carinderia',
      'karinderya',
      'eatery',
      'turo turo',
      'restawran',
      'diner',
      'grill',
      'food house',
    ],
  );

  static const convenience = BusinessCategory(
    id: 'convenience',
    label: 'Sari-Sari / Convenience',
    osmTagKey: 'shop',
    osmTagValue: 'convenience',
    icon: Icons.storefront_outlined,
    group: BusinessGroup.everyday,
    description: 'Sari-sari stores, mini marts and convenience stores.',
    aliases: [
      'sari sari',
      'sarisari',
      'sari sari store',
      'tindahan',
      'convenience store',
      'mini mart',
      'minimart',
      'mini grocery',
    ],
    coverageNote:
        'Many small sari-sari stores are not on OpenStreetMap yet, so the '
        'real number nearby is often higher.',
  );

  static const laundry = BusinessCategory(
    id: 'laundry',
    label: 'Laundry Shop',
    osmTagKey: 'shop',
    osmTagValue: 'laundry',
    icon: Icons.local_laundry_service_outlined,
    group: BusinessGroup.services,
    description:
        'Laundry shops and laundromats, self-service or wash-and-fold.',
    aliases: [
      'laundry',
      'laundromat',
      'labada',
      'laba',
      'wash and fold',
      'laundry service',
    ],
  );

  static const bakery = BusinessCategory(
    id: 'bakery',
    label: 'Bakery',
    osmTagKey: 'shop',
    osmTagValue: 'bakery',
    icon: Icons.bakery_dining_outlined,
    group: BusinessGroup.food,
    description: 'Bakeries and bakeshops that sell bread.',
    aliases: [
      'panaderia',
      'panaderya',
      'bakeshop',
      'bake shop',
      'bread',
      'pandesal',
      'tinapay',
    ],
  );

  // Added in the expanded catalog.

  static const fastFood = BusinessCategory(
    id: 'fast_food',
    label: 'Fast Food',
    osmTagKey: 'amenity',
    osmTagValue: 'fast_food',
    icon: Icons.fastfood_outlined,
    group: BusinessGroup.food,
    description: 'Self-service and take-out food places.',
    aliases: [
      'fast food',
      'fastfood',
      'take out',
      'takeout',
      'burger',
      'burgers',
      'fried chicken',
      'pizza',
      'shawarma',
      'siomai',
    ],
  );

  static const iceCream = BusinessCategory(
    id: 'ice_cream',
    label: 'Ice Cream Shop',
    osmTagKey: 'amenity',
    osmTagValue: 'ice_cream',
    icon: Icons.icecream_outlined,
    group: BusinessGroup.food,
    description: 'Shops selling ice cream or frozen yogurt over the counter.',
    aliases: [
      'ice cream',
      'sorbetes',
      'gelato',
      'frozen yogurt',
      'froyo',
      'dessert shop',
    ],
  );

  static const meatShop = BusinessCategory(
    id: 'meat_shop',
    label: 'Meat Shop',
    osmTagKey: 'shop',
    osmTagValue: 'butcher',
    icon: Icons.kebab_dining_outlined,
    group: BusinessGroup.food,
    description: 'Shops that mainly sell meat.',
    aliases: ['butcher', 'meat', 'meat shop', 'karnehan', 'karne'],
    coverageNote:
        'Meat stalls inside public markets are rarely mapped one by one.',
  );

  static const supermarket = BusinessCategory(
    id: 'supermarket',
    label: 'Supermarket',
    osmTagKey: 'shop',
    osmTagValue: 'supermarket',
    icon: Icons.shopping_cart_outlined,
    group: BusinessGroup.everyday,
    description: 'Large grocery stores and supermarkets.',
    aliases: [
      'grocery',
      'groceries',
      'grocery store',
      'hypermarket',
      'hypermart',
      'supermart',
    ],
  );

  static const varietyStore = BusinessCategory(
    id: 'variety_store',
    label: 'General Variety Store',
    osmTagKey: 'shop',
    osmTagValue: 'variety_store',
    icon: Icons.category_outlined,
    group: BusinessGroup.everyday,
    description: 'Low-price stores selling many kinds of inexpensive items.',
    aliases: [
      'variety',
      'variety store',
      'general merchandise',
      'general store',
      'bazaar',
      'dollar store',
      'peso store',
    ],
    coverageNote:
        'Some general merchandise stores are mapped as convenience stores '
        'instead, so also check Sari-Sari / Convenience.',
  );

  static const waterRefilling = BusinessCategory(
    id: 'water_refilling',
    label: 'Water Refilling Station',
    osmTagKey: 'shop',
    osmTagValue: 'water',
    icon: Icons.water_drop_outlined,
    group: BusinessGroup.everyday,
    description: 'Shops that mainly sell drinking water, including refills.',
    aliases: [
      'water refilling',
      'water refilling station',
      'refilling station',
      'water station',
      'purified water',
      'mineral water',
      'drinking water',
      'tubig',
    ],
    coverageNote:
        'Water refilling stations are a newer map category, so many are '
        'not mapped yet.',
  );

  static const pharmacy = BusinessCategory(
    id: 'pharmacy',
    label: 'Pharmacy / Drugstore',
    osmTagKey: 'amenity',
    osmTagValue: 'pharmacy',
    icon: Icons.local_pharmacy_outlined,
    group: BusinessGroup.everyday,
    description: 'Pharmacies and drugstores where a pharmacist sells medicine.',
    aliases: [
      'pharmacy',
      'drugstore',
      'drug store',
      'botika',
      'botica',
      'parmasya',
      'medicine',
      'gamot',
    ],
  );

  static const barbershop = BusinessCategory(
    id: 'barbershop_hairdresser',
    label: 'Barbershop / Hairdresser',
    osmTagKey: 'shop',
    osmTagValue: 'hairdresser',
    icon: Icons.content_cut,
    group: BusinessGroup.personalCare,
    description: 'Barbershops and hair salons where hair is cut.',
    aliases: [
      'barbershop',
      'barber',
      'barber shop',
      'barberya',
      'barberia',
      'hairdresser',
      'hair salon',
      'haircut',
      'hair cut',
      'gupitan',
    ],
    coverageNote:
        'OpenStreetMap uses one category for both barbershops and hair '
        'salons, so results include both. Only some records say they are a '
        'barber.',
  );

  static const beautySalon = BusinessCategory(
    id: 'beauty_salon',
    label: 'Beauty Salon / Spa',
    osmTagKey: 'shop',
    osmTagValue: 'beauty',
    icon: Icons.face_retouching_natural_outlined,
    group: BusinessGroup.personalCare,
    description: 'Beauty, nail and facial salons and beauty spas.',
    aliases: [
      'beauty salon',
      'beauty parlor',
      'beauty parlour',
      'parlor',
      'salon',
      'nail salon',
      'nails',
      'manicure',
      'pedicure',
      'spa',
      'facial',
      'lash',
      'waxing',
    ],
    coverageNote:
        'Salons that mainly cut hair are usually mapped as hairdressers, so '
        'also check Barbershop / Hairdresser.',
  );

  static const massage = BusinessCategory(
    id: 'massage',
    label: 'Massage Shop',
    osmTagKey: 'shop',
    osmTagValue: 'massage',
    icon: Icons.spa_outlined,
    group: BusinessGroup.personalCare,
    description: 'Massage and reflexology shops.',
    aliases: [
      'massage',
      'masahe',
      'hilot',
      'reflexology',
      'massage spa',
      'foot spa',
    ],
  );

  static const gym = BusinessCategory(
    id: 'gym',
    label: 'Gym / Fitness Center',
    osmTagKey: 'leisure',
    osmTagValue: 'fitness_centre',
    icon: Icons.fitness_center,
    group: BusinessGroup.personalCare,
    description: 'Gyms and fitness centers with machines or classes.',
    aliases: [
      'gym',
      'fitness',
      'fitness center',
      'fitness centre',
      'fitness gym',
      'workout',
      'crossfit',
    ],
  );

  static const optical = BusinessCategory(
    id: 'optical_shop',
    label: 'Optical Shop',
    osmTagKey: 'shop',
    osmTagValue: 'optician',
    icon: Icons.remove_red_eye_outlined,
    group: BusinessGroup.personalCare,
    description: 'Shops that sell and fit eyeglasses and contact lenses.',
    aliases: [
      'optical',
      'optician',
      'optical shop',
      'eyeglasses',
      'eye glasses',
      'salamin sa mata',
      'contact lens',
      'contact lenses',
    ],
  );

  static const clothing = BusinessCategory(
    id: 'clothing',
    label: 'Clothing Store',
    osmTagKey: 'shop',
    osmTagValue: 'clothes',
    icon: Icons.checkroom_outlined,
    group: BusinessGroup.lifestyle,
    description: 'Shops that mainly sell clothes.',
    aliases: [
      'clothing',
      'clothes',
      'damit',
      'boutique',
      'apparel',
      'fashion',
      'rtw',
      'ready to wear',
    ],
  );

  static const thrift = BusinessCategory(
    id: 'thrift_ukay',
    label: 'Thrift / Ukay-Ukay',
    osmTagKey: 'shop',
    osmTagValue: 'second_hand',
    icon: Icons.recycling_outlined,
    group: BusinessGroup.lifestyle,
    description: 'Shops selling second-hand goods, such as ukay-ukay.',
    aliases: [
      'ukay',
      'ukay ukay',
      'ukayan',
      'thrift',
      'thrift store',
      'thrift shop',
      'second hand',
      'secondhand',
      'segunda mano',
      'surplus',
    ],
    coverageNote:
        'Second-hand shops that focus on one product (such as used phones) '
        'may be mapped under that product instead.',
  );

  static const bookstore = BusinessCategory(
    id: 'bookstore',
    label: 'Bookstore',
    osmTagKey: 'shop',
    osmTagValue: 'books',
    icon: Icons.menu_book_outlined,
    group: BusinessGroup.lifestyle,
    description: 'Stores that mainly sell books.',
    aliases: ['books', 'book store', 'book shop', 'libro', 'tindahan ng libro'],
  );

  static const petShop = BusinessCategory(
    id: 'pet_shop',
    label: 'Pet Shop',
    osmTagKey: 'shop',
    osmTagValue: 'pet',
    icon: Icons.pets_outlined,
    group: BusinessGroup.lifestyle,
    description: 'Shops selling pets or pet supplies and food.',
    aliases: [
      'pet',
      'pets',
      'pet store',
      'petshop',
      'pet supplies',
      'pet food',
      'dog food',
      'cat food',
    ],
  );

  static const florist = BusinessCategory(
    id: 'florist',
    label: 'Florist',
    osmTagKey: 'shop',
    osmTagValue: 'florist',
    icon: Icons.local_florist_outlined,
    group: BusinessGroup.lifestyle,
    description: 'Flower shops selling bouquets and cut flowers.',
    aliases: ['flower shop', 'flowers', 'flower', 'bulaklak', 'bouquet'],
  );

  static const electronics = BusinessCategory(
    id: 'electronics',
    label: 'Electronics Store',
    osmTagKey: 'shop',
    osmTagValue: 'electronics',
    icon: Icons.tv_outlined,
    group: BusinessGroup.tech,
    description: 'Shops selling TVs, appliances and other electronics.',
    aliases: [
      'electronics',
      'electronic store',
      'appliance',
      'appliances',
      'appliance store',
      'gadgets',
      'gadget store',
    ],
  );

  static const mobilePhone = BusinessCategory(
    id: 'mobile_phone',
    label: 'Mobile Phone Shop',
    osmTagKey: 'shop',
    osmTagValue: 'mobile_phone',
    icon: Icons.smartphone_outlined,
    group: BusinessGroup.tech,
    description: 'Shops that mainly sell mobile phones and accessories.',
    aliases: [
      'cellphone',
      'cell phone',
      'cellphone shop',
      'cellphone store',
      'mobile phone',
      'phone shop',
      'phone store',
      'cp shop',
      'smartphone',
    ],
  );

  static const computerStore = BusinessCategory(
    id: 'computer_store',
    label: 'Computer Store',
    osmTagKey: 'shop',
    osmTagValue: 'computer',
    icon: Icons.computer_outlined,
    group: BusinessGroup.tech,
    description: 'Shops selling computers, parts and software.',
    aliases: [
      'computer store',
      'laptop',
      'laptop store',
      'computer parts',
      'pc parts',
      'pc store',
    ],
  );

  static const electronicsRepair = BusinessCategory(
    id: 'electronics_repair',
    label: 'Phone & Computer Repair',
    osmTagKey: 'craft',
    osmTagValue: 'electronics_repair',
    icon: Icons.build_outlined,
    group: BusinessGroup.tech,
    description:
        'Repair shops and service centers for phones, computers and '
        'appliances.',
    aliases: [
      'computer repair',
      'laptop repair',
      'pc repair',
      'cellphone repair',
      'phone repair',
      'gadget repair',
      'appliance repair',
      'electronics repair',
      'tv repair',
    ],
    coverageNote:
        'Shops that both sell and repair are often mapped as a store only, '
        'so also check Computer Store or Mobile Phone Shop.',
  );

  static const internetCafe = BusinessCategory(
    id: 'internet_cafe',
    label: 'Internet Café / Computer Shop',
    osmTagKey: 'amenity',
    osmTagValue: 'internet_cafe',
    icon: Icons.desktop_windows_outlined,
    group: BusinessGroup.tech,
    description:
        'Places that rent computers and internet by the hour, such as '
        'pisonet shops.',
    aliases: [
      'internet cafe',
      'computer shop',
      'computer rental',
      'pisonet',
      'piso net',
      'net cafe',
      'cybercafe',
      'cyber cafe',
      'internet shop',
    ],
  );

  static const hardware = BusinessCategory(
    id: 'hardware',
    label: 'Hardware Store',
    osmTagKey: 'shop',
    osmTagValue: 'hardware',
    icon: Icons.hardware_outlined,
    group: BusinessGroup.home,
    description: 'Shops selling tools, fasteners and household hardware.',
    aliases: ['hardware', 'tools', 'tool shop', 'ferreteria'],
  );

  static const homeImprovement = BusinessCategory(
    id: 'home_improvement',
    label: 'Construction & Home Depot',
    osmTagKey: 'shop',
    osmTagValue: 'doityourself',
    icon: Icons.construction_outlined,
    group: BusinessGroup.home,
    description: 'Large home-improvement and construction supply stores.',
    aliases: [
      'construction supply',
      'construction supplies',
      'building materials',
      'home improvement',
      'home depot',
      'diy',
    ],
    coverageNote:
        'Smaller construction supply stores are often mapped as hardware '
        'stores, so also check Hardware Store.',
  );

  static const furniture = BusinessCategory(
    id: 'furniture',
    label: 'Furniture Store',
    osmTagKey: 'shop',
    osmTagValue: 'furniture',
    icon: Icons.chair_outlined,
    group: BusinessGroup.home,
    description: 'Shops that sell furniture.',
    aliases: ['furniture', 'furnitures', 'muwebles', 'sofa', 'furniture shop'],
  );

  static const gasStation = BusinessCategory(
    id: 'gas_station',
    label: 'Gas Station',
    osmTagKey: 'amenity',
    osmTagValue: 'fuel',
    icon: Icons.local_gas_station_outlined,
    group: BusinessGroup.vehicles,
    description: 'Fuel stations for cars and motorcycles.',
    aliases: [
      'gasoline',
      'gasoline station',
      'gasolinahan',
      'petrol',
      'petrol station',
      'fuel',
      'filling station',
    ],
  );

  static const carWash = BusinessCategory(
    id: 'car_wash',
    label: 'Car Wash',
    osmTagKey: 'amenity',
    osmTagValue: 'car_wash',
    icon: Icons.local_car_wash_outlined,
    group: BusinessGroup.vehicles,
    description: 'Places that wash cars and other motor vehicles.',
    aliases: ['carwash', 'auto wash', 'motor wash', 'motorwash', 'car wash'],
  );

  static const autoRepair = BusinessCategory(
    id: 'auto_repair',
    label: 'Auto Repair Shop',
    osmTagKey: 'shop',
    osmTagValue: 'car_repair',
    icon: Icons.car_repair_outlined,
    group: BusinessGroup.vehicles,
    description: 'Shops where cars are repaired and serviced.',
    aliases: [
      'auto repair',
      'car repair',
      'car service',
      'mechanic',
      'talyer',
      'auto shop',
      'auto service',
      'casa',
    ],
  );

  static const autoParts = BusinessCategory(
    id: 'auto_parts',
    label: 'Auto Parts Store',
    osmTagKey: 'shop',
    osmTagValue: 'car_parts',
    icon: Icons.handyman_outlined,
    group: BusinessGroup.vehicles,
    description: 'Shops selling car parts, accessories and motor oil.',
    aliases: [
      'auto parts',
      'car parts',
      'auto supply',
      'car accessories',
      'auto accessories',
      'motor oil',
    ],
  );

  static const tyres = BusinessCategory(
    id: 'tire_vulcanizing',
    label: 'Tire / Vulcanizing Shop',
    osmTagKey: 'shop',
    osmTagValue: 'tyres',
    icon: Icons.tire_repair_outlined,
    group: BusinessGroup.vehicles,
    description: 'Shops that sell or repair tires, such as vulcanizing shops.',
    aliases: [
      'vulcanizing',
      'vulcanizing shop',
      'vulcanize',
      'tire',
      'tires',
      'tire shop',
      'tyre',
      'tyres',
      'gulong',
    ],
    coverageNote: 'Small roadside vulcanizing stands are often not on the map.',
  );

  static const motorcycleShop = BusinessCategory(
    id: 'motorcycle_shop',
    label: 'Motorcycle Shop',
    osmTagKey: 'shop',
    osmTagValue: 'motorcycle',
    icon: Icons.two_wheeler_outlined,
    group: BusinessGroup.vehicles,
    description:
        'Shops selling motorcycles, parts, accessories or riding gear.',
    aliases: [
      'motorcycle',
      'motorcycle dealer',
      'motorcycle parts',
      'motorcycle accessories',
      'motor parts',
      'moto parts',
      'motor shop',
      'motorshop',
    ],
    coverageNote:
        'Parts-only shops are mapped in different ways, so some may be '
        'missing.',
  );

  static const motorcycleRepair = BusinessCategory(
    id: 'motorcycle_repair',
    label: 'Motorcycle Repair Shop',
    osmTagKey: 'shop',
    osmTagValue: 'motorcycle_repair',
    icon: Icons.motorcycle_outlined,
    group: BusinessGroup.vehicles,
    description: 'Shops where motorcycles are repaired.',
    aliases: [
      'motorcycle repair',
      'motor repair',
      'motorcycle mechanic',
      'motorcycle service',
      'talyer ng motor',
    ],
    coverageNote:
        'Shops that both sell and repair motorcycles may be mapped as a '
        'Motorcycle Shop instead.',
  );

  static const bicycleShop = BusinessCategory(
    id: 'bicycle_shop',
    label: 'Bicycle Shop',
    osmTagKey: 'shop',
    osmTagValue: 'bicycle',
    icon: Icons.pedal_bike_outlined,
    group: BusinessGroup.vehicles,
    description: 'Shops that sell or repair bicycles and accessories.',
    aliases: [
      'bicycle',
      'bike',
      'bike shop',
      'bisikleta',
      'bike repair',
      'bicycle repair',
    ],
  );

  static const dryCleaning = BusinessCategory(
    id: 'dry_cleaning',
    label: 'Dry Cleaner',
    osmTagKey: 'shop',
    osmTagValue: 'dry_cleaning',
    icon: Icons.dry_cleaning_outlined,
    group: BusinessGroup.services,
    description: 'Shops that mainly offer dry cleaning of clothes.',
    aliases: ['dry cleaning', 'dry cleaner', 'dry cleaners'],
  );

  static const printing = BusinessCategory(
    id: 'printing',
    label: 'Printing / Photocopy Shop',
    osmTagKey: 'shop',
    osmTagValue: 'copyshop',
    icon: Icons.print_outlined,
    group: BusinessGroup.services,
    description: 'Shops offering photocopying and document printing.',
    aliases: [
      'printing',
      'printing shop',
      'print shop',
      'printing services',
      'photocopy',
      'xerox',
      'copy center',
      'copy shop',
      'print',
    ],
  );

  static const pawnshop = BusinessCategory(
    id: 'pawnshop',
    label: 'Pawnshop',
    osmTagKey: 'shop',
    osmTagValue: 'pawnbroker',
    icon: Icons.diamond_outlined,
    group: BusinessGroup.services,
    description: 'Pawnshops that lend money against jewelry and other items.',
    aliases: ['pawn shop', 'pawnbroker', 'sanglaan', 'prenda'],
  );

  /// Every supported category, in picker order within each group.
  static const all = [
    coffeeShop,
    restaurant,
    fastFood,
    bakery,
    iceCream,
    meatShop,
    convenience,
    supermarket,
    varietyStore,
    waterRefilling,
    pharmacy,
    barbershop,
    beautySalon,
    massage,
    gym,
    optical,
    clothing,
    thrift,
    bookstore,
    petShop,
    florist,
    electronics,
    mobilePhone,
    computerStore,
    electronicsRepair,
    internetCafe,
    hardware,
    homeImprovement,
    furniture,
    gasStation,
    carWash,
    autoRepair,
    autoParts,
    tyres,
    motorcycleShop,
    motorcycleRepair,
    bicycleShop,
    laundry,
    dryCleaning,
    printing,
    pawnshop,
  ];

  static final Map<String, BusinessCategory> _byId = {
    for (final c in all) c.id: c,
  };

  /// The category stored under [id], or null for an unknown id.
  static BusinessCategory? byId(String id) => _byId[id];

  @override
  bool operator ==(Object other) => other is BusinessCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BusinessCategory($id)';
}
