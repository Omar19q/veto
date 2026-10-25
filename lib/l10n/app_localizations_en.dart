// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get system => 'Use device settings';

  @override
  String get preferenceSaveFailed =>
      'Your setting could not be saved. Please try again.';

  @override
  String get whereTo => 'Where to?';

  @override
  String get pickup => 'Pickup';

  @override
  String get destination => 'Destination';

  @override
  String get changeAddress => 'Change address';

  @override
  String get home => 'Home';

  @override
  String get work => 'Work';

  @override
  String get savedPlaces => 'Saved places';

  @override
  String get recentPlaces => 'Recent destinations';

  @override
  String get useLocation => 'Use my location';

  @override
  String get choosePickup => 'Choose pickup location';

  @override
  String get chooseDestination => 'Choose destination';

  @override
  String get services => 'Choose a service';

  @override
  String get car => 'Car';

  @override
  String get motorcycle => 'Motorcycle';

  @override
  String get tukTuk => 'Tuk-tuk';

  @override
  String get delivery => 'Delivery';

  @override
  String get confirmRide => 'Confirm ride';

  @override
  String get viewFare => 'See fare';

  @override
  String get searching => 'Looking for a nearby captain';

  @override
  String get cancel => 'Cancel';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Try again';

  @override
  String get continueAction => 'Continue';

  @override
  String get close => 'Close';

  @override
  String get support => 'Support';

  @override
  String get price => 'Fare';

  @override
  String get wallet => 'Wallet';

  @override
  String get cash => 'Cash';

  @override
  String get offers => 'Available offers';

  @override
  String get suggestAddress => 'Can\'t find your area or building?';

  @override
  String get suggestionTitle => 'Suggest an address';

  @override
  String get suggestionInfo =>
      'This is a private suggestion for review. It does not enable rides in an unsupported city.';

  @override
  String get city => 'City';

  @override
  String get area => 'Area';

  @override
  String get buildingLetter => 'Building letter (optional)';

  @override
  String get buildingNumber => 'Building number';

  @override
  String get address => 'Address description';

  @override
  String get note => 'Additional note';

  @override
  String get sendReview => 'Send for review';

  @override
  String get mySuggestions => 'My address suggestions';

  @override
  String get pending => 'Pending review';

  @override
  String get needsInformation => 'More information needed';

  @override
  String get rejected => 'Rejected';

  @override
  String get published => 'Published';

  @override
  String get reviewed => 'Reviewed';

  @override
  String get suggestionSent => 'Your suggestion was sent for review.';

  @override
  String get suggestionRateLimit =>
      'Please wait a minute before sending another suggestion.';

  @override
  String get suggestionInvalid =>
      'Check the address details and select a valid location.';

  @override
  String get suggestionCityMismatch =>
      'Choose the correct city for this address.';

  @override
  String get suggestionFailed =>
      'The suggestion could not be confirmed. Check its status or retry with the same details. Your ride and wallet were unchanged.';

  @override
  String get locationUnconfirmed =>
      'Selected location — confirm the address or add a description.';

  @override
  String get gpsPermission =>
      'Allow location access, or choose an address manually.';

  @override
  String get gpsDisabled =>
      'Location services are off. You can choose an address manually.';

  @override
  String get gpsFailed =>
      'We couldn\'t obtain a reliable location. Choose an address manually or try again.';

  @override
  String get phone => 'Phone number';

  @override
  String get country => 'Country';

  @override
  String get countrySearch => 'Search country or calling code';

  @override
  String get phoneInvalid =>
      'Enter a valid phone number for the selected country.';

  @override
  String get verificationRequest =>
      'A verification code will be sent through the existing WhatsApp verification service.';

  @override
  String get bookingCreated => 'Your ride request was created';

  @override
  String get captainAcceptance => 'Captain acceptance';

  @override
  String get rideDuration => 'Trip duration';

  @override
  String get noReliableEstimate => 'Searching — no reliable time estimate yet';

  @override
  String get optionalOffer => 'You can increase your offer if you wish.';

  @override
  String get higherOfferHelp =>
      'A higher offer may interest more captains. Acceptance is not guaranteed.';

  @override
  String get market => 'VETO Market';

  @override
  String get enterPhone => 'Enter your phone number';

  @override
  String get requestCode => 'Request verification code via WhatsApp';

  @override
  String get verificationFailed =>
      'We couldn\'t submit the verification request. Please try again.';

  @override
  String get internationalUnavailable =>
      'Verification is not available for this country yet. Choose a supported country.';

  @override
  String get preferencesLoadFailed =>
      'Your saved settings couldn\'t be restored. Choose your language and appearance again.';

  @override
  String get offersDelivered => 'Offers created';

  @override
  String get deliveredSearchRadius => 'Last offer radius';

  @override
  String get continueConsent => 'By continuing, you agree to';

  @override
  String get terms => 'Terms of service';

  @override
  String get privacy => 'Privacy policy';

  @override
  String get and => 'and';

  @override
  String get morning => 'Good morning';

  @override
  String get afternoon => 'Good afternoon';

  @override
  String get evening => 'Good evening';

  @override
  String get welcome => 'Welcome';

  @override
  String get notifications => 'Notifications';

  @override
  String get profile => 'Profile';

  @override
  String get currency => 'EGP';

  @override
  String get specialOffer => 'Available offer';

  @override
  String get bookNow => 'Book now';

  @override
  String get openMarket => 'Open VETO Market';

  @override
  String get offersUnavailable =>
      'Offers could not be loaded. You can still book a ride.';

  @override
  String get findingLocation => 'Finding your location…';

  @override
  String get chooseLocation => 'Choose your pickup location';

  @override
  String get selectedLocation => 'Selected location';

  @override
  String get bookingGuide =>
      'Choose pickup and destination, then review the fare before confirming. Save frequent addresses for faster booking.';

  @override
  String get understood => 'Got it';

  @override
  String get suggestionReplay =>
      'The previous submission may have reached the server. Retry with the same details to check its receipt.';

  @override
  String get emptySuggestions => 'No address suggestions yet.';

  @override
  String get addressSearchFailed =>
      'Address search is unavailable. Choose a saved address or a pin, or try again.';

  @override
  String get quoteFailed =>
      'The server could not confirm the fare. Please try again.';

  @override
  String get routeDisplayUnavailable =>
      'Road route preview is unavailable. Pickup and destination pins remain accurate.';

  @override
  String get accountLoadFailed =>
      'Your account or active ride could not be refreshed. Retry before relying on these details.';

  @override
  String get marketLoadFailed =>
      'Your market order status could not be loaded. Ride booking is still available.';

  @override
  String get correctSuggestion => 'Correct details';

  @override
  String get uiea5f73b8 =>
      'Your location is unavailable. Choose a pin on the map.';

  @override
  String get ui4e3d1712 => 'Pickup';

  @override
  String get ui396197d7 => 'Choose a valid destination first.';

  @override
  String get uia8d53c82 =>
      'The server could not confirm the fare. Please try again.';

  @override
  String get uic32397f1 => 'No valid fare is available.';

  @override
  String get ui44a70a8d => 'Choose a pickup with valid coordinates.';

  @override
  String get ui2c00f52f => 'Choose a destination with valid coordinates.';

  @override
  String get ui2beacbfd => 'You already have an active ride.';

  @override
  String get ui70e7a8c0 => 'Your active ride could not be checked.';

  @override
  String get ui41f09900 => 'Choose your service';

  @override
  String get uia3ac6d76 => 'Destination';

  @override
  String get ui7fc5c5dd => 'Review and confirm your ride';

  @override
  String get ui09e60c0f => 'Choose service and fare';

  @override
  String get ui56807a6f => 'Choose your offer';

  @override
  String get uib075cda8 => 'Ride details';

  @override
  String get ui3c6518b4 => 'Searching for a captain';

  @override
  String get ui07676a93 => 'Captain offers';

  @override
  String get uic714374d => 'Where to?';

  @override
  String get ui74cafc32 => 'Place categories could not be loaded. Try again.';

  @override
  String get ui15cd2781 => 'Registered places could not be loaded.';

  @override
  String get ui02609bec => 'Buildings in this area could not be loaded.';

  @override
  String get ui5c6fddf6 =>
      'Choose your area letter first to find the correct building.';

  @override
  String get uiec4369bc => 'Enter a building number from 1 to 590.';

  @override
  String get ui39c9c0fc => 'Building search is unavailable.';

  @override
  String get ui2acdce12 => 'Selected map location';

  @override
  String get ui0282b8e7 => 'This place has no verified coordinates.';

  @override
  String get ui46d9c9af => 'Registered place';

  @override
  String get ui5f74518a => 'This building has no verified coordinates.';

  @override
  String get ui3ccabf1f =>
      'Choose the area letter in the highlighted field first.';

  @override
  String get ui8e451470 =>
      'Enter a building number from 1 to 590, then select Add.';

  @override
  String get ui5dd6c786 =>
      'This ride will use your selected location. The building becomes public only after review.';

  @override
  String get ui91aff234 => 'Choose pickup location';

  @override
  String get ui5bdfac2b => 'Your location, a building, or a saved place';

  @override
  String get uia1f24fc1 => 'Choose city';

  @override
  String get uiaae85882 => 'Use my location';

  @override
  String get ui0ecb38c0 => 'Choose a pin on the map';

  @override
  String get ui4960a634 => 'Building';

  @override
  String get uib5d1d3fe => 'Area letter and building number';

  @override
  String get ui947ac162 => 'Known place';

  @override
  String get ui92c0fd35 => 'A registered gate, restaurant, school, or landmark';

  @override
  String get ui9f290894 => 'Saved places';

  @override
  String get uiefe7950f => 'Home, work, or a place you saved';

  @override
  String get uif36f493e => 'Change address type';

  @override
  String get ui72de3382 => 'Saved place';

  @override
  String get ui5c204281 => 'Landmark or pickup note (optional)';

  @override
  String get uifad68bbd => 'For example, by the side gate';

  @override
  String get ui19896675 => 'No registered places in this category yet.';

  @override
  String get uiae7ae56d => 'Pickup';

  @override
  String get uie0d502ff => 'Choose area';

  @override
  String get uieca4806f => 'Building number';

  @override
  String get ui7af87c25 => 'For example: 125';

  @override
  String get ui99bef41e =>
      'This number was not found. You can suggest the building location below.';

  @override
  String get ui23e4b967 => 'No registered buildings in this area yet.';

  @override
  String get ui09d5b8ff => 'Enter a building number to search.';

  @override
  String get ui42ebe4b5 => 'Select your building from the results';

  @override
  String get ui6b9fed40 =>
      'Finish entering the number to find the correct building.';

  @override
  String get uifc5bae31 => 'Cannot find your building?';

  @override
  String get ui8616aae5 => 'Suggest your building on the map for review.';

  @override
  String get uibff694c6 => 'Save this place';

  @override
  String get ui85c938bf => 'Save this building';

  @override
  String get ui700ee7bb => 'Choose a building with verified coordinates.';

  @override
  String get ui566d62bb =>
      'Your pickup has no coordinates. Choose it from registered places or the map.';

  @override
  String get uib70a4633 => 'Choose destination';

  @override
  String get ui42f90d2d => 'Choose on map';

  @override
  String get ui3d03e800 => 'Place the pin yourself';

  @override
  String get ui2a038421 => 'Building in Hadayek Al Ahram';

  @override
  String get ui018f341c => 'Choose the area or search by building number';

  @override
  String get ui4f301aa9 =>
      'A registered gate, bank, restaurant, school, or mosque';

  @override
  String get uie2a404ff => 'Choose home, work, or a saved address';

  @override
  String get uif8b22ed8 => 'Another city or area';

  @override
  String get ui955024f3 => 'Search for the place or choose it on the map';

  @override
  String get ui1e33ffb8 =>
      'Search by city or place name, then choose the result.';

  @override
  String get ui5ed8eb3d => 'For example: Downtown, Alexandria, Ain Sokhna';

  @override
  String get uidde5f7a4 => 'For example: Downtown or a place name';

  @override
  String get uib8818d2d => 'No matching places were found.';

  @override
  String get ui90754ad6 => 'Destination';

  @override
  String get uide6f5aba =>
      '1. Select your area letter in the highlighted field';

  @override
  String get ui9ba6e611 =>
      '2. Enter your building number, then select its card';

  @override
  String get ui498edaea => 'No building with this number was found.';

  @override
  String get ui533b3b9d => 'Enter the building number to see results here.';

  @override
  String get ui5d77e042 =>
      'Select a destination card below to calculate the server fare.';

  @override
  String get uibc40c997 => 'This code has expired';

  @override
  String get ui327c8f24 => 'This offer has not started';

  @override
  String get uif628612e => 'This code is currently disabled';

  @override
  String get ui9b548771 => 'The code usage limit has been reached';

  @override
  String get uiab945993 => 'The offer has reached its customer limit';

  @override
  String get ui312fca54 => 'You have reached your usage limit for this code';

  @override
  String get uidf40e49a => 'This offer needs review';

  @override
  String get ui3b3d074b => 'No discount is available for this ride';

  @override
  String get ui2dcb22b8 => 'Sign in with an active customer account';

  @override
  String get ui28fd5fd3 => 'Connection failed. Please try again';

  @override
  String get uia73828a5 => 'This code is invalid or unavailable';

  @override
  String get uidd00b654 => 'Distance';

  @override
  String get uia7947509 => 'Duration';

  @override
  String get ui45a9a436 => 'Fare';

  @override
  String get uid219bc19 => 'Enter code';

  @override
  String get ui84c7eeb2 => 'Expected purchase amount — optional';

  @override
  String get ui1881ccb3 => 'Cash';

  @override
  String get ui898cec70 => 'Pay the captain in cash';

  @override
  String get uidf1727d8 => 'Wallet';

  @override
  String get ui92215af2 => 'Wallet + cash';

  @override
  String get ui8b068efc => 'Destination';

  @override
  String get ui69cb4d81 => 'Wallet';

  @override
  String get uid1588f9b => 'Wallet + cash';

  @override
  String get uiff8a5dd1 => 'Transport fare';

  @override
  String get ui87369f01 => 'Added incentive';

  @override
  String get uif28e3f71 => 'Previous amount due';

  @override
  String get uib593a645 => 'Discount';

  @override
  String get uif918ebca => 'Total after discount';

  @override
  String get ui70cc122a => 'Paid from wallet';

  @override
  String get ui741126d6 => 'No registered places near your available location';

  @override
  String get ui228e7f21 => 'Nearby places';

  @override
  String get uif51ac3a9 => 'Previous amount due';

  @override
  String get uid7788534 => 'Services available for this route';

  @override
  String get uicb6c9e7d =>
      'Transport fare before incentive, discount and previous due';

  @override
  String get uid8019644 => 'Continue to discount and payment';

  @override
  String get ui1dc14005 =>
      'The first eligible captain to accept is assigned automatically.';

  @override
  String get ui4c324b17 => 'Start your request';

  @override
  String get uia06d487b => 'Where will we pick you up?';

  @override
  String get ui94709dd1 => 'Review request';

  @override
  String get ui194ae5ca => 'Searching';

  @override
  String get ui595241dd => 'Captain offers received';

  @override
  String get ui674f7a10 => 'Choose a service to continue.';

  @override
  String get ui5acaa87e => 'Your current location or another pickup';

  @override
  String get ui4ef558e7 => 'Search for a place or select a map pin';

  @override
  String get uice4a26ca => 'Choose a service and confirm';

  @override
  String get uiacd55510 =>
      'Your request is registered. We will notify you when a captain accepts. You can refresh its status.';

  @override
  String get uib3a04740 =>
      'Captain offers are available. Follow your ride here.';

  @override
  String get ui728e6087 => 'Service';

  @override
  String get ui4d7d679f => 'From';

  @override
  String get ui97fe3fe5 => 'To';

  @override
  String get ui8d0a03c3 => 'Estimated fare';

  @override
  String get uib43afc26 => 'Your ride, made simple.';

  @override
  String get uicb822418 => 'Back';

  @override
  String get ui8f7d74ac => 'Confirm';

  @override
  String get ui8a440ee4 => 'Package weight (kg)';

  @override
  String get uif11b8c52 => 'Promo code';

  @override
  String get ui268974da => 'Apply';

  @override
  String get ui18a707e2 => 'Note for captain (optional)';

  @override
  String get ui49acfce8 => 'For example: call on arrival, or use the rear gate';

  @override
  String get uiae2d6005 => 'Payment method';

  @override
  String get uic6e5c7c6 => 'Balance does not cover the full total';

  @override
  String get ui5dbd6c30 => 'Wallet balance, then the rest in cash';

  @override
  String get ui16372d11 => 'No wallet balance';

  @override
  String get ui18c40f92 => 'Cash to pay the captain';

  @override
  String get ui216376e1 => 'Remaining payment';

  @override
  String get uia39f7a83 => 'Confirm and request ride';

  @override
  String get ui5164d8be => 'Payment summary';

  @override
  String get ui68881282 =>
      'Including discount, previous due and wallet payment';

  @override
  String get uid6c3b867 => 'Remaining payment';

  @override
  String get ui8fb9853e => 'Cash to pay the captain';

  @override
  String get ui032bb56d => 'Fully paid from wallet';

  @override
  String get currencyShort => 'EGP';

  @override
  String moneyValue(String amount) {
    return '$amount EGP';
  }

  @override
  String distanceValue(String amount) {
    return '$amount km';
  }

  @override
  String durationValue(String amount) {
    return '$amount min';
  }

  @override
  String promoAppliedValue(String amount) {
    return 'Applied discount: $amount EGP';
  }

  @override
  String previousDueNotice(String reason, String amount) {
    return '$reason: $amount EGP will be added to this ride';
  }

  @override
  String paymentSummary(String method) {
    return 'Payment method: $method';
  }

  @override
  String walletPaymentSummary(String method, String amount) {
    return 'Payment: $method — $amount EGP from wallet';
  }

  @override
  String walletRemaining(String amount) {
    return 'Estimated wallet balance after booking: $amount EGP';
  }

  @override
  String foundPickup(String address) {
    return 'Your pickup: $address';
  }

  @override
  String flowStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String buildingName(String number) {
    return 'Building $number';
  }

  @override
  String areaBuilding(String area, String number) {
    return 'Area $area - building $number';
  }

  @override
  String fromPickup(String address) {
    return 'From: $address';
  }

  @override
  String get account9193bd6a => 'Switch account';

  @override
  String get account7272be04 => 'Captain account';

  @override
  String get accountdebf96d9 => 'Customer account';

  @override
  String get accounta180a470 =>
      'Linking a customer account requires a secure identity review.';

  @override
  String get account3ef541b9 => 'Done';

  @override
  String get account478c486f => 'More';

  @override
  String get account6553a836 => 'Not rated yet';

  @override
  String get account30db229c => 'Help';

  @override
  String get account166aea7d => 'Earnings';

  @override
  String get accountf3683943 => 'My rides';

  @override
  String get accountede87845 => 'Share VETO and earn';

  @override
  String get accounta496e785 => 'High demand areas';

  @override
  String get account654a0663 => 'Profile';

  @override
  String get accountb439a50f => 'Switch to customer';

  @override
  String get account8f2788c0 => 'Quick verification — VETO team';

  @override
  String get account8ce3e0cc => 'Notifications';

  @override
  String get accountc3bb52b7 => 'Customer support';

  @override
  String get accountaa6de5d4 => 'Privacy and terms';

  @override
  String get account24c192cb => 'Request account deletion';

  @override
  String get account5bc457c0 => 'Refresh data';

  @override
  String get account21f47442 => 'Sign out';

  @override
  String get growthcf594384 =>
      'The gift is unavailable now. You can continue using the app.';

  @override
  String get growthafffef98 =>
      'Offer terms could not be loaded. Retry from Invitations.';

  @override
  String get growthcc285252 =>
      'Your choice could not be saved. Check the code and try again.';

  @override
  String get growthedf50f6c => 'Welcome to VETO';

  @override
  String get growth9586813a =>
      'Have an invitation code? Add it now. Campaign terms and budget apply. Incentives and waiting charges are excluded from the discount.';

  @override
  String get growthf132a39e => 'Invitation code';

  @override
  String get growth47d263ad => 'Saving…';

  @override
  String get growth2952dce5 => 'Apply code';

  @override
  String get growtha3238c1d => 'Skip and continue';

  @override
  String get growth46164e2c => 'Review your invitation';

  @override
  String get growth9a30dc2a => 'Cancel';

  @override
  String get growth9bbb0792 => 'Open WhatsApp';

  @override
  String get growthfcf8b93c =>
      'WhatsApp could not be opened. You can copy the link.';

  @override
  String get growthede87845 => 'Share VETO and earn';

  @override
  String get growthb7147d67 => 'Invite a friend and earn';

  @override
  String get growth77ac862f => 'Invitation details could not be loaded';

  @override
  String get growth14d5786f => 'Retry';

  @override
  String get growth574836bc => 'Offers are currently disabled';

  @override
  String get growthc24481f6 => 'Share invitation';

  @override
  String get growthfef8e3c9 => 'Copy link';

  @override
  String get growthf1979292 => 'Ride concerns and review requests';

  @override
  String get growthc5cb135c => 'Car badge / motorcycle card';

  @override
  String get growth965d621f =>
      'Earn EGP 15 after your friend’s first eligible ride is completed and settled. Credit applies only to transport fare and cannot be combined with another offer.';

  @override
  String get growth1b588c8a =>
      'Friend invitation credit is promotional and cannot be withdrawn.';

  @override
  String get growtha3856838 => 'Allow app usage measurement';

  @override
  String get growthe98a92b2 => 'Measurement preference could not be loaded';

  @override
  String get growthb31335b2 =>
      'Optional. No phone number, location, or verification code.';

  @override
  String get growth23af0f62 => 'Measurement preference could not be saved';

  @override
  String get growth3899eb0a => 'Startup sound';

  @override
  String get growth9c2791a1 => 'Preference could not be loaded';

  @override
  String get growthb85f466b => 'Optional short system click. Off by default.';

  @override
  String get growthf15e1487 => 'Sound preference could not be saved';

  @override
  String get growth961fd493 => 'Badge generation is currently disabled';

  @override
  String get growthbff11b26 =>
      'The approved badge template could not be loaded';

  @override
  String get growth75bc722a => 'Invitation badge';

  @override
  String get growthc12b43ff =>
      'Place the badge behind a seat, clear of the driver’s view and airbags. For motorcycles, attach a small card to the delivery bag, clear of handlebars and wheels.';

  @override
  String get growthd0195c3b => 'Scan to download the app';

  @override
  String get growtha660bd6f => 'Print landscape A4 car badge';

  @override
  String get growth50f5b043 => 'Print motorcycle card 8 × 11 cm';

  @override
  String get growthf12097cd =>
      'Print at actual size. Do not use your phone as a badge while driving.';

  @override
  String invitationMessage(String code, String link) {
    return 'Try VETO SANYA 🚗\nInvitation code: $code\nEnter the code during registration to see the offer available to your account.\n$link';
  }

  @override
  String growthInvitations(String value) {
    return 'Invitations: $value';
  }

  @override
  String growthQualifiedFriends(String value) {
    return 'Friends with an eligible completed ride: $value';
  }

  @override
  String growthQualifiedTrips(String value) {
    return 'Eligible rides: $value';
  }

  @override
  String growthDue(String value) {
    return 'Rewards due: EGP $value';
  }

  @override
  String growthPaid(String value) {
    return 'Rewards paid: EGP $value';
  }

  @override
  String growthCredit(String value) {
    return 'Available promotional credit: EGP $value';
  }

  @override
  String growthCode(String value) {
    return 'Invitation code: $value';
  }

  @override
  String growthEventsFailed(String value) {
    return '$value optional measurement events could not be sent. Rides were unaffected.';
  }

  @override
  String get zeroTitle => 'Two hours of zero commission';

  @override
  String get zeroLoadFailed => 'Zero commission reward could not be loaded.';

  @override
  String get zeroActivateFailed =>
      'Activation could not be confirmed. Refresh before retrying; the server stores reward timing.';

  @override
  String get zeroActivate => 'Activate now — timing starts on the server';

  @override
  String get zeroExpired => 'The activation deadline has passed';

  @override
  String get zeroAcceptedPreserved =>
      'The acceptance window has ended; eligible rides keep their exemption';

  @override
  String get zeroNoTripCap => 'No ride count limit';

  @override
  String get zeroNoCostCap => 'No cost limit';

  @override
  String get zeroIndependent =>
      'Covers fare and waiting commission. Incentive and debt rules remain unchanged.';

  @override
  String get zeroRefresh => 'Refresh rewards';

  @override
  String zeroDeadline(String value) {
    return 'Activate before: $value';
  }

  @override
  String zeroServices(String value) {
    return 'Eligible services: $value';
  }

  @override
  String zeroRemaining(String value) {
    return 'Remaining $value';
  }

  @override
  String zeroSaved(String value) {
    return 'Actual commission saved: EGP $value';
  }

  @override
  String zeroTripCap(String value) {
    return 'Completed ride limit: $value';
  }

  @override
  String zeroCostCap(String value) {
    return 'Cost limit: EGP $value. Eligible rides keep their full exemption.';
  }

  @override
  String get live284968d7 => 'This ride is currently unavailable.';

  @override
  String get live182cb52e => 'Ride status refreshed';

  @override
  String get live6ef3859c => 'Ride status could not be refreshed. Try again.';

  @override
  String get liveeed45423 => 'the amount set by administration';

  @override
  String get livefc43d3fe =>
      'You are still searching. Cancellation is free. Any wallet amount held for this ride is refunded once.';

  @override
  String get live47420271 =>
      'You are within the grace period, so cancellation is free. Any held wallet funds are refunded once.';

  @override
  String get live3006aec8 =>
      'Cancellation fees may apply based on captain acceptance time and administration rules. Check the amount due in your account.';

  @override
  String get live6aef022f => 'Cancel ride';

  @override
  String get livecb822418 => 'Back';

  @override
  String get livede0b18e1 => 'Ride cancelled';

  @override
  String get liveac9ac0e6 =>
      'You can request a new ride. Held wallet funds are refunded once according to the cancellation statement.';

  @override
  String get live65d25b44 => 'OK';

  @override
  String get live2f225a03 => 'Captain';

  @override
  String get live6539544e => 'WhatsApp could not be opened.';

  @override
  String get live37ccdeb7 => 'Ride support';

  @override
  String get live99f2c8a6 => 'Current ride';

  @override
  String get livedcf45bf6 => 'Refresh status';

  @override
  String get live9a86a128 => 'The ride could not be loaded';

  @override
  String get live14d5786f => 'Retry';

  @override
  String get live5a6daebf => 'Waiting for captain acceptance';

  @override
  String get live3c6518b4 => 'Searching for a captain';

  @override
  String get live4babb638 =>
      'Searching for available captains eligible for your service.';

  @override
  String get live606af07c => 'Call';

  @override
  String get live5a0374f3 => 'Not provided';

  @override
  String get livea674a023 => 'Ride';

  @override
  String get liveb075cda8 => 'Ride details';

  @override
  String get liveae7ae56d => 'Pickup';

  @override
  String get live8b068efc => 'Destination';

  @override
  String get livedd00b654 => 'Distance';

  @override
  String get livea7947509 => 'Duration';

  @override
  String get live65fc6a0a => 'Customer note for captain';

  @override
  String get live15d8bb61 => 'Chat with captain';

  @override
  String get liveb7d72a98 => 'Captain assigned';

  @override
  String get live2f7a3366 => 'Captain is on the way';

  @override
  String get live0676addf => 'Captain has arrived';

  @override
  String get liveda8838dc => 'Ride in progress';

  @override
  String get livece7c7ba9 => 'Ride completed';

  @override
  String get live8c2ae1f8 => 'Updating ride';

  @override
  String get livebdfe2de5 =>
      'Your captain accepted the ride and is preparing to come to you.';

  @override
  String get live6467fed6 => 'Follow your captain on the map until arrival.';

  @override
  String get live1a58a508 =>
      'Your captain has reached pickup. Please be ready.';

  @override
  String get live340df273 =>
      'Your ride has started. Captain location updates appear on the map.';

  @override
  String get live08e09e69 =>
      'Your ride has ended. Review the final statement and rate your experience.';

  @override
  String get live4a4aa18a =>
      'The ride was cancelled. Check the cancellation statement for any applicable amount.';

  @override
  String get livea7ecc2bc => 'Status refreshes automatically.';

  @override
  String get live89aef3a3 => 'Car';

  @override
  String get live80a51d6a => 'Motorcycle';

  @override
  String get live113cb058 => 'Delivery';

  @override
  String get livec9a1bb1e => 'The phone app could not be opened.';

  @override
  String liveCancellationAfterGrace(String fee) {
    return 'The grace period has ended. Current cancellation compensation of $fee goes to the captain under administration rules. The server checks it again on confirmation.';
  }

  @override
  String liveCancelConfirm(String message) {
    return '$message\n\nContinue and cancel this ride?';
  }

  @override
  String liveSupportMessage(String trip) {
    return 'Hello, I need support with ride $trip.';
  }

  @override
  String liveIncentive(String value) {
    return 'Ride incentive: EGP $value';
  }

  @override
  String growthDiscountTerms(String discounts, String cap) {
    return 'First three eligible ride discounts: $discounts% · Discount cap: EGP $cap';
  }

  @override
  String growthOfferExpiry(String value) {
    return 'Valid until $value, subject to eligible services and campaign budget. Excludes incentives, waiting charges, and prior debts.';
  }

  @override
  String get growthLinkReadFailed =>
      'The link code could not be read automatically. You can enter it manually.';

  @override
  String get home86b9f2f0 => 'Request your ride again?';

  @override
  String get home0708df98 => 'Not now';

  @override
  String get home76509239 => 'Request again';

  @override
  String get homeeefa3156 => 'Finding your city…';

  @override
  String get home80e0d09a => 'Choose pickup on the map';

  @override
  String get home6d6c1e9b => 'Choose pickup on the map for an accurate fare';

  @override
  String get home71bcd653 => 'Finding your current area';

  @override
  String get homea5ba6dc1 => 'Other app services remain available';

  @override
  String get home96a80d01 => 'You can continue and choose your destination';

  @override
  String get home57b420fe => 'Choose pickup to calculate the fare';

  @override
  String get home53f070d4 => 'Choose city';

  @override
  String get home9874ac8e => 'Refresh city';

  @override
  String get home13e32830 =>
      'New offers could not be checked. You can continue booking normally.';

  @override
  String get homeb7147d67 => 'Invite a friend and earn';

  @override
  String get home6397a101 => 'Track VETO Market order';

  @override
  String get home8e0c6845 => 'Waiting for store acceptance';

  @override
  String get home797b2da9 => 'Store accepted the order';

  @override
  String get home8594c09a => 'Your order is being prepared';

  @override
  String get homee08d6fd7 => 'Ready for captain pickup';

  @override
  String get home58387cb4 => 'Captain assigned — open to contact';

  @override
  String get homebaac8162 => 'Captain picked up the order';

  @override
  String get home2f7a3366 => 'Captain is on the way';

  @override
  String get homebae11587 => 'Track order status';

  @override
  String get homeeb4cee6e => 'Add your name in seconds';

  @override
  String get home05fb123d => 'Add your name so we can welcome you personally.';

  @override
  String get home4fabeda0 => 'Enter a name with at least two characters';

  @override
  String get home0bfd0492 => 'Your name could not be saved. Try again.';

  @override
  String get homeb658c871 => 'Let us welcome you by name ✨';

  @override
  String get homed017c069 => 'Enter your name once for a personal welcome.';

  @override
  String get home84e2331e => 'Your name';

  @override
  String get home2bd32fda => 'Enter your name';

  @override
  String get homea49e25ed => 'Save my name';

  @override
  String get profile6db47f1c => 'Your photo could not be uploaded';

  @override
  String get profilec3bb52b7 => 'Customer support';

  @override
  String get profile606af07c => 'Call';

  @override
  String get profile8e10b7d8 => 'Hello, I need help with VETO SANYA';

  @override
  String get profile9193bd6a => 'Switch account';

  @override
  String get profile41e29a2a => 'Personal';

  @override
  String get profile7272be04 => 'Captain account';

  @override
  String get profilee979acbd => 'Register as captain';

  @override
  String get profileb9eaeabe => 'Open captain mode with your account';

  @override
  String get profilebad7739d => 'Apply to join the captain team';

  @override
  String get profile3ef541b9 => 'Done';

  @override
  String get profileafe5d60a => 'My VETO account';

  @override
  String get profile3f3089b7 => 'My account';

  @override
  String get profile6b1fd308 => 'Refresh profile';

  @override
  String get profile4f95f432 => 'New member';

  @override
  String get profile05f99bc8 => 'VETO member';

  @override
  String get profile2df1f491 => 'Profile • Edit photo and details';

  @override
  String get profile89e7f927 => 'Account type';

  @override
  String get profile9092f905 => 'Switch to captain';

  @override
  String get profile30db229c => 'Help';

  @override
  String get profile69cb4d81 => 'Wallet';

  @override
  String get profile92d05589 => 'Activity';

  @override
  String get profile09f41ce6 => 'Account and features';

  @override
  String get profilec8c5d575 => 'My frames and rewards';

  @override
  String get profilebfa6d7fd => 'Your rating, rides, and available frames';

  @override
  String get profile158bcacd => 'Invite a friend and earn EGP 15';

  @override
  String get profileb62e7ee8 =>
      'Separate promotional credit after your friend’s first eligible ride';

  @override
  String get profile8ce3e0cc => 'Notifications';

  @override
  String get profile45d7fc3c => 'Ride and account updates';

  @override
  String get profileed230578 => 'Receive rides with the same account';

  @override
  String get profile1614cb5d => 'Register as captain';

  @override
  String get profileba0e24fa => 'Apply to join the captain team';

  @override
  String get profiled2016401 => 'Quick verification';

  @override
  String get profile72081e80 => 'Verification and WhatsApp requests';

  @override
  String get profile52233a23 => 'Support and security';

  @override
  String get profile5fe46ac6 => 'Suggestion';

  @override
  String get profile615e6b1d => 'Share an idea to improve VETO SANYA';

  @override
  String get profile12506e99 => 'Complaint';

  @override
  String get profileb0500561 => 'Our support team is ready to help';

  @override
  String get profileaa6de5d4 => 'Privacy and terms';

  @override
  String get profile86c46fe1 => 'Policies, your rights, and your data';

  @override
  String get profile24c192cb => 'Request account deletion';

  @override
  String get profile70224a06 =>
      'Request deletion through the official channels';

  @override
  String get profile21f47442 => 'Sign out';

  @override
  String get profileda1d0e35 => 'Sign out safely';

  @override
  String get profile14009384 => 'VETO SANYA • Your journey, made simple';

  @override
  String get wallet30454aef => 'Ride hold refund';

  @override
  String get wallet94d8f009 => 'Cancellation compensation';

  @override
  String get wallet08b4509e => 'Cancellation fee';

  @override
  String get wallet73a173f7 => 'Balance correction';

  @override
  String get wallet7a70ab91 => 'Top-up reward';

  @override
  String get wallet4626aabc => 'Wallet top-up';

  @override
  String get wallet9da2b774 => 'Credit';

  @override
  String get walletdd1bba5b => 'Change from captain';

  @override
  String get walletec9ccd93 => 'Debit';

  @override
  String get walletf11b8c52 => 'Promo code';

  @override
  String get walleta674a023 => 'Ride';

  @override
  String get wallet113d570d => 'Adjustment';

  @override
  String get wallet1cae7479 => 'Commission';

  @override
  String get wallete343e4a4 => 'Penalty';

  @override
  String get walleta94f951d => 'Settlement credit';

  @override
  String get wallete1853a0c => 'Settlement payment';

  @override
  String get wallet6432e51d => 'Incentive';

  @override
  String get wallet40c7d7e2 => 'Wallet balance';

  @override
  String get wallet9b7f8de8 =>
      'Top up securely. Offers and rewards are applied after the transfer is reviewed.';

  @override
  String get wallet6a50382f => 'Top up wallet';

  @override
  String get walletaf7fb819 => 'Transactions';

  @override
  String get walletf0795392 => 'No transactions yet';

  @override
  String get auth4b6a0d56 => 'Enter the code';

  @override
  String get auth94b8b549 => 'The code must contain four digits';

  @override
  String get auth8ba78f82 =>
      'This number is linked to different customer and captain accounts. Contact administration to review the account links.';

  @override
  String get auth877ec1c8 =>
      'Please wait. Administration has not sent the code yet.';

  @override
  String get auth2fb0282a => 'This request expired. Request a new code.';

  @override
  String get authf4eb3c84 => 'Attempt limit reached. Request a new code.';

  @override
  String get auth7cf0e2f5 => 'Incorrect code.';

  @override
  String get auth5063b733 => 'This number is not linked to an active store.';

  @override
  String get auth00d3d260 =>
      'The store account could not be prepared. The server recorded the cause; administration must review the store login service.';

  @override
  String get authc9ff542b =>
      'The account was created, but store access could not be linked. Administration must review the store account link.';

  @override
  String get auth9736c215 =>
      'The code was verified, but a secure session could not be opened. Request a new code and retry.';

  @override
  String get auth7525bff1 => 'Store login failed. Contact administration.';

  @override
  String get authac9e317b =>
      'This request expired. Go back and request verification again.';

  @override
  String get auth7474039f =>
      'Attempt limit reached. Request verification again.';

  @override
  String get authef7a895a => 'This number is not registered as a captain.';

  @override
  String get auth8d4c6591 => 'The captain account is currently inactive.';

  @override
  String get authe1e92bab => 'The captain account is not ready for login.';

  @override
  String get authbf47817e =>
      'The captain account could not be secured. Contact administration.';

  @override
  String get auth095e455e =>
      'Administration must review the captain account details.';

  @override
  String get auth767a6bf3 => 'Captain login failed. Try again.';

  @override
  String get autha18be99f =>
      'This number belongs to a captain. Use the captain login code.';

  @override
  String get auth9ec825fc =>
      'The customer account is inactive. Contact support.';

  @override
  String get auth6c804eff => 'Administration must review the customer account.';

  @override
  String get auth6dd32123 =>
      'The customer account could not be prepared. Try again.';

  @override
  String get authe2341633 => 'The account could not be secured. Try again.';

  @override
  String get auth51953e13 =>
      'The customer profile could not be prepared. Try again.';

  @override
  String get authd7cba707 =>
      'The customer profile could not be linked to the account. Contact administration.';

  @override
  String get authc15acdd8 =>
      'A login session could not be created. Request a new code after administration reviews the issue.';

  @override
  String get authd41a26b6 =>
      'The customer account could not be linked. Contact administration.';

  @override
  String get authe4a12e31 => 'This account is blocked. Contact support.';

  @override
  String get auth517e8c1a => 'Administration must review the account status.';

  @override
  String get authac51cf01 =>
      'Verification is temporarily unavailable. Try later.';

  @override
  String get authf7179060 => 'The code is incorrect or expired.';

  @override
  String get auth51721be4 => 'Login failed. Try again.';

  @override
  String get auth160e784b =>
      'The connection is unavailable. Check your network and retry.';

  @override
  String get auth54d4f443 => 'Administration must update the login service.';

  @override
  String get auth7b3824d7 => 'The login service is not fully configured.';

  @override
  String get auth7513ec76 =>
      'The customer account could not be linked. Contact administration.';

  @override
  String get authd2227474 =>
      'The customer account could not be created. Contact administration.';

  @override
  String get auth010fd34d =>
      'The login session could not be created. Contact administration.';

  @override
  String get auth31654349 => 'This account is blocked. Contact support.';

  @override
  String get auth334c0562 => 'Verification is temporarily unavailable.';

  @override
  String get auth4c5573f4 =>
      'Administration has not configured the support number';

  @override
  String get auth56a1b88a => 'WhatsApp could not be opened';

  @override
  String get auth653fd437 => 'Verification code';

  @override
  String get auth4bf997e8 => 'Please wait';

  @override
  String get authaff91568 =>
      'Your verification code will be sent through WhatsApp after administration reviews your request.';

  @override
  String get authc1717a62 => 'Verify code';

  @override
  String get authec6b1f69 =>
      'Code not received? Contact support through WhatsApp';

  @override
  String get topupfb743f85 =>
      'Top-up service could not be loaded. Please retry.';

  @override
  String get topup120e8520 =>
      'Enter a valid amount or choose the offer amount.';

  @override
  String get topup85a2d105 => 'Choose an available payment method first.';

  @override
  String get topup42c2949d => 'Enter the number you transferred from.';

  @override
  String get topup8c6dd9dd =>
      'Your request was received for review. No balance has been added yet.';

  @override
  String get topupf5d7c7d6 =>
      'The top-up request could not be confirmed. Check its status before retrying.';

  @override
  String get topup4d96fe71 => '✨ Wallet offers';

  @override
  String get topup6a50382f => 'Top up your wallet';

  @override
  String get topup78775dc3 => 'Top up for your next ride';

  @override
  String get topup1eb95ad4 =>
      'Reward terms are shown clearly. Balance is added after transfer verification.';

  @override
  String get topupd2016477 => '✦ Top-up offer';

  @override
  String get topup292f3529 => 'Choose this offer';

  @override
  String get topupf5e67eb7 => 'Available offers';

  @override
  String get topupd27033c9 =>
      'Choose an offer. The reward is shown separately from your transfer.';

  @override
  String get topupc2ef5692 => 'Choose your own top-up amount without a reward';

  @override
  String get topupe0607388 =>
      'Payment methods are not enabled. Administration must add a verified transfer number.';

  @override
  String get topup1768325b => '01 / Choose amount';

  @override
  String get topupb7231cbd => 'Selected offer';

  @override
  String get topup1223dbd6 =>
      'The offer amount is fixed to protect your reward. Go back to choose another offer.';

  @override
  String get topupac3d43ad => 'Transfer amount in EGP';

  @override
  String get topup29bc32d5 => 'Required transfer amount';

  @override
  String get topup346be366 => 'Offer reward';

  @override
  String get topup663ba8dc => 'Total added after approval';

  @override
  String get topup43f4b708 => '02 / Choose payment method';

  @override
  String get topupb14b98c9 =>
      'No payment method is currently active. Do not transfer until administration adds one.';

  @override
  String get topupd85df9ec => 'Transfer details appear in the next step';

  @override
  String get topup1d09cf88 => 'Continue to transfer instructions';

  @override
  String get topup114df589 => '03 / Transfer details';

  @override
  String get topup08e262ba => 'Copy transfer number';

  @override
  String get topupa914d518 => 'Transfer details copied';

  @override
  String get topup58890d41 => 'Transfer instructions';

  @override
  String get topup9f05f6f1 =>
      'Check the transfer number and amount before sending.';

  @override
  String get topup9296abef => 'Sender number *';

  @override
  String get topup9895aa5d => 'Sender wallet or account number';

  @override
  String get topup18f7532a => 'Transaction reference (if available)';

  @override
  String get topupceedefc4 => 'Reference shown on your transfer receipt';

  @override
  String get topup218b7624 => '🛡️ Protecting your balance';

  @override
  String get topupd6c8e2d2 =>
      'Submitting a request does not add balance. Your payment and reward are credited once after an authorized employee verifies and approves the transfer.';

  @override
  String get topup838c527e => 'Submitting request…';

  @override
  String get topup2bc6aebc => 'Submit top-up request';

  @override
  String get topup4a807954 => 'Approved • Balance credited';

  @override
  String get topup5d969a71 => 'Rejected';

  @override
  String get topup8aac5fac => 'Under review';

  @override
  String get topupd44d4435 => 'Unknown';

  @override
  String get topup90aa4d47 => '04 / Track top-up request';

  @override
  String get topup007c4718 =>
      'We received your request and are checking the transfer. Status updates after review.';

  @override
  String get topupc769438a =>
      'Your transfer was verified and your wallet credited.';

  @override
  String get topupca711e4a =>
      'Your request was not approved. Review the rejection reason with support before a new attempt.';

  @override
  String get topupd84c4984 => 'Reference';

  @override
  String get topup558ab445 => 'Amount paid';

  @override
  String get topup36bba20f => 'Reward';

  @override
  String get topupf3471840 => 'Payment method';

  @override
  String get topup82e926cb => 'Received at';

  @override
  String get topupc875c278 => 'Refresh request status';

  @override
  String get topup066febb5 => 'View all requests';

  @override
  String get topupe5f00560 => 'Top-up request history';

  @override
  String get topup102df0aa => 'You have not submitted a top-up request yet.';

  @override
  String get topup152d5282 => 'My wallet';

  @override
  String get topup45513074 => 'Top-up history';

  @override
  String get topupf3b40143 => 'Back to offers';

  @override
  String get topupcb822418 => 'Back';

  @override
  String get captain278d3e8e =>
      'Update your location to receive requests. Check GPS and connectivity.';

  @override
  String get captainf6174ae5 => 'The dashboard could not be loaded. Retry.';

  @override
  String get captain5d90693a =>
      'Wait for the current ride action to be confirmed, then retry.';

  @override
  String get captain0e3338be =>
      'Allow location access to start receiving rides.';

  @override
  String get captain13e4b9b7 =>
      'Your location could not be confirmed. Check permission and connectivity, then retry.';

  @override
  String get captain199848b2 =>
      'You reached the debt limit. Open your payment statement; availability returns after an approved payment reduces debt below the limit.';

  @override
  String get captain9c360bcd =>
      'Complete your current ride before going offline.';

  @override
  String get captain37cdd354 =>
      'Your captain account is not approved. Contact support.';

  @override
  String get captain0028fab8 =>
      'Your captain account is temporarily suspended. Check app notices or contact support.';

  @override
  String get captain20d90f0e =>
      'Update your location to receive rides. Check GPS and connectivity.';

  @override
  String get captaineaa58c01 =>
      'Location services are off. Enable them in phone settings.';

  @override
  String get captainae5e5078 =>
      'Allow location access while using the app in its settings.';

  @override
  String get captainb91e4e01 =>
      'Location is enabled, but no fix is available yet. Try near a window or outdoors, then go online.';

  @override
  String get captain4d71e045 =>
      'Your device location could not be read. Check permission and retry.';

  @override
  String get captain0c8c1ed6 =>
      'Your session on this device has ended. Sign out and log in again.';

  @override
  String get captain6779d8a9 =>
      'The server rejected your status update. Log in again; contact support if the issue persists.';

  @override
  String get captain1c8a49fe =>
      'Your captain account could not be verified. Log in again.';

  @override
  String get captain96de460e =>
      'Your online status could not be saved on the server. Retry.';

  @override
  String get captain07ec3438 =>
      'Your location was found, but could not be sent to the server. Check connectivity and go online again.';

  @override
  String get captain4d8aa1e0 =>
      'Purchase instructions appear before request acceptance.';

  @override
  String get captain4bd12227 =>
      'You cannot accept a request while on an active ride';

  @override
  String get captain961fe263 => 'This request is unavailable';

  @override
  String get captaind292c0f8 => 'This request is no longer available';

  @override
  String get captain61f278b9 => 'Ride accepted';

  @override
  String get captain6aad32b8 => 'Another captain accepted this ride first';

  @override
  String get captaine28fe29b => 'You are currently on another ride';

  @override
  String get captain817dceb0 =>
      'The request could not be accepted. It may no longer be available; refresh and retry.';

  @override
  String get captain3e4011c0 => 'The request could not be declined';

  @override
  String get captain9947a71a => 'This step is unavailable';

  @override
  String get captain82963d4d => 'Unavailable';

  @override
  String get captain583a75cf => 'Detailed ride statement';

  @override
  String get captainfee7f899 =>
      'Server-approved amount to collect from the customer';

  @override
  String get captaind922438f =>
      'After wallet payments, discounts, and prior amounts due, as confirmed by the server';

  @override
  String get captain7f29d28a => 'Base fare';

  @override
  String get captaine8ea6cc8 => 'Waiting charges';

  @override
  String get captainb593a645 => 'Discount';

  @override
  String get captain48f62d04 => 'Full incentive';

  @override
  String get captaind8148f15 => 'Previous company amount due';

  @override
  String get captaindf9cee25 => 'Customer statement total';

  @override
  String get captainccfb9ede => 'Paid from customer wallet';

  @override
  String get captain8b296d76 => 'Collect cash from customer';

  @override
  String get captain3bdc9404 => 'Company commission';

  @override
  String get captain79fe765a => 'Company incentive share';

  @override
  String get captainc3b788c0 => 'Your incentive share';

  @override
  String get captain986f250b => 'Your net entitlement';

  @override
  String get captaind3aa4069 => 'Settlement account change';

  @override
  String get captain233aea82 => 'Settlement balance after ride';

  @override
  String get captain3ef541b9 => 'Done';

  @override
  String get captainaa0eba0d =>
      'The statement could not be shown. Pull to refresh and retry.';

  @override
  String get captaindb6c6f4e => 'The phone app could not be opened';

  @override
  String get captain2b50d9f0 =>
      'Administration has not configured support details';

  @override
  String get captainc3bb52b7 => 'Customer support';

  @override
  String get captainebfead75 => 'Call customer support';

  @override
  String get captain56a1b88a => 'WhatsApp could not be opened';

  @override
  String get captain14d5786f => 'Retry';

  @override
  String get captainbfcf4830 => 'Home';

  @override
  String get captainf3683943 => 'My rides';

  @override
  String get captain166aea7d => 'Earnings';

  @override
  String get captain62d6fd3d => 'News';

  @override
  String get captain478c486f => 'More';

  @override
  String get captain00eab31f => 'Refresh';

  @override
  String get captain2443fd0d =>
      'Ride offers could not be synchronized. Refresh and check connectivity.';

  @override
  String get captainee9201f4 => 'New ride request';

  @override
  String get captain99f2c8a6 => 'Current ride';

  @override
  String get captaind6004d47 => 'Captain offers and rewards';

  @override
  String get captain4abac2da => 'VETO Market assignment';

  @override
  String get captaindee9712a => 'Today and account details';

  @override
  String get captain33e9156d => 'Today’s summary — Cairo time';

  @override
  String get captainb13e131c => 'Today’s ride count';

  @override
  String get captain4c103c55 => 'Today’s income (net rides)';

  @override
  String get captainf8e8dfb6 =>
      'Today’s summary could not be refreshed. Pull to retry.';

  @override
  String get captain80098418 => 'Rating';

  @override
  String get captainfcd34918 => 'Captain app';

  @override
  String get captain8ce3e0cc => 'Notifications';

  @override
  String get captain8448690a => 'Confirming status…';

  @override
  String get captain7b3b2ab3 => 'Go offline';

  @override
  String get captainb074b07c => 'Go online';

  @override
  String get captain3c02a45d => 'Store order';

  @override
  String get captainbef9383c =>
      'This assignment was allocated automatically. No acceptance or rejection is required.';

  @override
  String get captainf86852a4 => 'Track assignment and go to store';

  @override
  String get captaind83efdf5 =>
      'Review rides, VETO Market orders, and their statements.';

  @override
  String get captain4bf40b6a =>
      'Market history could not be loaded. Refresh or contact support.';

  @override
  String get captainaf4b3178 => 'VETO Market orders';

  @override
  String get captaincf83fb17 => 'No previous rides';

  @override
  String get captainda3de6e3 => 'Completed rides appear here.';

  @override
  String get captain2823f378 => 'Earnings and settlements';

  @override
  String get pendingDraftUnavailable =>
      'The pending request on this device could not be read. Retry before sending a new request.';

  @override
  String get suggestionConfirmedStorage =>
      'Your suggestion reached review, but the local retry receipt could not be cleared. Retry to close without submitting again.';

  @override
  String get loading => 'Loading…';

  @override
  String get captainReferralCode => 'Captain referral code';

  @override
  String get captainCodeLoadFailed => 'Your code could not be loaded. Retry.';

  @override
  String get cancelServiceUnavailable =>
      'Cancellation is unavailable on this server version. Your request was not confirmed as cancelled; contact support.';

  @override
  String get cancelAcceptanceRace =>
      'A captain accepted while you were cancelling. Review the updated ride status.';

  @override
  String get cancelFinancialGuard =>
      'The server stopped cancellation to protect your balance because of a financial conflict. Send the ride ID to support.';

  @override
  String get cancelSessionUnavailable =>
      'Your session could not be verified. Log in and review request status.';

  @override
  String get cancelUnconfirmed =>
      'The server has not confirmed cancellation. Refresh request status before retrying, and reconnect if offline.';

  @override
  String get bookingCreatedDistributionFailed =>
      'Your request was created, but delivery of captain offers was not confirmed. Refresh its status; do not create another request.';

  @override
  String get bookingCreateUnconfirmed =>
      'Request creation was not confirmed. Refresh your rides before retrying to avoid a duplicate request.';

  @override
  String get bookingCreateRejected =>
      'The server rejected this request. Review the address, price and payment method, or contact support if the problem persists.';

  @override
  String get bookingCoverageUnavailable =>
      'Booking is unavailable in this city. You can submit an address suggestion for review, but cannot book outside service coverage.';

  @override
  String get bookingSessionUnavailable =>
      'Your account session could not be verified. Log in and check your rides before requesting again.';

  @override
  String get bookingPromoExpired =>
      'This promo code expired. Review the discount before requesting.';

  @override
  String get bookingPromoTotalLimit => 'This code reached its usage limit.';

  @override
  String get bookingPromoPeopleLimit =>
      'This offer reached its customer limit.';

  @override
  String get bookingPromoUserLimit =>
      'You reached your usage limit for this code.';

  @override
  String get bookingPromoInactive => 'This promo code is inactive.';

  @override
  String get bookingPromoNotStarted => 'This offer has not started.';

  @override
  String get bookingPromoInvalid => 'This promo code was not found.';

  @override
  String get bookingPromoReview => 'Administration must review this code.';

  @override
  String get bookingStatusUnavailable =>
      'Ride status could not be confirmed by the server. Refresh again or contact support; do not create a second request.';

  @override
  String get bookingStillSearching =>
      'Status refreshed: still searching for a captain.';

  @override
  String get bookingRequestCancelled => 'Your ride request was cancelled.';

  @override
  String get captainCodePending =>
      'Your referral code is awaiting administration setup';

  @override
  String get captainCodeCapacityHelp =>
      'Current code capacity is full. Your account, rides and accounting remain available; no unapproved code or QR will be shown.';

  @override
  String get registrationb214d2cc => 'Application status updated';

  @override
  String get registration9496b651 =>
      'Your application could not be loaded. Check the connection and retry.';

  @override
  String get registration3cfb232e =>
      'Your birth date does not match the national ID. Review and correct your details.';

  @override
  String get registration3f4f4ac8 =>
      'A detail is missing or invalid. Review your personal and vehicle details.';

  @override
  String get registration0e85de07 =>
      'Your session expired. Log in to VETO before submitting.';

  @override
  String get registration8574ec84 =>
      'Your account has a different role. Contact VETO administration to review the application without changing your account.';

  @override
  String get registrationad110af9 =>
      'An image is invalid. Use JPG, PNG or WebP smaller than 8 MB.';

  @override
  String get registration6d21b4e2 =>
      'This application has already been reviewed. Contact administration to change details.';

  @override
  String get registrationb23d2d69 =>
      'Application images could not be saved. Retry, or contact support if the problem persists.';

  @override
  String get registrationb4eecfa9 =>
      'Captain applications are currently unavailable. Contact support.';

  @override
  String get registration6d45fa59 =>
      'Service permissions prevented saving your application. Contact VETO administration.';

  @override
  String get registration6a52abd7 =>
      'The connection was interrupted during submission. Reconnect and check your application status before retrying.';

  @override
  String get registration41d01feb =>
      'Image upload failed. Check your connection and retry.';

  @override
  String get registration53b824de =>
      'Submission was not confirmed. Check application status before retrying, or contact support.';

  @override
  String get registration3659b0f0 =>
      'Make sure the image is clear and all edges are visible before uploading.';

  @override
  String get registrationb99f84a8 => 'Choose again';

  @override
  String get registration09a46335 => 'Use image';

  @override
  String get registration5460351a =>
      'Your national ID and birth date do not match. Check the first seven ID digits and select the correct birth date.';

  @override
  String get registration9709cc61 =>
      'Some images are missing. Add all required images first.';

  @override
  String get registration93a7a9fd =>
      'Your application was received, but the team code was not saved. Review it with support.';

  @override
  String get registration217825d5 =>
      'Your application was received. The VETO team will review it.';

  @override
  String get registrationd5a02f88 => 'This field is required';

  @override
  String get registrationcd844480 => 'Enter your 14-digit national ID';

  @override
  String get registration3190ac91 => 'Enter a valid Egyptian mobile number';

  @override
  String get registration056e90e2 => 'Enter a valid manufacture year';

  @override
  String get registration50f73ca9 => 'Enter your full name';

  @override
  String get registrationb44d35b0 => 'Join VETO captains';

  @override
  String get registration71763395 =>
      'Enter your details, photograph your documents and submit your application. The VETO team will review it and contact you.';

  @override
  String get registrationb5e7acfe => 'Your Egyptian mobile number';

  @override
  String get registration6c2ab9bd => 'Full name';

  @override
  String get registration6541a8c6 => 'National ID';

  @override
  String get registration2625e95c => 'Team code (optional)';

  @override
  String get registration3d9e6c97 => 'Check the team code';

  @override
  String get registration33646453 => 'Birth date';

  @override
  String get registration6f667536 => 'You must be at least 18';

  @override
  String get registration39f0be0f => 'Operating area';

  @override
  String get registration491712d6 => 'Full address';

  @override
  String get registration9d55adc6 => 'Vehicle type';

  @override
  String get registration89aef3a3 => 'Car';

  @override
  String get registration80a51d6a => 'Motorcycle';

  @override
  String get registration0adf93a2 => 'Make';

  @override
  String get registrationc3e10fad => 'Model';

  @override
  String get registrationae42906b => 'Manufacture year';

  @override
  String get registration041b469d => 'Colour';

  @override
  String get registration67fa5912 => 'Plate number';

  @override
  String get registration427f9e30 =>
      'Good lighting • no glare • all edges visible\nVehicle registration is required for cars and motorcycles.';

  @override
  String get registratione52577dc => '✓ Image stored privately';

  @override
  String get registration33b4d832 => '✓ Image ready to submit';

  @override
  String get registrationb0014815 => 'Take photo';

  @override
  String get registrationa3f9bb7c => 'Replace image';

  @override
  String get registration3a375696 => 'Choose image';

  @override
  String get registration0b2cbdfb => 'Review your details before submitting';

  @override
  String get registration3a64c036 =>
      'Make sure your details and images are clear and correct, then submit to the VETO team. Keep the original documents for review.';

  @override
  String get registration35516879 => 'Submit for review';

  @override
  String get registration12e27be4 => 'Initial review completed';

  @override
  String get registrationc7dac90b =>
      'You were approved. You can sign in to your captain account as usual.';

  @override
  String get registration6a4555f7 =>
      'Your status will be updated here after review.';

  @override
  String get registration541ca893 =>
      'Your application passed initial review. The VETO team will contact you to complete onboarding.';

  @override
  String get registration2a0486aa => 'You can follow review team notes here.';

  @override
  String get registrationa9e9d067 => 'Back';

  @override
  String get registration27ae3a38 => 'Select your birth date';

  @override
  String get registration7b27fbaf => 'Complete all documents';

  @override
  String get registration322b7b61 => 'Continue';

  @override
  String get applicationPortrait => 'Portrait';

  @override
  String get applicationIdFront => 'National ID • front';

  @override
  String get applicationIdBack => 'National ID • back';

  @override
  String get applicationLicenseFront => 'Driving licence • front';

  @override
  String get applicationLicenseBack => 'Driving licence • back';

  @override
  String get applicationVehicleFront => 'Vehicle registration • front';

  @override
  String get applicationVehicleBack => 'Vehicle registration • back';

  @override
  String get applicationPending => 'Under review';

  @override
  String get applicationNeedsInfo => 'More information required';

  @override
  String get applicationApproved => 'Approved';

  @override
  String get applicationRejected => 'Rejected';

  @override
  String get applicationPersonalStep => 'Personal details';

  @override
  String get applicationVehicleStep => 'Vehicle details';

  @override
  String get applicationDocumentsStep => 'Document images';

  @override
  String get applicationReviewStep => 'Review and submit';

  @override
  String applicationStep(int step, String label) {
    return 'Step $step of 4 • $label';
  }

  @override
  String applicationDocumentCount(int count) {
    return 'Documents: $count / 7';
  }

  @override
  String get presencecbc96ded => 'Offline';

  @override
  String get presencee6302b21 => 'Updating connection and location';

  @override
  String get presencea781f074 => 'Online and ready for rides';

  @override
  String get presence0aeaba38 => 'Busy with a ride';

  @override
  String get presence05691d14 => 'Connection interrupted';

  @override
  String get presencee28d58d1 => 'Account unavailable';

  @override
  String get presencec81ed735 =>
      'Start when you are ready. Your location is checked before receiving requests.';

  @override
  String get presencee267108e => 'Confirming your status with the server…';

  @override
  String get presence6d021561 =>
      'You will be alerted by sound and vibration when a suitable offer arrives.';

  @override
  String get presence2dbd1bcf =>
      'Complete your current task. The server checks whether your availability can change.';

  @override
  String get presence2038f1aa =>
      'Reconnecting automatically. Your receiving status has not yet been confirmed.';

  @override
  String get presence94d187fa =>
      'Review approval and settlement status, or contact support.';

  @override
  String get presence7b43f77f => 'Confirming';

  @override
  String get presence7b3b2ab3 => 'Stop receiving rides';

  @override
  String get presence52edad40 => 'Start receiving rides';

  @override
  String get presenceecaefa5c => 'Offer expired';

  @override
  String captainOfferSeconds(int seconds) {
    return '$seconds seconds left to accept';
  }

  @override
  String get chatTitle => 'Ride chat';

  @override
  String get chatCaptain => 'Captain';

  @override
  String get chatCustomer => 'Customer';

  @override
  String get chatNotReady => 'Chat opens after a captain accepts the ride.';

  @override
  String get chatParticipantOnly =>
      'Chat is available only to this ride’s customer and captain.';

  @override
  String get chatLoadFailed =>
      'Messages could not be loaded. Check your connection and retry.';

  @override
  String get chatSendUnconfirmed =>
      'Message delivery was not confirmed. Check the chat, then retry the same message.';

  @override
  String get chatEmpty =>
      'Start a conversation with the other ride participant';

  @override
  String get chatYou => 'You';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatCompose => 'Write a message…';

  @override
  String get chatQuickReplies => 'Quick replies · tap to send';

  @override
  String get chatRateLimited =>
      'Messages were sent too quickly. Wait a moment before retrying.';

  @override
  String get chatRequestConflict =>
      'The server detected a message request conflict. Check the chat and contact support if it persists.';

  @override
  String get chatInvalidMessage =>
      'Enter a message of no more than 1,000 characters.';

  @override
  String get chatSessionUnavailable =>
      'Your session could not be verified. Log in before sending a message.';

  @override
  String get replyCustomerWaiting => 'Hello, I am waiting at the pickup point.';

  @override
  String get replyCustomerEta =>
      'Could you let me know your estimated arrival time?';

  @override
  String get replyCustomerGate => 'I am at the gate now.';

  @override
  String get replyCustomerCall => 'Could you call me when you arrive?';

  @override
  String get replyCustomerReady => 'Thank you, I will be ready.';

  @override
  String get replyCaptainEnRoute => 'Hello, I am on my way to you.';

  @override
  String get replyCaptainArrived =>
      'I have arrived at the pickup point and am waiting for you.';

  @override
  String get replyCaptainMeeting => 'Could you confirm the meeting point?';

  @override
  String get replyCaptainLandmark => 'Could you share a nearby landmark?';

  @override
  String get replyCaptainUpdate =>
      'Thank you, I will let you know when I arrive.';

  @override
  String get receiptf1d6d15f => 'Completed';

  @override
  String get receiptd87ae61b => 'Cancelled';

  @override
  String get receiptc74d3b21 => 'Searching';

  @override
  String get receipt30d5d6b5 => 'Accepted';

  @override
  String get receipt2de6d001 => 'Captain on the way';

  @override
  String get receipt39ac9d30 => 'Captain arrived';

  @override
  String get receiptc20f27ab => 'In progress';

  @override
  String get receipt42816de2 => 'VETO Car';

  @override
  String get receiptf8748198 => 'VETO Motorcycle';

  @override
  String get receiptccd99512 => 'VETO Package';

  @override
  String get receiptc99f71b7 => 'VETO ride';

  @override
  String get receiptdadf5afd => 'No captain was assigned to this ride';

  @override
  String get receipt2f225a03 => 'Captain';

  @override
  String get receiptc634600a => 'Your captain';

  @override
  String get receipte12a8659 => 'Ride details';

  @override
  String get receipt4d7d679f => 'From';

  @override
  String get receipt97fe3fe5 => 'To';

  @override
  String get receipt4fe4aa51 => 'Captain details could not be refreshed';

  @override
  String get receipt17d786d8 => 'Invoice';

  @override
  String get receipt7f29d28a => 'Base fare';

  @override
  String get receipt4d1a2a15 => 'Waiting';

  @override
  String get receipt6432e51d => 'Incentive';

  @override
  String get receiptec9ccd93 => 'Discount';

  @override
  String get receiptf28e3f71 => 'Previous amount due';

  @override
  String get receiptc5496762 => 'Ride total';

  @override
  String get receipta455b08a => 'Not yet confirmed';

  @override
  String get receipt48c3380c => 'From wallet';

  @override
  String get receipt1881ccb3 => 'Cash';

  @override
  String receiptDistance(String value) {
    return '$value km';
  }

  @override
  String receiptMinutes(String value) {
    return '$value min';
  }

  @override
  String receiptCompletedAt(String value) {
    return 'Completed $value';
  }

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationReadAll => 'Mark all read';

  @override
  String get notificationEmpty => 'No notifications yet';

  @override
  String get notificationLoadFailed =>
      'Notifications could not be loaded. Tap to retry.';

  @override
  String get notificationReadFailed =>
      'This notification could not be marked as read. Please retry.';

  @override
  String get notificationUpdateFailed => 'Notifications could not be updated';

  @override
  String get captainRide182cb52e => 'Ride status refreshed';

  @override
  String get captainRide0f653eb8 => 'This ride could not be found.';

  @override
  String get captainRide3acc32e9 =>
      'Ride status could not be verified. Refresh or contact support.';

  @override
  String get captainRide5332028e => 'You are now heading to the customer.';

  @override
  String get captainRide73187c4e => 'Your arrival has been recorded.';

  @override
  String get captainRide3ab5268d => 'The ride has started.';

  @override
  String get captainRided8d96922 => 'Ride status updated.';

  @override
  String get captainRidea042411e => 'Customer';

  @override
  String get captainRide9947a71a =>
      'This action is unavailable in the current ride state.';

  @override
  String get captainRide3c0f919c =>
      'Cancellation is available only before starting the ride.';

  @override
  String get captainRidef20a786e =>
      'Cancellation eligibility could not be verified. Please retry.';

  @override
  String get captainRidebe27c947 => 'Confirm ride cancellation';

  @override
  String get captainRidefd11f805 =>
      'No compensation is currently due. Eligibility is checked again when you confirm.';

  @override
  String get captainRidecb822418 => 'Back';

  @override
  String get captainRideadfc99d3 => 'Confirm cancellation';

  @override
  String get captainRide82963d4d => 'Unavailable';

  @override
  String get captainRide54940fb7 => 'Ride invoice';

  @override
  String get captainRide18b3b709 =>
      'Collection amount comes from the server invoice. Existing accounting and settlements apply.';

  @override
  String get captainRide7f29d28a => 'Base fare';

  @override
  String get captainRidee8ea6cc8 => 'Waiting charges';

  @override
  String get captainRideb593a645 => 'Discount';

  @override
  String get captainRide3eab5144 => 'Incentive';

  @override
  String get captainRide500e1d79 => 'Previous amount collected for the company';

  @override
  String get captainRidec5496762 => 'Ride total';

  @override
  String get captainRideb245e20d => 'From customer wallet';

  @override
  String get captainRide6b6e59d4 => 'Cash to collect from customer';

  @override
  String get captainRide53f0a84e => 'Company ride commission';

  @override
  String get captainRide79fe765a => 'Company incentive share';

  @override
  String get captainRide4bbacf57 => 'Your incentive share';

  @override
  String get captainRide9c8ac33a => 'Your net ride entitlement';

  @override
  String get captainRide493a9f67 => 'Settlement wallet change';

  @override
  String get captainRide233aea82 => 'Settlement balance after ride';

  @override
  String get captainRide3ef541b9 => 'Done';

  @override
  String get captainRide9af289d1 => 'Invoice could not be loaded.';

  @override
  String get captainRide6ff5cf85 => 'Amount to collect now';

  @override
  String get captainRideaab7cc3e => 'Amount unavailable';

  @override
  String get captainRide4bbd31a2 =>
      'The server collection amount is unavailable. Refresh the invoice or contact support before collecting payment.';

  @override
  String get captainRideba6f0140 =>
      'Server-approved amount after wallet payment, discounts and any previous amount due.';

  @override
  String get captainRide0b915e74 =>
      'Navigation is unavailable in this ride state. Refresh the status.';

  @override
  String get captainRide5b455cbb =>
      'Exact destination is unavailable. Ask the customer to confirm the address.';

  @override
  String get captainRide87bf7175 =>
      'Exact pickup is unavailable. Contact the customer to confirm it.';

  @override
  String get captainRide765e075b =>
      'Maps could not be opened. Check that a map app or browser is available.';

  @override
  String get captainRide94920016 =>
      'Directions could not be opened. Please retry or contact support.';

  @override
  String get captainRide186db0ab =>
      'WhatsApp could not be opened. Contact support from the menu.';

  @override
  String get captainRidedc09f493 =>
      'The support number has not been configured by an administrator.';

  @override
  String get captainRidef034b7ea =>
      'Support could not be opened. Please retry.';

  @override
  String get captainRide0c1c76d8 => 'Ride assigned';

  @override
  String get captainRide7a8d87be => 'Heading to customer';

  @override
  String get captainRide36e931f5 => 'Arrived at pickup';

  @override
  String get captainRidea6fa5196 => 'Ride in progress';

  @override
  String get captainRidece7c7ba9 => 'Ride completed';

  @override
  String get captainRidede0b18e1 => 'Ride cancelled';

  @override
  String get captainRide6a95aeca => 'Refresh ride';

  @override
  String get captainRide3010a9b6 => 'Head to customer';

  @override
  String get captainRide058c0950 => 'Mark arrival';

  @override
  String get captainRide2cb6f5f1 => 'Start ride';

  @override
  String get captainRide11c70484 => 'Complete ride';

  @override
  String get captainRide9a86a128 => 'Ride could not be loaded.';

  @override
  String get captainRide8bbee7af => 'Try again';

  @override
  String get captainRide97044b5c => 'Back to requests';

  @override
  String get captainRidedcf45bf6 => 'Refresh status';

  @override
  String get captainRidef7776e80 =>
      'Complete or cancel this ride before leaving. Support and chat remain available.';

  @override
  String get captainRide1c184d79 =>
      'This ride is no longer active. You can return to receive new requests.';

  @override
  String get captainRidec99f7794 => 'Back to home';

  @override
  String get captainRide606af07c => 'Call';

  @override
  String get captainRide287b4011 => 'Ride support';

  @override
  String get captainRideae7ae56d => 'Pickup';

  @override
  String get captainRide8b068efc => 'Destination';

  @override
  String get captainRide3c2c2a12 => 'Current stage: heading to destination';

  @override
  String get captainRide28582b4d => 'Current stage: heading to customer';

  @override
  String get captainRidef73184e0 => 'Navigate to destination';

  @override
  String get captainRide7b2fdccc => 'Navigate to pickup';

  @override
  String get captainRidede501d19 => 'Customer waiting time';

  @override
  String get captainRidef6c538ef =>
      'Waiting charges and free minutes follow the administrator pricing rules. The final amount is confirmed in the invoice.';

  @override
  String get captainRide6aef022f => 'Cancel ride';

  @override
  String get captainRide69ca2e6b => 'Assigned';

  @override
  String get captainRide7e5dbf26 => 'To pickup';

  @override
  String get captainRideceb508b1 => 'Arrived';

  @override
  String get captainRidedaa86941 => 'Ride';

  @override
  String get captainRide3398d2be => 'Completed';

  @override
  String captainCancellationFee(String amount) {
    return 'Current cancellation compensation: EGP $amount, deducted from your balance and credited to the customer. Checked again at confirmation.';
  }

  @override
  String captainSupportRide(String id) {
    return 'Hello, I need support during ride $id.';
  }

  @override
  String captainExtraRequests(String value) {
    return 'Extra requests: $value';
  }

  @override
  String captainCustomerNote(String value) {
    return 'Customer note: $value';
  }

  @override
  String captainWaitingPolicy(String minutes, String rate) {
    return 'First $minutes minutes are free, then EGP $rate per minute under administrator pricing. The final amount appears in the invoice.';
  }

  @override
  String get financialCard82963d4d => 'Unavailable';

  @override
  String get financialCarde62437f7 =>
      'Final amounts cannot be confirmed until the receipt is loaded.';

  @override
  String get financialCard5164d8be => 'Final receipt';

  @override
  String get financialCard02d58fca =>
      'Available after completion and financial settlement';

  @override
  String get financialCard8b296d76 => 'Collect cash from customer';

  @override
  String get financialCarda98cf68f => 'Cash remaining for captain';

  @override
  String get financialCardc5496762 => 'Ride total';

  @override
  String get financialCard4dcfdfe9 => 'Paid from wallet';

  @override
  String get financialCard3eab5144 => 'Incentive';

  @override
  String get financialCarde8ea6cc8 => 'Waiting charges';

  @override
  String get financialCardcfea168e => 'Previous amount due included';

  @override
  String get financialCardb593a645 => 'Discount';

  @override
  String get financialCard10217aa6 => 'Change transferred to customer wallet';

  @override
  String get financialCard3bdc9404 => 'Company commission';

  @override
  String get financialCardc3b788c0 => 'Your incentive share';

  @override
  String get financialCard986f250b => 'Your net entitlement';

  @override
  String get financialCardf22ebe52 =>
      'The server collection amount is unavailable. Open the invoice or contact support before collecting payment.';

  @override
  String get financialCardf9ba759e =>
      'Wallet payment is already deducted. Collect only the cash amount shown above.';

  @override
  String get financialCard16361e3f =>
      'Collect only the cash amount shown above.';

  @override
  String get financialCard6392399b => 'Cancellation receipt';

  @override
  String get financialCardef59f590 =>
      'The receipt could not be loaded. Refund status and amount are unconfirmed.';

  @override
  String get financialCard95d3accb => 'Wallet refund';

  @override
  String get financialCardb4549ee9 =>
      'Cancellation compensation after grace period';

  @override
  String get financialCard1da6648d =>
      'This receipt shows recorded transactions and does not collect or refund money.';

  @override
  String get rideLoadingDetails => 'Loading your ride details…';

  @override
  String get captainHomea9f18daf =>
      'Amounts are read from the server and cannot be changed on this phone.';

  @override
  String get captainHomed704e9bc => 'Net earnings';

  @override
  String get captainHomecf1aadab => 'Current settlement balance';

  @override
  String get captainHome227f09b8 =>
      'A positive balance is due to you; a negative balance is due to the company. Ride earnings remain separate from store accounts.';

  @override
  String get captainHomeed440205 => 'Recent transactions';

  @override
  String get captainHome96dede8e => 'No transactions yet';

  @override
  String get captainHome2f8aa27c =>
      'Earnings, commissions and settlements will appear here.';

  @override
  String get captainHome3fcf112b => 'Transaction';

  @override
  String get captainHomeaf9189ea =>
      'Finish the ride and go offline before opening customer mode.';

  @override
  String get captainHome3dc57bb8 =>
      'The customer account is not linked to this identity. Contact support for review.';

  @override
  String get captainHome31e75c6d => 'Finish your ride and go offline first.';

  @override
  String get captainHomeffc8991e =>
      'Complete or cancel the active ride before signing out.';

  @override
  String get captainHome59807bee => 'Captain details';

  @override
  String get captainHome52ab0984 => 'Name';

  @override
  String get captainHome94b59a51 => 'Phone';

  @override
  String get captainHome4309e001 => 'Vehicle';

  @override
  String get captainHome936290d6 => 'License plate';

  @override
  String get captainHome9643e947 => 'Captain';

  @override
  String get captainHome9d6ea6f4 => 'Welcome to your dashboard';

  @override
  String get captainHome5bc457c0 => 'Refresh';

  @override
  String get captainHome85c00f9b => 'Your rating';

  @override
  String get captainHome19e6729c => 'Completed rides';

  @override
  String get captainHome490a4c57 => 'Online';

  @override
  String get captainHomecbc96ded => 'Offline';

  @override
  String get captainHome7a151ab7 => 'Receiving requests';

  @override
  String get captainHome6a746fbd => 'Go online';

  @override
  String get captainHomec0ec8bb3 =>
      'Your debt limit has been reached. Contact support to settle the balance.';

  @override
  String get captainHome59003b32 =>
      'Your account needs review or approval before receiving rides.';

  @override
  String get captainHome134f277e =>
      'Request details could not be loaded. Please reopen it.';

  @override
  String get captainHomecb822418 => 'Back';

  @override
  String get captainHomea042411e => 'Customer';

  @override
  String get captainHome8c66b1c1 => 'Updating';

  @override
  String get captainHomec06144c2 => 'Accept ride';

  @override
  String get captainHome3fb68bff => 'Extra shopping requests 🛍️';

  @override
  String get captainHomede8700b0 => 'New ride request';

  @override
  String get captainHome80a51d6a => 'Motorcycle';

  @override
  String get captainHome113cb058 => 'Package';

  @override
  String get captainHome89aef3a3 => 'Car';

  @override
  String get captainHome9703ff57 => 'Accept';

  @override
  String get captainHomeeb3b1bcc => 'Decline';

  @override
  String get captainHome3a7baec4 => 'On the way';

  @override
  String get captainHomeceb508b1 => 'Arrived';

  @override
  String get captainHome2cb6f5f1 => 'Start ride';

  @override
  String get captainHome11c70484 => 'Complete ride';

  @override
  String get captainHome606af07c => 'Call';

  @override
  String get captainHome212e5d4b => 'Chat';

  @override
  String get captainHome0c1c76d8 => 'Ride assigned';

  @override
  String get captainHome7a8d87be => 'Heading to customer';

  @override
  String get captainHome36e931f5 => 'Arrived at pickup';

  @override
  String get captainHomea6fa5196 => 'Ride in progress';

  @override
  String get captainHomea674a023 => 'Ride';

  @override
  String get captainHome54940fb7 => 'Ride invoice';

  @override
  String get captainHome196a7a12 => 'Waiting for assignment';

  @override
  String get captainHome156d85a1 => 'Ride accepted';

  @override
  String get captainHome83ab21ee => 'Arrived at pickup';

  @override
  String get captainHome888bd5a4 => 'Ride started';

  @override
  String get captainHomef1d6d15f => 'Completed';

  @override
  String get captainHomed87ae61b => 'Cancelled';

  @override
  String get captainHomefa8729c1 => 'Ride status updated';

  @override
  String get captainHome1cabb6f1 => 'Settlement is up to date';

  @override
  String get captainHome9cef3446 => 'Open payment statement';

  @override
  String get captainHome5a0374f3 => 'Unspecified';

  @override
  String get captainHomed528cf79 => 'online status';

  @override
  String get captainHome8937faa1 => 'location';

  @override
  String get captainHome234766dc => 'Store';

  @override
  String get captainHome5f7b65d5 => 'Delivered';

  @override
  String get captainHome616d302c => 'Cancelled';

  @override
  String captainHomeNewRating(String value) {
    return 'New rating received ⭐ $value';
  }

  @override
  String captainHomeCustomer(String value) {
    return 'Customer: $value';
  }

  @override
  String captainHomePartialEarnings(String count) {
    return 'Earnings for $count completed rides are unavailable. Displayed income is partial.';
  }

  @override
  String captainHomeToDestination(String value) {
    return 'To $value';
  }

  @override
  String captainHomeStatus(String value) {
    return 'Ride status: $value';
  }

  @override
  String captainHomeDistance(String value) {
    return '$value km';
  }

  @override
  String captainHomePickupDistance(String value) {
    return '$value km to pickup';
  }

  @override
  String captainHomeArrival(String value) {
    return '$value min to arrive';
  }

  @override
  String captainHomeCompanyDue(String value) {
    return 'Amount due to company: EGP $value';
  }

  @override
  String captainHomeYourSettlement(String value) {
    return 'Settlement credit due to you: EGP $value';
  }

  @override
  String captainHomeDebtLimit(String value) {
    return 'Your debt limit (EGP $value) has been reached. Open the statement and contact support. The balance changes only after payment approval.';
  }

  @override
  String captainHomeMissingRpc(String code) {
    return 'The captain presence service is incompatible with the database. Send support error code $code.';
  }

  @override
  String captainHomeServerSave(String field, String code) {
    return 'The server could not save $field. Error code: $code.';
  }

  @override
  String captainMarketTitle(String store, String window) {
    return 'VETO Market — $store$window';
  }

  @override
  String captainMarketWindow(String number) {
    return ' — counter $number';
  }

  @override
  String captainMarketNet(String status, String amount) {
    return '$status • Net delivery: $amount';
  }

  @override
  String captainRideOfferDetails(
    String pickup,
    String destination,
    String distance,
    String minutes,
    String fare,
    String incentive,
  ) {
    return 'From: $pickup\nTo: $destination\nDistance: $distance km\nDuration: $minutes min\nBase fare: EGP $fare\nIncentive: EGP $incentive';
  }

  @override
  String captainOfferExtras(String extras, String estimate) {
    return 'Customer requests: $extras\n$estimate';
  }

  @override
  String get captainExtrasLimit => 'Maximum EGP 500';

  @override
  String captainExtrasEstimate(String amount) {
    return 'Estimated: EGP $amount';
  }

  @override
  String get profile9cb77234 => 'Edit name';

  @override
  String get profileecc98e31 => 'Full name';

  @override
  String get profilecb822418 => 'Back';

  @override
  String get profileddfcaf9d => 'Save';

  @override
  String get profile0b9ef884 => 'VETO customer';

  @override
  String get profiled256b773 => 'My profile';

  @override
  String get profileba69e2b8 => 'Choose a photo';

  @override
  String get profile995846e9 => 'Completed rides';

  @override
  String get profile957084b6 => 'Your rating';

  @override
  String get profiled51f9d8d => 'New';

  @override
  String get profilea7b2860b => 'My details';

  @override
  String get profilecaa3f2bb => 'Gender';

  @override
  String get profilefdcd3da0 => 'Select';

  @override
  String get profile2f13379b => 'Male';

  @override
  String get profiled2ee47ec => 'Female';

  @override
  String get profile163e063e => 'Ride preferences';

  @override
  String get profilead0b4e2d =>
      'Choose up to four preferences, visible only to your assigned captain.';

  @override
  String get profile57141c0a =>
      'Ride preferences are not available on the server. Other profile features remain available.';

  @override
  String get profile17ed4b4f => 'My frames';

  @override
  String get profile4a630f62 =>
      'Frames unlock after completed rides. You can choose any unlocked frame.';

  @override
  String get profile60e389c8 => 'VETO frame';

  @override
  String get profiled520070b => 'Available';

  @override
  String get profile774eeef9 => 'Refresh profile';

  @override
  String get profileErrorLoad =>
      'Your profile could not be loaded. Retry or contact support.';

  @override
  String get profileErrorFrame =>
      'Your frame was not changed. Check ride eligibility and retry.';

  @override
  String get profileErrorPhoto =>
      'Your photo could not be updated. Please retry.';

  @override
  String get profileErrorName => 'Your name could not be updated.';

  @override
  String get profileErrorGender => 'Your gender could not be updated.';

  @override
  String get profileErrorLimit => 'You can select up to four preferences.';

  @override
  String get profileErrorPreferences =>
      'Preferences could not be saved and will not appear to your captain until saved.';

  @override
  String get profileInterest0 => 'Quiet ride';

  @override
  String get profileInterest1 => 'No music';

  @override
  String get profileInterest2 => 'Gentle air conditioning';

  @override
  String get profileInterest3 => 'No phone calls';

  @override
  String get profileInterest4 => 'Fastest route';

  @override
  String get profileInterest5 => 'Help with luggage';

  @override
  String profileUnlockAfter(String count) {
    return 'Unlocks after $count rides';
  }

  @override
  String get history6d43782b => 'New request';

  @override
  String get history0791d4ac => 'Offers received';

  @override
  String get historyf5fde9cb => 'Accepted';

  @override
  String get history2de6d001 => 'Captain on the way';

  @override
  String get history39ac9d30 => 'Captain arrived';

  @override
  String get history888bd5a4 => 'Ride started';

  @override
  String get historyf1d6d15f => 'Completed';

  @override
  String get historyd87ae61b => 'Cancelled';

  @override
  String get history62853165 => 'Pending';

  @override
  String get history1318e3f2 => 'Confirmed';

  @override
  String get history06f3d61f => 'Preparing';

  @override
  String get history5f7b65d5 => 'Delivered';

  @override
  String get history285fe647 => '🚗 Car ride';

  @override
  String get history13b46160 => '🛵 Motorcycle ride';

  @override
  String get history040fc12a => '📦 Package';

  @override
  String get history91392c59 => '🛒 VETO Market';

  @override
  String get historyc951ef09 => 'My orders';

  @override
  String get historyb5fae2e2 => 'No orders yet';

  @override
  String get history22a82a2c => 'Rides';

  @override
  String get history452d2aff => 'Repeat ride at standard fare';

  @override
  String get historyaf4b3178 => 'VETO Market orders';

  @override
  String get history578c9670 => 'VETO Market order';

  @override
  String get historyAmountUnavailable => 'Amount unavailable';

  @override
  String get historyLoadFailed => 'Orders could not be loaded. Tap to retry.';

  @override
  String get marketCheckout583fb62f =>
      'This promo code is invalid for this store or has expired.';

  @override
  String get marketCheckout5c851b29 =>
      'The area\'s delivery fee could not be loaded.';

  @override
  String get marketCheckout85907225 =>
      'Your account details could not be loaded. Sign in again and retry.';

  @override
  String get marketCheckout7e25319d => 'Choose a delivery address.';

  @override
  String get marketCheckout6bd931d4 =>
      'This address has no valid coordinates. Tap Change and select a location on the map.';

  @override
  String get marketCheckout022a299f =>
      'Your session has expired. Sign in again to confirm your order.';

  @override
  String get marketCheckoute6356df7 =>
      'You already have an active order. Open it from home before creating another.';

  @override
  String get marketCheckout22bbfe23 =>
      'A product or quantity is unavailable. Return to your cart and refresh it.';

  @override
  String get marketCheckout9b041b34 =>
      'This store is unavailable. Choose another store or retry later.';

  @override
  String get marketCheckoute957f73e =>
      'Your wallet balance is insufficient. Choose cash or wallet plus cash.';

  @override
  String get marketCheckoutfb4a312e => 'Confirm order';

  @override
  String get marketCheckout4cb08bb2 => 'Order summary';

  @override
  String get marketCheckout4793cceb => 'Subtotal';

  @override
  String get marketCheckoutaa63ea8f => 'Delivery fee';

  @override
  String get marketCheckoutbaed6e99 => 'Total';

  @override
  String get marketCheckout65397569 => 'VETO Market promo code';

  @override
  String get marketCheckout40cf4d30 => 'Enter an optional promo code';

  @override
  String get marketCheckout268974da => 'Apply';

  @override
  String get marketCheckout0d08b83a => 'Delivery address';

  @override
  String get marketCheckout3efc34e3 => 'Change';

  @override
  String get marketCheckout7b7b0404 => 'Finding your location…';

  @override
  String get marketCheckoutaae85882 => 'Use my location';

  @override
  String get marketCheckout74190f4b => 'Address';

  @override
  String get marketCheckoutb03c96ad => 'Choose delivery address';

  @override
  String get marketCheckoutae2d6005 => 'Payment method';

  @override
  String get marketCheckout1881ccb3 => 'Cash';

  @override
  String get marketCheckout91f328d3 => 'No saved addresses';

  @override
  String get marketCheckout8d30f720 => 'Add address';

  @override
  String get marketCheckout5dc8b4dc =>
      'Allow location access, then tap Use my location.';

  @override
  String get marketCheckout1c4408e5 => 'Enable location services and retry.';

  @override
  String get marketCheckoutb4e4ffee =>
      'Your location could not be determined. Retry near a window or choose an address manually.';

  @override
  String get marketCheckout75c427ae => 'Location settings';

  @override
  String get marketCheckoutd49bcb58 => 'Home';

  @override
  String get marketCheckout20fa724b =>
      'Location selected ✓ Add your area letter and building number to help the captain find you.';

  @override
  String get marketCheckout784ff5e6 => 'Label (for example: Home)';

  @override
  String get marketCheckoutbc20c882 =>
      'Choose your area letter in Hadayek Al Ahram';

  @override
  String get marketCheckouteca4806f => 'Building number';

  @override
  String get marketCheckoutde69d94f => 'Floor';

  @override
  String get marketCheckoutbf021870 => 'Apartment number';

  @override
  String get marketCheckout9a30dc2a => 'Cancel';

  @override
  String get marketCheckout8a0c87e3 =>
      'Choose the area letter and building number first.';

  @override
  String get marketCheckout0a19bc85 => 'Allow location access, then tap Save.';

  @override
  String get marketCheckout70d4e1aa =>
      'Enable location services, then tap Save.';

  @override
  String get marketCheckoute908ffef =>
      'Your location is not available yet. Retry near a window, then tap Save.';

  @override
  String get marketCheckout9b62db02 =>
      'Your address could not be saved. Please retry.';

  @override
  String get marketCheckoutddfcaf9d => 'Save';

  @override
  String get marketOrderUnconfirmed =>
      'Order confirmation is unavailable. Check your orders or contact support before retrying.';

  @override
  String get marketPromoUnconfirmed =>
      'The promo code could not be verified. It has not been confirmed invalid; please retry.';

  @override
  String marketPromoApplied(String code) {
    return 'Promo discount ($code)';
  }

  @override
  String marketWalletChoice(String amount) {
    return 'Wallet (EGP $amount)';
  }

  @override
  String marketWalletCashChoice(String amount) {
    return 'Wallet + cash (EGP $amount from wallet, remaining in cash)';
  }

  @override
  String get ratingExperience => 'How was your ride with this passenger?';

  @override
  String get ratingExcellent => 'Excellent';

  @override
  String get ratingVeryGood => 'Very good';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingImprove => 'Needs improvement';

  @override
  String get ratingUncomfortable => 'Uncomfortable experience';

  @override
  String get ratingWhatHappened => 'What happened?';

  @override
  String get ratingBlocked =>
      'You will no longer receive requests from this passenger.';

  @override
  String get ratingBlockOption => 'Stop receiving their requests';

  @override
  String get ratingNote => 'Additional note (optional)';

  @override
  String get ratingSending => 'Sending…';

  @override
  String get ratingSend => 'Send rating';

  @override
  String get ratingLater => 'Not now';

  @override
  String get ratingReason0 => 'Late to the pickup point';

  @override
  String get ratingReason1 => 'Inappropriate behaviour';

  @override
  String get ratingReason2 => 'Changed destination';

  @override
  String get ratingReason3 => 'Uncomfortable communication';

  @override
  String get ratingReason4 => 'Other';

  @override
  String get ratingUnconfirmed =>
      'Rating completion could not be confirmed. Check its status or contact support before retrying.';

  @override
  String ratingStars(String count) {
    return '$count out of 5';
  }

  @override
  String get customerRatingTitle => 'How was your ride?';

  @override
  String get customerRatingComment => 'Optional comment';

  @override
  String get customerRatingPrivacy =>
      'Your reasons and comment are for the review team. The captain sees their updated rating without your name.';

  @override
  String get customerRatingSending => 'Sending…';

  @override
  String get customerRatingReason0 => 'Late pickup';

  @override
  String get customerRatingReason1 => 'Inappropriate behaviour';

  @override
  String get customerRatingReason2 => 'Uncomfortable driving';

  @override
  String get customerRatingReason3 => 'Requested extra money';

  @override
  String get customerRatingReason4 => 'Different vehicle';

  @override
  String get customerRatingReason5 => 'Unexpected route';

  @override
  String get customerRatingReason6 => 'Another issue';

  @override
  String get customerRatingReason7 => 'Arrived quickly';

  @override
  String get customerRatingReason8 => 'Respectful';

  @override
  String get customerRatingReason9 => 'Comfortable driving';

  @override
  String get customerRatingReason10 => 'Clean vehicle';

  @override
  String get customerRatingReason11 => 'Excellent experience';

  @override
  String customerRatingCaptain(String name) {
    return 'Rate captain $name';
  }

  @override
  String customerRatingStars(String count) {
    return '$count stars';
  }

  @override
  String get marketStoresTitle => 'VETO Market';

  @override
  String get marketStoresEmpty => 'No stores are available right now';

  @override
  String get marketStoresOpen => 'Open';

  @override
  String get marketStoresClosed => 'Closed';

  @override
  String get marketStoresFailed => 'Stores could not be loaded. Please retry.';

  @override
  String marketStoresMinutes(String count) {
    return '$count min';
  }

  @override
  String get marketProductsTitle => 'Products';

  @override
  String get marketProductsEmpty => 'No products in this category';

  @override
  String get marketProductsAdd => 'Add';

  @override
  String get marketProductsCart => 'Shopping cart';

  @override
  String get marketProductsTotal => 'Subtotal';

  @override
  String get marketProductsContinue => 'Continue order';

  @override
  String get marketProductsFailed =>
      'Products could not be loaded. Please retry.';

  @override
  String marketProductsViewCart(String count, String amount) {
    return 'View cart ($count items) - EGP $amount';
  }

  @override
  String marketProductsLine(String price, String count, String amount) {
    return 'EGP $price × $count = EGP $amount';
  }

  @override
  String get marketHistoryTitle => 'My VETO Market orders';

  @override
  String get marketHistoryEmpty => 'No previous orders.';

  @override
  String get marketHistoryReorder =>
      'Reorder available items at current prices';

  @override
  String get marketHistoryPartial => 'Some items are not fully available';

  @override
  String get marketHistoryCancel => 'Cancel';

  @override
  String get marketHistoryAccept => 'Agree';

  @override
  String get marketHistoryStoreUnavailable =>
      'This store is closed or unavailable.';

  @override
  String get marketHistoryProductsUnavailable =>
      'No items are currently available to reorder.';

  @override
  String get marketHistoryReorderFailed =>
      'The reorder could not be prepared. Please retry.';

  @override
  String get marketHistoryFailed =>
      'Your orders could not be loaded. Retry or check your sign-in.';

  @override
  String marketHistoryStock(String name, String count) {
    return '$name (only $count available)';
  }

  @override
  String marketHistoryMissing(String items) {
    return 'These items will be omitted or reduced:\n$items\n\nContinue with the remaining items at current prices?';
  }

  @override
  String marketHistoryOrder(String id, String status) {
    return 'Order $id • $status';
  }

  @override
  String marketHistoryAmount(String amount) {
    return 'Total when ordered: EGP $amount';
  }

  @override
  String marketHistoryDate(String date) {
    return 'Date: $date';
  }

  @override
  String get marketTracking2335b680 => 'Your VETO Market order';

  @override
  String get marketTrackingd8fd5c0d => 'WhatsApp support';

  @override
  String get marketTracking7a653e5a =>
      'Order could not be loaded. Refresh or check your sign-in.';

  @override
  String get marketTrackingd51f9d8d => 'New';

  @override
  String get marketTrackingf5fde9cb => 'Accepted';

  @override
  String get marketTrackingbf6cf358 => 'Preparing';

  @override
  String get marketTracking9643e947 => 'Captain';

  @override
  String get marketTracking69ca2e6b => 'Collected';

  @override
  String get marketTracking4452951b => 'On the way';

  @override
  String get marketTracking3ef541b9 => 'Done';

  @override
  String get marketTracking3b315330 => 'Your captain';

  @override
  String get marketTrackinga6b2ea4b => 'VETO captain';

  @override
  String get marketTracking606af07c => 'Call';

  @override
  String get marketTracking3150a947 => 'Chat';

  @override
  String get marketTrackinge9ffcc97 => 'Order details';

  @override
  String get marketTracking771e11be => 'Subtotal';

  @override
  String get marketTracking78415ee3 => 'Delivery';

  @override
  String get marketTracking48c3380c => 'Paid from wallet';

  @override
  String get marketTrackingdbf303cb => 'Cash due';

  @override
  String get marketTrackingbaed6e99 => 'Total';

  @override
  String get marketTracking4c5cf17e => 'Store';

  @override
  String get marketTrackingae881876 => 'WhatsApp could not be opened.';

  @override
  String get marketTracking376012df => 'Waiting for the store';

  @override
  String get marketTracking333cc412 => 'The store accepted your order';

  @override
  String get marketTracking58837987 => 'Your order is being prepared';

  @override
  String get marketTracking07554e17 => 'Ready for pickup';

  @override
  String get marketTrackingb7d72a98 => 'A captain has been assigned';

  @override
  String get marketTrackingff3274e0 => 'The captain collected your order';

  @override
  String get marketTracking2f7a3366 => 'The captain is on the way to you';

  @override
  String get marketTracking3a648805 => 'Order delivered';

  @override
  String get marketTracking46c5b2fc => 'Order cancelled';

  @override
  String get marketTracking7430827b =>
      'We will let you know when the store accepts.';

  @override
  String get marketTracking3a216b91 => 'The store will prepare your order.';

  @override
  String get marketTracking80c40038 =>
      'The store is checking and preparing your items.';

  @override
  String get marketTracking0f39c3d0 => 'Waiting for captain pickup.';

  @override
  String get marketTracking7451a3a0 => 'The captain is heading to the store.';

  @override
  String get marketTracking8877e2b1 => 'You can now contact the captain.';

  @override
  String get marketTracking55635fa8 => 'Follow the captain on the map.';

  @override
  String get marketTrackingc0e8e2e6 => 'Thank you for using VETO Market.';

  @override
  String get marketTrackinga952b3bf =>
      'Check the cancellation reason or contact support.';

  @override
  String get marketTrackingaed070ad => 'Order chat';

  @override
  String get marketTrackingcb7741fc => 'Write a message…';

  @override
  String marketTrackingPhone(String phone) {
    return 'Captain phone: $phone';
  }

  @override
  String marketTrackingVehicle(String vehicle, String color, String plate) {
    return '$vehicle • $color • Plate $plate';
  }

  @override
  String marketTrackingCounter(String number) {
    return 'Counter $number';
  }

  @override
  String get marketChatSendFailed =>
      'Message delivery could not be confirmed. Check the conversation before retrying.';

  @override
  String get marketChatSupportFailed => 'WhatsApp could not be opened.';

  @override
  String get marketChatTitle => 'Order chat';

  @override
  String get marketChatSupport => 'WhatsApp support';

  @override
  String get marketChatEmpty => 'Start the conversation with a clear message.';

  @override
  String get marketChatInput => 'Write a clear message…';

  @override
  String get marketChatYou => 'You';

  @override
  String get marketChatCaptain => 'Captain';

  @override
  String get marketChatStore => 'Store';

  @override
  String get marketChatAdmin => 'Review team';

  @override
  String get marketChatCustomer => 'Customer';

  @override
  String get marketChatParticipant => 'Participant';

  @override
  String get marketChatLoadFailed =>
      'The conversation could not be loaded. Retry or check your sign-in.';

  @override
  String get marketChatReadFailed =>
      'The message read status could not be updated.';

  @override
  String get captainFareBase => 'Ride base fare';

  @override
  String get captainFareUpdating => 'Fare is being updated';

  @override
  String get captainFareFinalInvoice =>
      'Server fare. Final invoice after the ride.';

  @override
  String captainFareIncentive(String amount) {
    return 'Extra incentive: +EGP $amount';
  }

  @override
  String get activeCaptain9b2f45b6 =>
      'Ride status could not be confirmed. Refresh before retrying.';

  @override
  String get activeCaptain99f2c8a6 => 'Current ride';

  @override
  String get activeCaptainae7ae56d => 'Pickup';

  @override
  String get activeCaptain8b068efc => 'Destination';

  @override
  String get activeCaptain45a9a436 => 'Fare';

  @override
  String get activeCaptain3eab5144 => 'Incentive';

  @override
  String get activeCaptainf69cdd96 => 'Accepted';

  @override
  String get activeCaptain3a7baec4 => 'On the way';

  @override
  String get activeCaptainceb508b1 => 'Arrived';

  @override
  String get activeCaptain888bd5a4 => 'Ride started';

  @override
  String get activeCaptainc20f27ab => 'In progress';

  @override
  String get activeCaptaineef4662a => 'Head to pickup';

  @override
  String get activeCaptain2cb6f5f1 => 'Start ride';

  @override
  String get activeCaptain11c70484 => 'Finish ride';

  @override
  String get feedbackClearMessage => 'Please write a clearer message';

  @override
  String get feedbackSent => 'Your message was sent to the review team';

  @override
  String get feedbackComplaint => 'Complaint';

  @override
  String get feedbackSuggestion => 'Suggestion';

  @override
  String get feedbackType => 'Message type';

  @override
  String get feedbackComplaintHint => 'Describe your complaint…';

  @override
  String get feedbackSuggestionHint =>
      'Share your suggestion to improve the app…';

  @override
  String get feedbackSending => 'Sending…';

  @override
  String get feedbackSend => 'Send to review team';

  @override
  String get feedbackUnconfirmed =>
      'Message submission could not be confirmed. Check with support before retrying.';

  @override
  String get feedbackAccountChanged =>
      'Check your sign-in and reopen this page from your current account.';

  @override
  String get legal23d4bbf5 =>
      'The link could not be opened. You can call 01031517830.';

  @override
  String get legalbb7d2e6a => 'The link could not be opened. Call 01031517830.';

  @override
  String get legal930c8cba => 'Legal information and support';

  @override
  String get legalcb822418 => 'Back';

  @override
  String get legal5d933de9 => 'Your rights and information in one place';

  @override
  String get legal18f333af =>
      'Read our policies and contact options, or start an account deletion request.';

  @override
  String get legalbcaecd4c => 'Last updated: 22 September 2026';

  @override
  String get legalf0942ede =>
      'I request deletion of my VETO SANYA account and associated data. Please explain verification and follow-up steps.';

  @override
  String get legal04f1727b => 'Request deletion through WhatsApp';

  @override
  String get legal0efc8201 => 'Call to request deletion';

  @override
  String get legal94fb90ab =>
      'WhatsApp opens a way to send the request. It does not automatically delete your account.';

  @override
  String get legal3852d180 => 'View all legal pages';

  @override
  String get legal01b2add5 => 'Contact: وعد محمد';

  @override
  String get legalb70c8e6c => 'Call: 01031517830';

  @override
  String get captainMarketd7768428 =>
      'Pickup recorded. You can now contact the customer.';

  @override
  String get captainMarket14dc5df9 =>
      'The customer was notified that you are on the way.';

  @override
  String get captainMarket53dcbe87 => 'Order delivered successfully.';

  @override
  String get captainMarket6eae6542 => 'Order updated.';

  @override
  String get captainMarket6de2e125 =>
      'The update could not be confirmed. Refresh the order before retrying.';

  @override
  String get captainMarketd8fd5c0d => 'WhatsApp support';

  @override
  String get captainMarkete8449fb2 => 'Cancel job — EGP 10 fee';

  @override
  String get captainMarket14d5786f => 'Try again';

  @override
  String get captainMarketd5d536cd =>
      'Go to the store first. Customer details appear after pickup.';

  @override
  String get captainMarketd8f14d9b =>
      'Complete the steps in order. The customer and store will receive updates.';

  @override
  String get captainMarketdaf5d487 => 'First stop: store';

  @override
  String get captainMarket97432797 => 'Store details';

  @override
  String get captainMarket4c5cf17e => 'Store';

  @override
  String get captainMarketd33daf8e => 'Call store';

  @override
  String get captainMarketc76b2601 => 'Open navigation';

  @override
  String get captainMarket8cc3de69 => 'Second stop: customer';

  @override
  String get captainMarketa042411e => 'Customer';

  @override
  String get captainMarket606af07c => 'Call';

  @override
  String get captainMarket3150a947 => 'Chat';

  @override
  String get captainMarket467e6137 => 'Check the order items';

  @override
  String get captainMarketf8720c74 => 'Product';

  @override
  String get captainMarketc2b2b3af => 'I collected the order';

  @override
  String get captainMarket58ed2a34 => 'On the way to customer';

  @override
  String get captainMarket25cb347d => 'Review invoice and confirm delivery';

  @override
  String get captainMarket310ca3cd => 'Order finished';

  @override
  String get captainMarket973ed905 => 'Collection and delivery invoice';

  @override
  String get captainMarket95b5d1f4 => 'Collect from customer';

  @override
  String get captainMarketdf06bb32 =>
      'The order is paid. Do not collect money from the customer.';

  @override
  String get captainMarket75d406d4 => 'Pay store on pickup';

  @override
  String get captainMarket02f77b39 => 'Paid from customer wallet';

  @override
  String get captainMarket25d3f39d => 'Customer discount';

  @override
  String get captainMarketaa63ea8f => 'Delivery fee';

  @override
  String get captainMarket78163c16 => 'Your net delivery earnings';

  @override
  String get captainMarket15c48cd1 =>
      'Do not deduct commission from the customer payment or the store entitlement. Your balance settlement is recorded automatically once after delivery.';

  @override
  String get captainMarket456e5cc8 =>
      'The invoice is incomplete. Refresh the order before confirming delivery.';

  @override
  String get captainMarket981e9393 => 'Confirm delivery and collection';

  @override
  String get captainMarketcce08954 =>
      'The order is paid. Deliver it without collecting cash.';

  @override
  String get captainMarketcb822418 => 'Back';

  @override
  String get captainMarket25deb8cf => 'Order delivered';

  @override
  String get captainMarket8b4ef63a => 'Payment collected and order delivered';

  @override
  String get captainMarketae881876 => 'WhatsApp could not be opened.';

  @override
  String get captainMarket3b88cefe => 'Cancel this store job?';

  @override
  String get captainMarket0ea97780 =>
      'Your assignment will be cancelled and the order returned to the administration. An EGP 10 fee will be deducted from your account.';

  @override
  String get captainMarket2e57d50e => 'Confirm cancellation and fee';

  @override
  String get captainMarket206a9708 =>
      'The job was cancelled and the EGP 10 fee deducted.';

  @override
  String get captainMarketff44f761 =>
      'Cancellation could not be confirmed. Refresh the order before retrying.';

  @override
  String get captainMarket3ba053db => 'Head to the store';

  @override
  String get captainMarket0b98ede2 => 'The order is ready at the store';

  @override
  String get captainMarket0bbfeacc => 'Collected — head to customer';

  @override
  String get captainMarketaf0ea2c8 => 'You are on the way to the customer';

  @override
  String get captainMarketf711d592 => 'Delivered successfully';

  @override
  String get captainMarket97b675e6 => 'Store delivery job';

  @override
  String get captainMarket67cf4a3e => 'Customer chat';

  @override
  String get captainMarketcb7741fc => 'Write a message…';

  @override
  String get captainMarketLoadFailed =>
      'The store job could not be loaded. Refresh or check your sign-in.';

  @override
  String captainMarketCommission(String percent) {
    return 'Company commission ($percent%)';
  }

  @override
  String captainMarketConfirmCash(String amount) {
    return 'Confirm you collected EGP $amount from the customer.';
  }

  @override
  String captainMarketJobTitle(String order) {
    return 'VETO Market job — $order';
  }

  @override
  String get bookingFinalCopy1b070dab =>
      'Offer settings could not be loaded. You can continue booking.';

  @override
  String get bookingFinalCopy372b98ca => 'Amount details';

  @override
  String get bookingFinalCopybeed4dc9 => 'Current incentive';

  @override
  String get bookingFinalCopy48c3380c => 'From wallet';

  @override
  String get bookingFinalCopy2e243e7f => 'Expected cash';

  @override
  String get bookingFinalCopy955b4b7b => 'Updating the fare from the server';

  @override
  String get bookingFinalCopy4a2fae95 =>
      'The previous request could not be restored. Choose its details and review the current fare.';

  @override
  String get bookingFinalCopy37a5d6fa =>
      'The fare is currently unavailable for this service. Please retry.';

  @override
  String get bookingFinalCopy2f2b8b3e => 'Choose your ride';

  @override
  String get bookingFinalCopy89aef3a3 => 'Car';

  @override
  String get bookingFinalCopy80a51d6a => 'Motorcycle';

  @override
  String get bookingFinalCopy113cb058 => 'Package';

  @override
  String get bookingFinalCopyda3ac454 => 'Fare after selection';

  @override
  String get bookingFinalCopyde62259f =>
      'The server fare changed. Review the total and confirm again.';

  @override
  String get bookingFinalCopy9d4632b1 =>
      'The fare could not be refreshed. Check the current quote before retrying.';

  @override
  String get bookingFinalCopyb60ed4c8 =>
      'Additional purchase requests must not exceed EGP 500';

  @override
  String get bookingFinalCopyb9f67739 => 'The ride request was cancelled.';

  @override
  String get bookingFinalCopyd6bf4f47 =>
      'The incentive update could not be confirmed. Refresh the ride before retrying.';

  @override
  String get bookingFinalCopy6c65081c =>
      'The choice could not be confirmed. Refresh the ride and payment details before retrying.';

  @override
  String get bookingFinalCopydd481f00 =>
      'The request is cancelled, but its recorded fees need support review. No historical balance was adjusted.';

  @override
  String get bookingFinalCopy70377ee9 => 'Updating your ride fare…';

  @override
  String bookingCurrentIncentive(String amount) {
    return 'The current incentive is already +EGP $amount. You can choose a higher amount.';
  }

  @override
  String get legacyCaptainRewardb754feca =>
      'The offer link could not be opened';

  @override
  String get legacyCaptainRewardbbe4ec79 => 'Captain rewards';

  @override
  String get legacyCaptainRewardea201b37 =>
      'Eligible completed rides during the offer period count. Payment is manual after administrative review.';

  @override
  String get legacyCaptainReward06d1b76f =>
      'The administration pays the reward through Vodafone Cash. It is not added to the app wallet.';

  @override
  String get legacyCaptainRewarda73a4757 => 'Open offer details';

  @override
  String get legacyCaptainReward9e6d9f56 => 'Reward paid';

  @override
  String get legacyCaptainReward9868ebaa =>
      'Due — awaiting Vodafone Cash payment';

  @override
  String get legacyCaptainReward6d269d00 => 'Recipient limit reached';

  @override
  String get legacyCaptainRewardecaefa5c => 'Offer ended';

  @override
  String get legacyCaptainReward7a13f6b6 => 'Starts soon';

  @override
  String get legacyCaptainReward141a2c34 => 'Offer available';

  @override
  String get legacyCaptainReward683deff3 =>
      'Manual Vodafone Cash payment after administrative review';

  @override
  String legacyCaptainRewardTime(String time) {
    return 'Time remaining: $time';
  }

  @override
  String legacyCaptainRewardProgress(String progress, String target) {
    return '$progress of $target eligible rides';
  }

  @override
  String get bookingAccountChanged =>
      'Your account changed. Return home and start from your current account.';

  @override
  String get captainAssignmentTitle => 'VETO Market job';

  @override
  String get captainAssignmentRefresh => 'Refresh';

  @override
  String get captainAssignmentEmpty =>
      'No store job is assigned to you right now';

  @override
  String get captainAssignmentOpen => 'Open assigned job';

  @override
  String get buildingNumberFirst =>
      'Enter a building number from 1 to 590 first.';

  @override
  String get buildingConfirmFirst => 'Confirm you are at the building first.';

  @override
  String get buildingGpsEnable =>
      'Turn on location services in your phone settings.';

  @override
  String get buildingGpsAllow =>
      'Allow location access in your device or browser settings.';

  @override
  String get buildingOutside =>
      'Your current location is outside the approximate Hadayek Al Ahram area.';

  @override
  String get buildingNumberInvalid => 'Enter a building number from 1 to 590.';

  @override
  String get buildingLocateFirst =>
      'Confirm you are at the building, then choose Locate me.';

  @override
  String get buildingReviewed =>
      'This building has already been reviewed. Go back and select it from search.';

  @override
  String get buildingDailyLimit =>
      'You reached today’s building submission limit. Try tomorrow.';

  @override
  String get buildingSession => 'Your session ended. Sign in again.';

  @override
  String get buildingLocationInvalid =>
      'The location or its accuracy is unsuitable. Enable GPS and try in an open area.';

  @override
  String get buildingCustomerRequired =>
      'Sign in with an active customer account.';

  @override
  String get buildingUnconfirmed =>
      'Saving could not be confirmed. Check the submission status before retrying.';

  @override
  String get buildingTitle => 'Building missing? Suggest its location';

  @override
  String get buildingAreaLetter => 'Area letter';

  @override
  String get buildingNumberHint => 'From 1 to 590';

  @override
  String get buildingAtLocation => 'I am at my building now';

  @override
  String get buildingLocating => 'Locating you…';

  @override
  String get buildingLocate => 'Locate me';

  @override
  String get buildingCancel => 'Cancel';

  @override
  String get buildingSaving => 'Saving…';

  @override
  String get buildingSave => 'Save and use this pickup';

  @override
  String get buildingIntro =>
      'Help the captain find you. Stand at the building and allow location access.';

  @override
  String get buildingReviewNotice =>
      'You can use this pickup for the current request. The administration reviews it before it appears for other customers.';

  @override
  String buildingAccuracyWeak(String accuracy) {
    return 'Location accuracy is low ($accuracy m). Try again in an open area.';
  }

  @override
  String buildingAreaValue(String letter) {
    return 'Area $letter';
  }

  @override
  String buildingAccuracyCaptured(String accuracy) {
    return 'Location captured — approximate accuracy $accuracy m';
  }

  @override
  String get captainMapDemandError =>
      'Areas could not be refreshed. Previous data may be outdated.';

  @override
  String get captainMapHighDemand => 'High demand';

  @override
  String get captainMapConnected => 'Connected';

  @override
  String get captainMapOffline => 'Offline';

  @override
  String get captainMapOpen => 'Open area map';

  @override
  String get captainMapMissingLocation =>
      'Your location is unavailable. The map shows a default centre.';

  @override
  String get captainMapHotspots => 'High-demand areas';

  @override
  String get captainMapRange => 'Range:';

  @override
  String get captainMapRefresh => 'Refresh areas';

  @override
  String get captainMapNearby => 'Active areas nearby';

  @override
  String get captainMapMultiplier => 'Highest published multiplier';

  @override
  String get captainMapSearchRange => 'Search range';

  @override
  String get captainMapOpenFull => 'View the full area map';

  @override
  String get captainMapEnable =>
      'Enable this to see high-demand areas around your location.';

  @override
  String captainMapKilometres(String distance) {
    return '$distance km';
  }

  @override
  String captainMapRequests(String count) {
    return 'Requests: $count';
  }

  @override
  String captainMapUpdated(String time) {
    return 'Updated $time • Server multipliers only';
  }

  @override
  String get partnerLoadFailed =>
      'The partnership report could not be loaded. Refresh or check your sign-in.';

  @override
  String get partnerPayoutTitle => 'Payout wallet';

  @override
  String get partnerWalletNumber => 'Wallet number';

  @override
  String get partnerCancel => 'Cancel';

  @override
  String get partnerSave => 'Save';

  @override
  String get partnerWalletUnconfirmed =>
      'The payout wallet update could not be confirmed. Refresh before retrying.';

  @override
  String get partnerTitle => 'Partnership account';

  @override
  String get partnerInactive => 'Partnership is inactive';

  @override
  String get partnerTeamCode => 'Your team code';

  @override
  String get partnerCaptains => 'Captains';

  @override
  String get partnerTrips => 'Rides';

  @override
  String get partnerDue => 'Amount due';

  @override
  String get partnerPaid => 'Paid';

  @override
  String get partnerSettledOnly => 'After ride completion and settlement';

  @override
  String get partnerCommissionDisabled => 'Commission is currently inactive';

  @override
  String get partnerPayoutWallet => 'Payout wallet';

  @override
  String get partnerAddWallet => 'Add your wallet number';

  @override
  String get partnerSchedule => 'Settlement every Saturday • 11 PM Cairo time';

  @override
  String get partnerTeam => 'Your team';

  @override
  String get partnerCaptain => 'Captain';

  @override
  String get partnerMotorcycle => 'Motorcycle';

  @override
  String get partnerCar => 'Car';

  @override
  String get partnerMonthly => 'Monthly summary';

  @override
  String get partnerStatements => 'Settlement statements';

  @override
  String get partnerTransferred => 'Paid';

  @override
  String get partnerPendingTransfer => 'Awaiting transfer';

  @override
  String get partnerOpen => 'Open partnership account';

  @override
  String partnerShare(String percent) {
    return 'Your commission: $percent% of the fare';
  }

  @override
  String partnerTeamRides(String vehicle, String count) {
    return '$vehicle • $count rides';
  }

  @override
  String partnerMonthValues(String due, String paid) {
    return 'Due: EGP $due • Paid: EGP $paid';
  }

  @override
  String get partnerMonthlyUnavailable =>
      'The monthly report is unavailable. The rest of the partnership report shows server results.';

  @override
  String get addressSearchPartial =>
      'Part of address search is unavailable. Results are from responding sources; you can choose an address manually.';

  @override
  String get vectorMapUnavailable =>
      'The map could not be displayed. You can use a saved address or return to address selection.';

  @override
  String get newsLoadFailed => 'Posts could not be loaded. Refresh to retry.';

  @override
  String get newsReactionFailed =>
      'Your reaction could not be confirmed. Refresh before retrying.';

  @override
  String get newsNicknameTitle => 'Your community nickname';

  @override
  String get newsNicknameHint => 'Choose the name you want to display.';

  @override
  String get newsNicknameExample => 'Example: VETO rider';

  @override
  String get newsCancel => 'Cancel';

  @override
  String get newsSaveNickname => 'Save nickname';

  @override
  String get newsNicknameSaved => 'Nickname saved';

  @override
  String get newsNicknameFailed =>
      'The nickname update could not be confirmed. Refresh before retrying.';

  @override
  String get newsTitle => 'VETO News';

  @override
  String get newsDisplayName => 'Display name';

  @override
  String get newsRefresh => 'Refresh';

  @override
  String get newsRetry => 'Retry';

  @override
  String get newsEmpty => 'No posts yet';

  @override
  String get newsCommunity => 'Community news';

  @override
  String get newsImageUnavailable => 'Image unavailable';

  @override
  String get newsComments => 'Comments';

  @override
  String get newsCommentsFailed => 'Comments are unavailable. Try again later.';

  @override
  String get newsCommentFailed =>
      'Comment posting could not be confirmed. Refresh before retrying.';

  @override
  String get newsMember => 'VETO member';

  @override
  String get newsUseNickname => 'Post using your nickname';

  @override
  String get newsWriteComment => 'Write a comment…';

  @override
  String get newsPostComment => 'Post comment';

  @override
  String newsLikes(String count) {
    return 'Like $count';
  }

  @override
  String get liveMapStale =>
      'Location needs an update — waiting for the captain';

  @override
  String get liveMapEtaUnavailable => 'Arrival estimate is unavailable';

  @override
  String get liveMapCalculating => 'Calculating arrival time';

  @override
  String get liveMapNearTarget => 'Near the destination point';

  @override
  String get liveMapEstimate => 'Estimated';

  @override
  String liveMapEtaDistance(int minutes, String distance) {
    return '$minutes min • $distance km';
  }

  @override
  String get homeLoyaltySilver => 'Silver';

  @override
  String get homeLoyaltyGold => 'Gold';

  @override
  String homeLoyaltyRank(int rank) {
    return 'Your rank: $rank';
  }

  @override
  String homeLoyaltyProgress(int remaining, int completed) {
    return '$remaining rides to the next level · $completed completed';
  }

  @override
  String homeLoyaltyCompleted(int completed) {
    return '$completed rides completed';
  }

  @override
  String get homeLoyaltyRewardCredited =>
      'Your ride reward was credited to your wallet';

  @override
  String homeLoyaltyRewardRemaining(int remaining, String amount) {
    return '$remaining rides to a reward of $amount EGP';
  }

  @override
  String get homeSavedPickupVerified =>
      'Saved pickup — you can change it before confirmation';

  @override
  String homeSelectedCity(String city) {
    return 'Selected city: $city';
  }

  @override
  String homeCityLocation(String city) {
    return 'Your location: $city';
  }

  @override
  String get homeCityLookupUnavailable =>
      'Pickup city could not be confirmed. Choose it manually or retry.';

  @override
  String get extraIntroTitle => 'Your ride and purchases in one trip';

  @override
  String get extraIntroBody =>
      'Ask your captain to pick up small purchases on the way. Agree on the items and their cost before buying.';

  @override
  String get extraIntroContinue => 'Continue to purchases';

  @override
  String get extraFeatureTitle => 'Pick up purchases';

  @override
  String get extraFeatureTip =>
      'Add your purchase request before confirming the ride.';

  @override
  String get extraFeatureLabel => 'Purchase request (optional)';

  @override
  String get extraFeatureHint => 'Example: pick up bread and milk on the way';

  @override
  String get extraFeatureHelper =>
      'Agree on the purchases and their cost with the captain';

  @override
  String get extraInvalidAmount =>
      'Enter a valid amount in EGP with up to two decimal places';

  @override
  String get captainGpsNeedsUpdate => 'Online — update your location';

  @override
  String get captainProfileVehicle => 'Ride vehicle';

  @override
  String get captainProfileIncompleteVehicle =>
      'Vehicle information is incomplete';

  @override
  String get captainProfileReviews => 'Passenger reviews';

  @override
  String get captainProfileNoReviews => 'No published captain reviews yet.';

  @override
  String get captainProfileVerifiedIdentity => 'Verified identity';

  @override
  String get captainProfileVerifiedVehicle => 'Verified vehicle';

  @override
  String get captainProfileCompleted => 'Completed rides';

  @override
  String get captainProfileAverage => 'Average rating';

  @override
  String captainProfileRatingCount(int count) {
    return 'From $count ratings';
  }

  @override
  String get captainProfileDefaultName => 'Captain';

  @override
  String get cityChoose => 'Choose a city';

  @override
  String get cityActualPrice => 'The fare uses the actual ride location';

  @override
  String get cityAutomaticLocation => 'Use my current location';

  @override
  String get cityPickupNext => 'Choose your pickup point next';

  @override
  String get cityComingSoon => 'Coming soon';

  @override
  String get placesRefresh => 'Refresh places';

  @override
  String get placesSearchHint =>
      'Search for an area, building letter or number';

  @override
  String get placesChooseAreaFirst => 'Choose an area first';

  @override
  String get placesIndependent => 'Buildings and individual places';

  @override
  String get placesBuildingLetter => 'Building letter, if available';

  @override
  String get placesAll => 'All';

  @override
  String get placesNoLetter => 'No letter';

  @override
  String get placesChooseBuilding => 'Choose a building number or place';

  @override
  String get placesNoApproved =>
      'No approved addresses are available for this city yet. Choose a map location or suggest an address.';

  @override
  String get placesSuggestionHelp =>
      'Address missing? Use Suggest an address below the list.';

  @override
  String get comboCaptainTitle => 'This ride includes purchases 🛍️';

  @override
  String get comboCaptainDescription =>
      'The customer has requested small purchases along the way.';

  @override
  String get comboCaptainSteps => 'What to do:';

  @override
  String get comboCaptainBuy => 'Buy the agreed items and pay in cash.';

  @override
  String get comboCaptainDeliver =>
      'Deliver the items and collect their cost plus the ride fare.';

  @override
  String get comboCaptainAgree =>
      'Confirm the items and prices with the customer in chat before buying.';

  @override
  String get comboCaptainLimit =>
      'Purchases are limited to EGP 500. Agree with the customer before buying.';

  @override
  String get comboCaptainSaveFailed =>
      'Confirmation could not be saved. Check connectivity and try again.';

  @override
  String get comboCaptainUnderstood => 'Understood';

  @override
  String get captainProfileNew => 'New';

  @override
  String cityNotActive(String place) {
    return '$place · Not active yet';
  }

  @override
  String placesCityTitle(String place) {
    return 'Areas and buildings in $place';
  }

  @override
  String placesCityAreas(String place) {
    return 'All areas in $place';
  }

  @override
  String placesUseArea(String place) {
    return 'Use the location of $place';
  }

  @override
  String get placesLoadFailed => 'Places could not be loaded. Tap refresh.';

  @override
  String get tripBadgeRequested => 'Requested';

  @override
  String get tripBadgeOffers => 'Offers available';

  @override
  String get tripBadgeAccepted => 'Accepted';

  @override
  String get tripBadgeArriving => 'Captain on the way';

  @override
  String get tripBadgeArrived => 'Captain arrived';

  @override
  String get tripBadgeStarted => 'Ride started';

  @override
  String get tripBadgeCompleted => 'Completed';

  @override
  String get tripBadgeCancelled => 'Cancelled';

  @override
  String get banDefaultAppeal =>
      'Please review the temporary suspension and the circumstances of the ride.';

  @override
  String get banAppealTitle => 'Tell us your side';

  @override
  String get banAppealHint => 'Explain your appeal';

  @override
  String get banBack => 'Back';

  @override
  String get banSendAppeal => 'Send appeal';

  @override
  String get banClearReason => 'Please explain your appeal clearly.';

  @override
  String get banSendFailed => 'The appeal could not be sent. Try again.';

  @override
  String get banTitle => 'Account temporarily suspended';

  @override
  String get banRemaining => 'Time remaining';

  @override
  String get banExpiryConfirming =>
      'Confirming the end of the suspension with the server';

  @override
  String get banReturnOnline =>
      'After the suspension ends, return to your dashboard and go online.';

  @override
  String get banAppealSent => 'Appeal sent for review';

  @override
  String get banSending => 'Sending';

  @override
  String get banAppeal => 'Submit an appeal';

  @override
  String get banRefreshAccount => 'Refresh account status';

  @override
  String get debtInvoiceLoadFailed =>
      'The invoice could not be loaded. Check the required server update and refresh.';

  @override
  String get debtInvoiceTitle => 'Captain amount due';

  @override
  String get debtInvoiceRefresh => 'Refresh invoice';

  @override
  String get debtInvoiceReference => 'Invoice reference';

  @override
  String get debtInvoiceStatus => 'Invoice status';

  @override
  String get debtInvoicePaid => 'Paid';

  @override
  String get debtInvoicePending => 'Awaiting payment and confirmation';

  @override
  String get debtInvoiceHelp =>
      'Contact support with the invoice reference. You can pay all or part of the amount due. The balance changes only after administration confirms receipt; opening this invoice or sending proof does not change it.';

  @override
  String get debtInvoiceSupportUnavailable =>
      'The support number is unavailable. Contact administration to configure it.';

  @override
  String get debtInvoiceAfterPayment => 'Refresh after payment';

  @override
  String get areaChooseLetter => 'Choose your area letter';

  @override
  String get areaChooseBuildingLetter =>
      'Tap the letter of the area containing your building';

  @override
  String get areaShowLetters => 'Tap the card to view the 16 area letters';

  @override
  String banReason(String reason) {
    return 'Your account was temporarily suspended: $reason';
  }

  @override
  String debtInvoiceAmount(String amount) {
    return 'Current amount due: $amount EGP';
  }

  @override
  String debtInvoiceCall(String phone) {
    return 'Call support: $phone';
  }

  @override
  String get captainRoadUnavailable =>
      'Route preview is unavailable. Refresh and try again.';

  @override
  String get captainRoadCoordinatesUnavailable =>
      'Ride coordinates are unavailable.';

  @override
  String get captainRoadTitle => 'Ride route';

  @override
  String get captainRoadLegend =>
      'Green: pickup • Red: destination • Blue: your location';

  @override
  String get captainRoadDirections => 'Road directions';

  @override
  String get captainRoadExplanation =>
      'Road geometry appears when available. Otherwise only location pins are shown. Distance comes from the ride record.';

  @override
  String get captainRoadDistanceUnknown => 'Unavailable';

  @override
  String get captainRoadPreview => 'Preview route';

  @override
  String get invalidTripIdentifier => 'Invalid ride identifier';

  @override
  String get topupBannerTitle => '✦ Wallet top-up offer';

  @override
  String get topupBannerApproval =>
      'Your bonus is added after the transfer is verified and approved.';

  @override
  String get topupBannerOpen => 'View offer';

  @override
  String get savedLoadFailed => 'Saved places could not be loaded. Try again.';

  @override
  String get savedDeleteTitle => 'Remove from saved places?';

  @override
  String get savedBack => 'Back';

  @override
  String get savedDelete => 'Remove';

  @override
  String get savedDeleteFailed => 'The saved place could not be removed.';

  @override
  String get savedPlacesTitle => 'Your saved places';

  @override
  String get savedRefresh => 'Refresh';

  @override
  String get savedHelp =>
      'Choose a saved place, or save one using the star beside a result.';

  @override
  String get savedEmptyHelp =>
      'No saved places yet. Open a building or place and tap its star.';

  @override
  String get quickBookingTitle => 'Your next ride starts here';

  @override
  String get quickBookingSubtitle => 'Everything you need for your ride';

  @override
  String get quickBookingCoverage => 'Currently available in Hadayek Al Ahram';

  @override
  String get quickBookingService => 'Choose your service';

  @override
  String get quickCar => 'VETO Car';

  @override
  String get quickCarCaption => 'A comfortable ride';

  @override
  String get quickMotorcycle => 'VETO Motorcycle';

  @override
  String get quickMotorcycleCaption => 'A quick ride';

  @override
  String get quickPackage => 'VETO Delivery';

  @override
  String get quickPackageCaption => 'From pickup to destination';

  @override
  String get quickMarket => 'VETO Market';

  @override
  String get quickMarketCaption => 'Household shopping';

  @override
  String get demandMapTitle => 'High-demand areas';

  @override
  String get demandDirectionsFailed => 'Directions could not be opened';

  @override
  String get demandHigh => 'High demand';

  @override
  String get demandNow => 'High-demand areas now';

  @override
  String get demandExplanation =>
      'Areas with high demand or an announced fare multiplier. This map does not change the fare.';

  @override
  String get demandLower => 'Lower demand';

  @override
  String get demandUpdating => 'Updating';

  @override
  String get demandEveryMinute => 'Updates every minute';

  @override
  String get demandHigher => 'Higher demand';

  @override
  String get demandNone => 'No high-demand area right now';

  @override
  String get demandStayAvailable =>
      'Stay available. New offers will appear automatically.';

  @override
  String get demandDirections => 'Directions to area';

  @override
  String topupBannerAmount(String paid, String total) {
    return 'Pay $paid EGP and receive $total EGP';
  }

  @override
  String savedDeleteDescription(String place) {
    return 'Remove “$place” from saved places only.';
  }

  @override
  String demandMultiplier(String factor) {
    return 'Fare ×$factor';
  }

  @override
  String demandHighArea(String place) {
    return '$place • High demand';
  }

  @override
  String demandAreaMultiplier(String place, String factor) {
    return '$place • Fare ×$factor';
  }

  @override
  String demandWaiting(String count) {
    return '$count waiting requests at observation';
  }

  @override
  String demandSnapshot(String requests, String captains) {
    return 'Snapshot: $requests requests • $captains available captains';
  }

  @override
  String get savedAddTitle => 'Save a place';

  @override
  String get savedNameHint => 'Place label, for example Home or Work';

  @override
  String get savedCancel => 'Cancel';

  @override
  String get savedSave => 'Save';

  @override
  String get savedEnterLabel => 'Enter a label for this place.';

  @override
  String get changeTransferAlready =>
      'Change for this ride was already transferred with another amount';

  @override
  String get changeTransferCashOnly =>
      'Change transfer is available after a completed cash ride';

  @override
  String get changeTransferAssignedOnly =>
      'Only the assigned captain can transfer change';

  @override
  String get changeTransferFailed =>
      'Transfer failed. Retry with the same amount';

  @override
  String get changeTransferUnconfirmed =>
      'The result is unconfirmed. Retry with the same amount';

  @override
  String get changeTransferAmount => 'Change amount in EGP';

  @override
  String get changeTransferBusy => 'Transferring';

  @override
  String get changeTransferAction => 'Transfer change to wallet';

  @override
  String get changeTransferDebt => 'Settlement debt';

  @override
  String get changeTransferBalance => 'Settlement balance';

  @override
  String get changeTransferInvalidAmount =>
      'Enter a positive amount with up to two decimal places';

  @override
  String changeTransferSuccess(String amount, String kind, String balance) {
    return '$amount EGP transferred to the customer wallet. $kind: $balance EGP';
  }

  @override
  String get savedFallbackLabel => 'Saved place';

  @override
  String get savedRemoveTooltip => 'Remove from saved places';

  @override
  String get savedChooseFailed =>
      'This place could not be selected. Try again.';

  @override
  String get savedCoordinatesRequired =>
      'Valid coordinates are required to save a place.';

  @override
  String get savedAlreadyExists => 'This place is already saved.';

  @override
  String get savedAdded => 'Place saved ✓';

  @override
  String get savedAddFailed =>
      'The place could not be saved. Check connectivity and try again.';

  @override
  String get quoteRateLimited =>
      'Too many fare requests in a short time. Wait briefly and retry; your destination is retained.';

  @override
  String get quoteCoordinatesRequired =>
      'Choose pickup and destination coordinates to calculate the fare.';

  @override
  String get quoteUnavailableRetry =>
      'Fare calculation is unavailable right now. Retry without selecting your addresses again.';

  @override
  String get compareServicePrices => 'Compare service fares';

  @override
  String get viewServiceFare => 'View fare';

  @override
  String get bookingProgressRoute => 'Route';

  @override
  String get bookingProgressService => 'Service';

  @override
  String get bookingProgressConfirm => 'Confirm';

  @override
  String get bookingProgressSearch => 'Search';

  @override
  String get captainLocationServiceRequired =>
      'Turn on location services to receive rides';

  @override
  String get captainLocationPermissionTitle => 'Location permission';

  @override
  String get captainLocationPermissionBody =>
      'Allow location while using the app to receive rides.';

  @override
  String get captainLocationLater => 'Later';

  @override
  String get expandBooking => 'Show booking options';

  @override
  String get collapseBooking => 'Collapse booking panel';

  @override
  String get earnedRideDiscount => 'A discount is available for this ride';

  @override
  String earnedRideSaving(String amount) {
    return 'Save $amount with your eligible offer. The server confirms the final amount.';
  }

  @override
  String get earnedRideTerms =>
      'Eligibility and expiry follow the offer terms.';

  @override
  String get earnedRideSkipped =>
      'Discount not selected. Review the total before confirming.';

  @override
  String get suggestedFareTitle => 'We are still looking for a captain';

  @override
  String get suggestedFareHelp =>
      'Keep your current price or choose the suggested price. You can cancel the search before a captain accepts.';

  @override
  String suggestedFareValue(String amount) {
    return 'Suggested price: EGP $amount';
  }

  @override
  String get keepCurrentFare => 'Keep current price';

  @override
  String get useSuggestedFare => 'Use suggested price';

  @override
  String get confirmingRequest => 'Confirming your request…';

  @override
  String searchElapsed(String time) {
    return 'Search time: $time';
  }

  @override
  String get searchCancelFree =>
      'Search cancellation is free before a captain accepts';

  @override
  String get bookingTotal => 'Ride total';

  @override
  String get changePayment => 'Choose payment method';

  @override
  String get captainJoinTitle => 'Drive with VETO';

  @override
  String get captainApplyAction => 'Apply as a captain';

  @override
  String get captainBadgeTitle => 'Your badge and referrals';

  @override
  String get captainCodeLoading => 'Loading your code…';

  @override
  String get captainCodeFailed => 'Code unavailable. Refresh to retry.';

  @override
  String get captainCodeUnavailable =>
      'Your code is unavailable or the campaign is paused';

  @override
  String get captainCodeRefresh => 'Refresh code and statistics';

  @override
  String get referralRegistrations => 'Signed up with your code';

  @override
  String get referralQualified => 'Completed a ride';

  @override
  String get referralPending => 'Awaiting qualification';

  @override
  String get referralDue => 'Due (EGP)';

  @override
  String get referralPaid => 'Paid (EGP)';

  @override
  String get badgeActive => 'Badge activated';

  @override
  String get badgePending => 'Badge awaiting administration activation';

  @override
  String badgeTeam(String value) {
    return 'Team: $value';
  }

  @override
  String get noLinkedTeam => 'Not linked';

  @override
  String get badgeMetricsUnavailable =>
      'Statistics are unavailable. Refresh to retry; estimates are not displayed.';

  @override
  String get badgePrintAction => 'Print your badge with your code and QR';

  @override
  String get badgeDetailsAction => 'Referral and offer details';

  @override
  String get badgeMetricsSource =>
      'Counts and rewards come from your account, not QR views.';

  @override
  String get badgeMenuAction => 'Invitation codes and badge earnings';

  @override
  String get currentPickup => 'My current location';

  @override
  String get welcomeNameInvalid => 'Enter a name with 2 to 80 characters.';

  @override
  String get welcomeCodeUnavailable =>
      'You can enter a code, but activation is paused or unavailable for this account. No discount is granted before server confirmation. You can continue without a code.';

  @override
  String get welcomeConfirmFailed =>
      'The server could not confirm this code. No gift has been granted. Check your connection and invitation before retrying.';

  @override
  String homeReferralSaving(String value) {
    return 'You have a $value% discount 🎁';
  }

  @override
  String homeCreditSaving(String value) {
    return 'You have EGP $value in rewards 🎁';
  }

  @override
  String get homeReferralSavingHelp =>
      'Use your offer on an eligible ride. Savings appear after choosing your route.';

  @override
  String get homeCreditSavingHelp =>
      'Use your invitation credit on an eligible ride after reviewing the quote.';

  @override
  String get menuWelcome => 'Your journey starts here';

  @override
  String get menuProfile => 'My profile';

  @override
  String get menuTrips => 'My trips and orders';

  @override
  String get menuWallet => 'My wallet';

  @override
  String get menuOffers => 'Offers and discounts';

  @override
  String get menuInvite => 'Invite friends';

  @override
  String get menuNews => 'VETO news';

  @override
  String get menuHelp => 'Help and complaints';

  @override
  String get menuSafety => 'Safety';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuLegal => 'Terms and privacy';

  @override
  String get menuCaptainApply => 'Drive with VETO SANYA';

  @override
  String get menuCaptainMode => 'Open captain mode';

  @override
  String get menuAccountTools => 'Account, partners and team';

  @override
  String get menuLogout => 'Sign out';

  @override
  String get menuNoAddresses =>
      'No saved places yet. Save an address when choosing a location.';

  @override
  String get menuAddressSuggestions => 'My address suggestions';

  @override
  String get homeActiveOrder => 'Track your current order';

  @override
  String get homePickupHint => 'Pickup point';

  @override
  String get authWelcomeV2 => 'Welcome to VETO SANYA';

  @override
  String get authPhoneHintV2 => 'Enter your mobile number to get started';

  @override
  String get gameTitle => 'Ring Road Driver';

  @override
  String get gamePlay => 'Play while you wait';

  @override
  String get gameStart => 'Let’s drive';

  @override
  String get gameResume => 'Resume checkpoint';

  @override
  String get gameRestart => 'Start again';

  @override
  String get gamePause => 'Pause';

  @override
  String get gameContinue => 'Continue driving';

  @override
  String get gameGarage => 'Choose your car';

  @override
  String get gameName => 'Car nickname (optional)';

  @override
  String get gameNicknameHint => 'Karim’s car';

  @override
  String get gameSedan => 'Small sedan';

  @override
  String get gameTaxi => 'Taxi';

  @override
  String get gameSuv => 'SUV';

  @override
  String get gameSport => 'Sporty compact';

  @override
  String get gameGold => 'Gold';

  @override
  String get gameWhite => 'White';

  @override
  String get gameBlack => 'Black';

  @override
  String get gameBlue => 'Blue';

  @override
  String get gameRed => 'Red';

  @override
  String get gameGreen => 'Green';

  @override
  String get gameLeft => 'Left';

  @override
  String get gameRight => 'Right';

  @override
  String get gameSound => 'Game sound';

  @override
  String get gameMuted => 'Sound off';

  @override
  String get gameDistance => 'Distance';

  @override
  String get gameBest => 'Best score';

  @override
  String get gameScore => 'Score';

  @override
  String get gameExit => 'Return to your request';

  @override
  String get gamePersonalExit => 'Close game';

  @override
  String get gameSaved => 'Progress is saved on this device for your account';

  @override
  String get gameSaveFailed =>
      'Unable to save progress on this device right now';

  @override
  String get gameWaiting =>
      'Captain matching is still running. Your trip comes first.';

  @override
  String get gameCrash1 => 'Easy, driver! We might need a tow 😂';

  @override
  String get gameCrash2 => 'Steady! This car is still new!';

  @override
  String get gameCrash3 => 'Stay in your lane, driver!';

  @override
  String get gameDodge => 'Nice driving!';

  @override
  String get gamePaused => 'Take a break. Continue when you are ready.';

  @override
  String get gameEntertainment =>
      'For fun only. Points are not money or wallet credit.';

  @override
  String get gameNotReady => 'Getting your car ready…';

  @override
  String get bannerPosition => 'Offer';

  @override
  String get bannerPrevious => 'Previous offer';

  @override
  String get bannerNext => 'Next offer';

  @override
  String get authResendV2 => 'Check verification request again';

  @override
  String get authRequestPendingV2 =>
      'Your request is pending. The verification team will provide the code.';

  @override
  String get authPhoneLabelV2 => 'Mobile number';

  @override
  String get draftUnavailableV2 =>
      'Unable to save the draft on this device right now.';
}
