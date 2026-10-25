import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'Use device settings'**
  String get system;

  /// No description provided for @preferenceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Your setting could not be saved. Please try again.'**
  String get preferenceSaveFailed;

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @changeAddress.
  ///
  /// In en, this message translates to:
  /// **'Change address'**
  String get changeAddress;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get work;

  /// No description provided for @savedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get savedPlaces;

  /// No description provided for @recentPlaces.
  ///
  /// In en, this message translates to:
  /// **'Recent destinations'**
  String get recentPlaces;

  /// No description provided for @useLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useLocation;

  /// No description provided for @choosePickup.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup location'**
  String get choosePickup;

  /// No description provided for @chooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get chooseDestination;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Choose a service'**
  String get services;

  /// No description provided for @car.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get car;

  /// No description provided for @motorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get motorcycle;

  /// No description provided for @tukTuk.
  ///
  /// In en, this message translates to:
  /// **'Tuk-tuk'**
  String get tukTuk;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @confirmRide.
  ///
  /// In en, this message translates to:
  /// **'Confirm ride'**
  String get confirmRide;

  /// No description provided for @viewFare.
  ///
  /// In en, this message translates to:
  /// **'See fare'**
  String get viewFare;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Looking for a nearby captain'**
  String get searching;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get price;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Available offers'**
  String get offers;

  /// No description provided for @suggestAddress.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find your area or building?'**
  String get suggestAddress;

  /// No description provided for @suggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest an address'**
  String get suggestionTitle;

  /// No description provided for @suggestionInfo.
  ///
  /// In en, this message translates to:
  /// **'This is a private suggestion for review. It does not enable rides in an unsupported city.'**
  String get suggestionInfo;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @area.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get area;

  /// No description provided for @buildingLetter.
  ///
  /// In en, this message translates to:
  /// **'Building letter (optional)'**
  String get buildingLetter;

  /// No description provided for @buildingNumber.
  ///
  /// In en, this message translates to:
  /// **'Building number'**
  String get buildingNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address description'**
  String get address;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Additional note'**
  String get note;

  /// No description provided for @sendReview.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get sendReview;

  /// No description provided for @mySuggestions.
  ///
  /// In en, this message translates to:
  /// **'My address suggestions'**
  String get mySuggestions;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get pending;

  /// No description provided for @needsInformation.
  ///
  /// In en, this message translates to:
  /// **'More information needed'**
  String get needsInformation;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @suggestionSent.
  ///
  /// In en, this message translates to:
  /// **'Your suggestion was sent for review.'**
  String get suggestionSent;

  /// No description provided for @suggestionRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Please wait a minute before sending another suggestion.'**
  String get suggestionRateLimit;

  /// No description provided for @suggestionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the address details and select a valid location.'**
  String get suggestionInvalid;

  /// No description provided for @suggestionCityMismatch.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct city for this address.'**
  String get suggestionCityMismatch;

  /// No description provided for @suggestionFailed.
  ///
  /// In en, this message translates to:
  /// **'The suggestion could not be confirmed. Check its status or retry with the same details. Your ride and wallet were unchanged.'**
  String get suggestionFailed;

  /// No description provided for @locationUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Selected location — confirm the address or add a description.'**
  String get locationUnconfirmed;

  /// No description provided for @gpsPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow location access, or choose an address manually.'**
  String get gpsPermission;

  /// No description provided for @gpsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. You can choose an address manually.'**
  String get gpsDisabled;

  /// No description provided for @gpsFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t obtain a reliable location. Choose an address manually or try again.'**
  String get gpsFailed;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countrySearch.
  ///
  /// In en, this message translates to:
  /// **'Search country or calling code'**
  String get countrySearch;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number for the selected country.'**
  String get phoneInvalid;

  /// No description provided for @verificationRequest.
  ///
  /// In en, this message translates to:
  /// **'A verification code will be sent through the existing WhatsApp verification service.'**
  String get verificationRequest;

  /// No description provided for @bookingCreated.
  ///
  /// In en, this message translates to:
  /// **'Your ride request was created'**
  String get bookingCreated;

  /// No description provided for @captainAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Captain acceptance'**
  String get captainAcceptance;

  /// No description provided for @rideDuration.
  ///
  /// In en, this message translates to:
  /// **'Trip duration'**
  String get rideDuration;

  /// No description provided for @noReliableEstimate.
  ///
  /// In en, this message translates to:
  /// **'Searching — no reliable time estimate yet'**
  String get noReliableEstimate;

  /// No description provided for @optionalOffer.
  ///
  /// In en, this message translates to:
  /// **'You can increase your offer if you wish.'**
  String get optionalOffer;

  /// No description provided for @higherOfferHelp.
  ///
  /// In en, this message translates to:
  /// **'A higher offer may interest more captains. Acceptance is not guaranteed.'**
  String get higherOfferHelp;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'VETO Market'**
  String get market;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhone;

  /// No description provided for @requestCode.
  ///
  /// In en, this message translates to:
  /// **'Request verification code via WhatsApp'**
  String get requestCode;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t submit the verification request. Please try again.'**
  String get verificationFailed;

  /// No description provided for @internationalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Verification is not available for this country yet. Choose a supported country.'**
  String get internationalUnavailable;

  /// No description provided for @preferencesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your saved settings couldn\'t be restored. Choose your language and appearance again.'**
  String get preferencesLoadFailed;

  /// No description provided for @offersDelivered.
  ///
  /// In en, this message translates to:
  /// **'Offers created'**
  String get offersDelivered;

  /// No description provided for @deliveredSearchRadius.
  ///
  /// In en, this message translates to:
  /// **'Last offer radius'**
  String get deliveredSearchRadius;

  /// No description provided for @continueConsent.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to'**
  String get continueConsent;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get terms;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacy;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get evening;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get currency;

  /// No description provided for @specialOffer.
  ///
  /// In en, this message translates to:
  /// **'Available offer'**
  String get specialOffer;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book now'**
  String get bookNow;

  /// No description provided for @openMarket.
  ///
  /// In en, this message translates to:
  /// **'Open VETO Market'**
  String get openMarket;

  /// No description provided for @offersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Offers could not be loaded. You can still book a ride.'**
  String get offersUnavailable;

  /// No description provided for @findingLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get findingLocation;

  /// No description provided for @chooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose your pickup location'**
  String get chooseLocation;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected location'**
  String get selectedLocation;

  /// No description provided for @bookingGuide.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup and destination, then review the fare before confirming. Save frequent addresses for faster booking.'**
  String get bookingGuide;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get understood;

  /// No description provided for @suggestionReplay.
  ///
  /// In en, this message translates to:
  /// **'The previous submission may have reached the server. Retry with the same details to check its receipt.'**
  String get suggestionReplay;

  /// No description provided for @emptySuggestions.
  ///
  /// In en, this message translates to:
  /// **'No address suggestions yet.'**
  String get emptySuggestions;

  /// No description provided for @addressSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Address search is unavailable. Choose a saved address or a pin, or try again.'**
  String get addressSearchFailed;

  /// No description provided for @quoteFailed.
  ///
  /// In en, this message translates to:
  /// **'The server could not confirm the fare. Please try again.'**
  String get quoteFailed;

  /// No description provided for @routeDisplayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Road route preview is unavailable. Pickup and destination pins remain accurate.'**
  String get routeDisplayUnavailable;

  /// No description provided for @accountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account or active ride could not be refreshed. Retry before relying on these details.'**
  String get accountLoadFailed;

  /// No description provided for @marketLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your market order status could not be loaded. Ride booking is still available.'**
  String get marketLoadFailed;

  /// No description provided for @correctSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Correct details'**
  String get correctSuggestion;

  /// No description provided for @uiea5f73b8.
  ///
  /// In en, this message translates to:
  /// **'Your location is unavailable. Choose a pin on the map.'**
  String get uiea5f73b8;

  /// No description provided for @ui4e3d1712.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get ui4e3d1712;

  /// No description provided for @ui396197d7.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid destination first.'**
  String get ui396197d7;

  /// No description provided for @uia8d53c82.
  ///
  /// In en, this message translates to:
  /// **'The server could not confirm the fare. Please try again.'**
  String get uia8d53c82;

  /// No description provided for @uic32397f1.
  ///
  /// In en, this message translates to:
  /// **'No valid fare is available.'**
  String get uic32397f1;

  /// No description provided for @ui44a70a8d.
  ///
  /// In en, this message translates to:
  /// **'Choose a pickup with valid coordinates.'**
  String get ui44a70a8d;

  /// No description provided for @ui2c00f52f.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination with valid coordinates.'**
  String get ui2c00f52f;

  /// No description provided for @ui2beacbfd.
  ///
  /// In en, this message translates to:
  /// **'You already have an active ride.'**
  String get ui2beacbfd;

  /// No description provided for @ui70e7a8c0.
  ///
  /// In en, this message translates to:
  /// **'Your active ride could not be checked.'**
  String get ui70e7a8c0;

  /// No description provided for @ui41f09900.
  ///
  /// In en, this message translates to:
  /// **'Choose your service'**
  String get ui41f09900;

  /// No description provided for @uia3ac6d76.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get uia3ac6d76;

  /// No description provided for @ui7fc5c5dd.
  ///
  /// In en, this message translates to:
  /// **'Review and confirm your ride'**
  String get ui7fc5c5dd;

  /// No description provided for @ui09e60c0f.
  ///
  /// In en, this message translates to:
  /// **'Choose service and fare'**
  String get ui09e60c0f;

  /// No description provided for @ui56807a6f.
  ///
  /// In en, this message translates to:
  /// **'Choose your offer'**
  String get ui56807a6f;

  /// No description provided for @uib075cda8.
  ///
  /// In en, this message translates to:
  /// **'Ride details'**
  String get uib075cda8;

  /// No description provided for @ui3c6518b4.
  ///
  /// In en, this message translates to:
  /// **'Searching for a captain'**
  String get ui3c6518b4;

  /// No description provided for @ui07676a93.
  ///
  /// In en, this message translates to:
  /// **'Captain offers'**
  String get ui07676a93;

  /// No description provided for @uic714374d.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get uic714374d;

  /// No description provided for @ui74cafc32.
  ///
  /// In en, this message translates to:
  /// **'Place categories could not be loaded. Try again.'**
  String get ui74cafc32;

  /// No description provided for @ui15cd2781.
  ///
  /// In en, this message translates to:
  /// **'Registered places could not be loaded.'**
  String get ui15cd2781;

  /// No description provided for @ui02609bec.
  ///
  /// In en, this message translates to:
  /// **'Buildings in this area could not be loaded.'**
  String get ui02609bec;

  /// No description provided for @ui5c6fddf6.
  ///
  /// In en, this message translates to:
  /// **'Choose your area letter first to find the correct building.'**
  String get ui5c6fddf6;

  /// No description provided for @uiec4369bc.
  ///
  /// In en, this message translates to:
  /// **'Enter a building number from 1 to 590.'**
  String get uiec4369bc;

  /// No description provided for @ui39c9c0fc.
  ///
  /// In en, this message translates to:
  /// **'Building search is unavailable.'**
  String get ui39c9c0fc;

  /// No description provided for @ui2acdce12.
  ///
  /// In en, this message translates to:
  /// **'Selected map location'**
  String get ui2acdce12;

  /// No description provided for @ui0282b8e7.
  ///
  /// In en, this message translates to:
  /// **'This place has no verified coordinates.'**
  String get ui0282b8e7;

  /// No description provided for @ui46d9c9af.
  ///
  /// In en, this message translates to:
  /// **'Registered place'**
  String get ui46d9c9af;

  /// No description provided for @ui5f74518a.
  ///
  /// In en, this message translates to:
  /// **'This building has no verified coordinates.'**
  String get ui5f74518a;

  /// No description provided for @ui3ccabf1f.
  ///
  /// In en, this message translates to:
  /// **'Choose the area letter in the highlighted field first.'**
  String get ui3ccabf1f;

  /// No description provided for @ui8e451470.
  ///
  /// In en, this message translates to:
  /// **'Enter a building number from 1 to 590, then select Add.'**
  String get ui8e451470;

  /// No description provided for @ui5dd6c786.
  ///
  /// In en, this message translates to:
  /// **'This ride will use your selected location. The building becomes public only after review.'**
  String get ui5dd6c786;

  /// No description provided for @ui91aff234.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup location'**
  String get ui91aff234;

  /// No description provided for @ui5bdfac2b.
  ///
  /// In en, this message translates to:
  /// **'Your location, a building, or a saved place'**
  String get ui5bdfac2b;

  /// No description provided for @uia1f24fc1.
  ///
  /// In en, this message translates to:
  /// **'Choose city'**
  String get uia1f24fc1;

  /// No description provided for @uiaae85882.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get uiaae85882;

  /// No description provided for @ui0ecb38c0.
  ///
  /// In en, this message translates to:
  /// **'Choose a pin on the map'**
  String get ui0ecb38c0;

  /// No description provided for @ui4960a634.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get ui4960a634;

  /// No description provided for @uib5d1d3fe.
  ///
  /// In en, this message translates to:
  /// **'Area letter and building number'**
  String get uib5d1d3fe;

  /// No description provided for @ui947ac162.
  ///
  /// In en, this message translates to:
  /// **'Known place'**
  String get ui947ac162;

  /// No description provided for @ui92c0fd35.
  ///
  /// In en, this message translates to:
  /// **'A registered gate, restaurant, school, or landmark'**
  String get ui92c0fd35;

  /// No description provided for @ui9f290894.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get ui9f290894;

  /// No description provided for @uiefe7950f.
  ///
  /// In en, this message translates to:
  /// **'Home, work, or a place you saved'**
  String get uiefe7950f;

  /// No description provided for @uif36f493e.
  ///
  /// In en, this message translates to:
  /// **'Change address type'**
  String get uif36f493e;

  /// No description provided for @ui72de3382.
  ///
  /// In en, this message translates to:
  /// **'Saved place'**
  String get ui72de3382;

  /// No description provided for @ui5c204281.
  ///
  /// In en, this message translates to:
  /// **'Landmark or pickup note (optional)'**
  String get ui5c204281;

  /// No description provided for @uifad68bbd.
  ///
  /// In en, this message translates to:
  /// **'For example, by the side gate'**
  String get uifad68bbd;

  /// No description provided for @ui19896675.
  ///
  /// In en, this message translates to:
  /// **'No registered places in this category yet.'**
  String get ui19896675;

  /// No description provided for @uiae7ae56d.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get uiae7ae56d;

  /// No description provided for @uie0d502ff.
  ///
  /// In en, this message translates to:
  /// **'Choose area'**
  String get uie0d502ff;

  /// No description provided for @uieca4806f.
  ///
  /// In en, this message translates to:
  /// **'Building number'**
  String get uieca4806f;

  /// No description provided for @ui7af87c25.
  ///
  /// In en, this message translates to:
  /// **'For example: 125'**
  String get ui7af87c25;

  /// No description provided for @ui99bef41e.
  ///
  /// In en, this message translates to:
  /// **'This number was not found. You can suggest the building location below.'**
  String get ui99bef41e;

  /// No description provided for @ui23e4b967.
  ///
  /// In en, this message translates to:
  /// **'No registered buildings in this area yet.'**
  String get ui23e4b967;

  /// No description provided for @ui09d5b8ff.
  ///
  /// In en, this message translates to:
  /// **'Enter a building number to search.'**
  String get ui09d5b8ff;

  /// No description provided for @ui42ebe4b5.
  ///
  /// In en, this message translates to:
  /// **'Select your building from the results'**
  String get ui42ebe4b5;

  /// No description provided for @ui6b9fed40.
  ///
  /// In en, this message translates to:
  /// **'Finish entering the number to find the correct building.'**
  String get ui6b9fed40;

  /// No description provided for @uifc5bae31.
  ///
  /// In en, this message translates to:
  /// **'Cannot find your building?'**
  String get uifc5bae31;

  /// No description provided for @ui8616aae5.
  ///
  /// In en, this message translates to:
  /// **'Suggest your building on the map for review.'**
  String get ui8616aae5;

  /// No description provided for @uibff694c6.
  ///
  /// In en, this message translates to:
  /// **'Save this place'**
  String get uibff694c6;

  /// No description provided for @ui85c938bf.
  ///
  /// In en, this message translates to:
  /// **'Save this building'**
  String get ui85c938bf;

  /// No description provided for @ui700ee7bb.
  ///
  /// In en, this message translates to:
  /// **'Choose a building with verified coordinates.'**
  String get ui700ee7bb;

  /// No description provided for @ui566d62bb.
  ///
  /// In en, this message translates to:
  /// **'Your pickup has no coordinates. Choose it from registered places or the map.'**
  String get ui566d62bb;

  /// No description provided for @uib70a4633.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get uib70a4633;

  /// No description provided for @ui42f90d2d.
  ///
  /// In en, this message translates to:
  /// **'Choose on map'**
  String get ui42f90d2d;

  /// No description provided for @ui3d03e800.
  ///
  /// In en, this message translates to:
  /// **'Place the pin yourself'**
  String get ui3d03e800;

  /// No description provided for @ui2a038421.
  ///
  /// In en, this message translates to:
  /// **'Building in Hadayek Al Ahram'**
  String get ui2a038421;

  /// No description provided for @ui018f341c.
  ///
  /// In en, this message translates to:
  /// **'Choose the area or search by building number'**
  String get ui018f341c;

  /// No description provided for @ui4f301aa9.
  ///
  /// In en, this message translates to:
  /// **'A registered gate, bank, restaurant, school, or mosque'**
  String get ui4f301aa9;

  /// No description provided for @uie2a404ff.
  ///
  /// In en, this message translates to:
  /// **'Choose home, work, or a saved address'**
  String get uie2a404ff;

  /// No description provided for @uif8b22ed8.
  ///
  /// In en, this message translates to:
  /// **'Another city or area'**
  String get uif8b22ed8;

  /// No description provided for @ui955024f3.
  ///
  /// In en, this message translates to:
  /// **'Search for the place or choose it on the map'**
  String get ui955024f3;

  /// No description provided for @ui1e33ffb8.
  ///
  /// In en, this message translates to:
  /// **'Search by city or place name, then choose the result.'**
  String get ui1e33ffb8;

  /// No description provided for @ui5ed8eb3d.
  ///
  /// In en, this message translates to:
  /// **'For example: Downtown, Alexandria, Ain Sokhna'**
  String get ui5ed8eb3d;

  /// No description provided for @uidde5f7a4.
  ///
  /// In en, this message translates to:
  /// **'For example: Downtown or a place name'**
  String get uidde5f7a4;

  /// No description provided for @uib8818d2d.
  ///
  /// In en, this message translates to:
  /// **'No matching places were found.'**
  String get uib8818d2d;

  /// No description provided for @ui90754ad6.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get ui90754ad6;

  /// No description provided for @uide6f5aba.
  ///
  /// In en, this message translates to:
  /// **'1. Select your area letter in the highlighted field'**
  String get uide6f5aba;

  /// No description provided for @ui9ba6e611.
  ///
  /// In en, this message translates to:
  /// **'2. Enter your building number, then select its card'**
  String get ui9ba6e611;

  /// No description provided for @ui498edaea.
  ///
  /// In en, this message translates to:
  /// **'No building with this number was found.'**
  String get ui498edaea;

  /// No description provided for @ui533b3b9d.
  ///
  /// In en, this message translates to:
  /// **'Enter the building number to see results here.'**
  String get ui533b3b9d;

  /// No description provided for @ui5d77e042.
  ///
  /// In en, this message translates to:
  /// **'Select a destination card below to calculate the server fare.'**
  String get ui5d77e042;

  /// No description provided for @uibc40c997.
  ///
  /// In en, this message translates to:
  /// **'This code has expired'**
  String get uibc40c997;

  /// No description provided for @ui327c8f24.
  ///
  /// In en, this message translates to:
  /// **'This offer has not started'**
  String get ui327c8f24;

  /// No description provided for @uif628612e.
  ///
  /// In en, this message translates to:
  /// **'This code is currently disabled'**
  String get uif628612e;

  /// No description provided for @ui9b548771.
  ///
  /// In en, this message translates to:
  /// **'The code usage limit has been reached'**
  String get ui9b548771;

  /// No description provided for @uiab945993.
  ///
  /// In en, this message translates to:
  /// **'The offer has reached its customer limit'**
  String get uiab945993;

  /// No description provided for @ui312fca54.
  ///
  /// In en, this message translates to:
  /// **'You have reached your usage limit for this code'**
  String get ui312fca54;

  /// No description provided for @uidf40e49a.
  ///
  /// In en, this message translates to:
  /// **'This offer needs review'**
  String get uidf40e49a;

  /// No description provided for @ui3b3d074b.
  ///
  /// In en, this message translates to:
  /// **'No discount is available for this ride'**
  String get ui3b3d074b;

  /// No description provided for @ui2dcb22b8.
  ///
  /// In en, this message translates to:
  /// **'Sign in with an active customer account'**
  String get ui2dcb22b8;

  /// No description provided for @ui28fd5fd3.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Please try again'**
  String get ui28fd5fd3;

  /// No description provided for @uia73828a5.
  ///
  /// In en, this message translates to:
  /// **'This code is invalid or unavailable'**
  String get uia73828a5;

  /// No description provided for @uidd00b654.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get uidd00b654;

  /// No description provided for @uia7947509.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get uia7947509;

  /// No description provided for @ui45a9a436.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get ui45a9a436;

  /// No description provided for @uid219bc19.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get uid219bc19;

  /// No description provided for @ui84c7eeb2.
  ///
  /// In en, this message translates to:
  /// **'Expected purchase amount — optional'**
  String get ui84c7eeb2;

  /// No description provided for @ui1881ccb3.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get ui1881ccb3;

  /// No description provided for @ui898cec70.
  ///
  /// In en, this message translates to:
  /// **'Pay the captain in cash'**
  String get ui898cec70;

  /// No description provided for @uidf1727d8.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get uidf1727d8;

  /// No description provided for @ui92215af2.
  ///
  /// In en, this message translates to:
  /// **'Wallet + cash'**
  String get ui92215af2;

  /// No description provided for @ui8b068efc.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get ui8b068efc;

  /// No description provided for @ui69cb4d81.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get ui69cb4d81;

  /// No description provided for @uid1588f9b.
  ///
  /// In en, this message translates to:
  /// **'Wallet + cash'**
  String get uid1588f9b;

  /// No description provided for @uiff8a5dd1.
  ///
  /// In en, this message translates to:
  /// **'Transport fare'**
  String get uiff8a5dd1;

  /// No description provided for @ui87369f01.
  ///
  /// In en, this message translates to:
  /// **'Added incentive'**
  String get ui87369f01;

  /// No description provided for @uif28e3f71.
  ///
  /// In en, this message translates to:
  /// **'Previous amount due'**
  String get uif28e3f71;

  /// No description provided for @uib593a645.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get uib593a645;

  /// No description provided for @uif918ebca.
  ///
  /// In en, this message translates to:
  /// **'Total after discount'**
  String get uif918ebca;

  /// No description provided for @ui70cc122a.
  ///
  /// In en, this message translates to:
  /// **'Paid from wallet'**
  String get ui70cc122a;

  /// No description provided for @ui741126d6.
  ///
  /// In en, this message translates to:
  /// **'No registered places near your available location'**
  String get ui741126d6;

  /// No description provided for @ui228e7f21.
  ///
  /// In en, this message translates to:
  /// **'Nearby places'**
  String get ui228e7f21;

  /// No description provided for @uif51ac3a9.
  ///
  /// In en, this message translates to:
  /// **'Previous amount due'**
  String get uif51ac3a9;

  /// No description provided for @uid7788534.
  ///
  /// In en, this message translates to:
  /// **'Services available for this route'**
  String get uid7788534;

  /// No description provided for @uicb6c9e7d.
  ///
  /// In en, this message translates to:
  /// **'Transport fare before incentive, discount and previous due'**
  String get uicb6c9e7d;

  /// No description provided for @uid8019644.
  ///
  /// In en, this message translates to:
  /// **'Continue to discount and payment'**
  String get uid8019644;

  /// No description provided for @ui1dc14005.
  ///
  /// In en, this message translates to:
  /// **'The first eligible captain to accept is assigned automatically.'**
  String get ui1dc14005;

  /// No description provided for @ui4c324b17.
  ///
  /// In en, this message translates to:
  /// **'Start your request'**
  String get ui4c324b17;

  /// No description provided for @uia06d487b.
  ///
  /// In en, this message translates to:
  /// **'Where will we pick you up?'**
  String get uia06d487b;

  /// No description provided for @ui94709dd1.
  ///
  /// In en, this message translates to:
  /// **'Review request'**
  String get ui94709dd1;

  /// No description provided for @ui194ae5ca.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get ui194ae5ca;

  /// No description provided for @ui595241dd.
  ///
  /// In en, this message translates to:
  /// **'Captain offers received'**
  String get ui595241dd;

  /// No description provided for @ui674f7a10.
  ///
  /// In en, this message translates to:
  /// **'Choose a service to continue.'**
  String get ui674f7a10;

  /// No description provided for @ui5acaa87e.
  ///
  /// In en, this message translates to:
  /// **'Your current location or another pickup'**
  String get ui5acaa87e;

  /// No description provided for @ui4ef558e7.
  ///
  /// In en, this message translates to:
  /// **'Search for a place or select a map pin'**
  String get ui4ef558e7;

  /// No description provided for @uice4a26ca.
  ///
  /// In en, this message translates to:
  /// **'Choose a service and confirm'**
  String get uice4a26ca;

  /// No description provided for @uiacd55510.
  ///
  /// In en, this message translates to:
  /// **'Your request is registered. We will notify you when a captain accepts. You can refresh its status.'**
  String get uiacd55510;

  /// No description provided for @uib3a04740.
  ///
  /// In en, this message translates to:
  /// **'Captain offers are available. Follow your ride here.'**
  String get uib3a04740;

  /// No description provided for @ui728e6087.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get ui728e6087;

  /// No description provided for @ui4d7d679f.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get ui4d7d679f;

  /// No description provided for @ui97fe3fe5.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get ui97fe3fe5;

  /// No description provided for @ui8d0a03c3.
  ///
  /// In en, this message translates to:
  /// **'Estimated fare'**
  String get ui8d0a03c3;

  /// No description provided for @uib43afc26.
  ///
  /// In en, this message translates to:
  /// **'Your ride, made simple.'**
  String get uib43afc26;

  /// No description provided for @uicb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get uicb822418;

  /// No description provided for @ui8f7d74ac.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get ui8f7d74ac;

  /// No description provided for @ui8a440ee4.
  ///
  /// In en, this message translates to:
  /// **'Package weight (kg)'**
  String get ui8a440ee4;

  /// No description provided for @uif11b8c52.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get uif11b8c52;

  /// No description provided for @ui268974da.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get ui268974da;

  /// No description provided for @ui18a707e2.
  ///
  /// In en, this message translates to:
  /// **'Note for captain (optional)'**
  String get ui18a707e2;

  /// No description provided for @ui49acfce8.
  ///
  /// In en, this message translates to:
  /// **'For example: call on arrival, or use the rear gate'**
  String get ui49acfce8;

  /// No description provided for @uiae2d6005.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get uiae2d6005;

  /// No description provided for @uic6e5c7c6.
  ///
  /// In en, this message translates to:
  /// **'Balance does not cover the full total'**
  String get uic6e5c7c6;

  /// No description provided for @ui5dbd6c30.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance, then the rest in cash'**
  String get ui5dbd6c30;

  /// No description provided for @ui16372d11.
  ///
  /// In en, this message translates to:
  /// **'No wallet balance'**
  String get ui16372d11;

  /// No description provided for @ui18c40f92.
  ///
  /// In en, this message translates to:
  /// **'Cash to pay the captain'**
  String get ui18c40f92;

  /// No description provided for @ui216376e1.
  ///
  /// In en, this message translates to:
  /// **'Remaining payment'**
  String get ui216376e1;

  /// No description provided for @uia39f7a83.
  ///
  /// In en, this message translates to:
  /// **'Confirm and request ride'**
  String get uia39f7a83;

  /// No description provided for @ui5164d8be.
  ///
  /// In en, this message translates to:
  /// **'Payment summary'**
  String get ui5164d8be;

  /// No description provided for @ui68881282.
  ///
  /// In en, this message translates to:
  /// **'Including discount, previous due and wallet payment'**
  String get ui68881282;

  /// No description provided for @uid6c3b867.
  ///
  /// In en, this message translates to:
  /// **'Remaining payment'**
  String get uid6c3b867;

  /// No description provided for @ui8fb9853e.
  ///
  /// In en, this message translates to:
  /// **'Cash to pay the captain'**
  String get ui8fb9853e;

  /// No description provided for @ui032bb56d.
  ///
  /// In en, this message translates to:
  /// **'Fully paid from wallet'**
  String get ui032bb56d;

  /// No description provided for @currencyShort.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get currencyShort;

  /// No description provided for @moneyValue.
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String moneyValue(String amount);

  /// No description provided for @distanceValue.
  ///
  /// In en, this message translates to:
  /// **'{amount} km'**
  String distanceValue(String amount);

  /// No description provided for @durationValue.
  ///
  /// In en, this message translates to:
  /// **'{amount} min'**
  String durationValue(String amount);

  /// No description provided for @promoAppliedValue.
  ///
  /// In en, this message translates to:
  /// **'Applied discount: {amount} EGP'**
  String promoAppliedValue(String amount);

  /// No description provided for @previousDueNotice.
  ///
  /// In en, this message translates to:
  /// **'{reason}: {amount} EGP will be added to this ride'**
  String previousDueNotice(String reason, String amount);

  /// No description provided for @paymentSummary.
  ///
  /// In en, this message translates to:
  /// **'Payment method: {method}'**
  String paymentSummary(String method);

  /// No description provided for @walletPaymentSummary.
  ///
  /// In en, this message translates to:
  /// **'Payment: {method} — {amount} EGP from wallet'**
  String walletPaymentSummary(String method, String amount);

  /// No description provided for @walletRemaining.
  ///
  /// In en, this message translates to:
  /// **'Estimated wallet balance after booking: {amount} EGP'**
  String walletRemaining(String amount);

  /// No description provided for @foundPickup.
  ///
  /// In en, this message translates to:
  /// **'Your pickup: {address}'**
  String foundPickup(String address);

  /// No description provided for @flowStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String flowStep(int step, int total);

  /// No description provided for @buildingName.
  ///
  /// In en, this message translates to:
  /// **'Building {number}'**
  String buildingName(String number);

  /// No description provided for @areaBuilding.
  ///
  /// In en, this message translates to:
  /// **'Area {area} - building {number}'**
  String areaBuilding(String area, String number);

  /// No description provided for @fromPickup.
  ///
  /// In en, this message translates to:
  /// **'From: {address}'**
  String fromPickup(String address);

  /// No description provided for @account9193bd6a.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get account9193bd6a;

  /// No description provided for @account7272be04.
  ///
  /// In en, this message translates to:
  /// **'Captain account'**
  String get account7272be04;

  /// No description provided for @accountdebf96d9.
  ///
  /// In en, this message translates to:
  /// **'Customer account'**
  String get accountdebf96d9;

  /// No description provided for @accounta180a470.
  ///
  /// In en, this message translates to:
  /// **'Linking a customer account requires a secure identity review.'**
  String get accounta180a470;

  /// No description provided for @account3ef541b9.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get account3ef541b9;

  /// No description provided for @account478c486f.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get account478c486f;

  /// No description provided for @account6553a836.
  ///
  /// In en, this message translates to:
  /// **'Not rated yet'**
  String get account6553a836;

  /// No description provided for @account30db229c.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get account30db229c;

  /// No description provided for @account166aea7d.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get account166aea7d;

  /// No description provided for @accountf3683943.
  ///
  /// In en, this message translates to:
  /// **'My rides'**
  String get accountf3683943;

  /// No description provided for @accountede87845.
  ///
  /// In en, this message translates to:
  /// **'Share VETO and earn'**
  String get accountede87845;

  /// No description provided for @accounta496e785.
  ///
  /// In en, this message translates to:
  /// **'High demand areas'**
  String get accounta496e785;

  /// No description provided for @account654a0663.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get account654a0663;

  /// No description provided for @accountb439a50f.
  ///
  /// In en, this message translates to:
  /// **'Switch to customer'**
  String get accountb439a50f;

  /// No description provided for @account8f2788c0.
  ///
  /// In en, this message translates to:
  /// **'Quick verification — VETO team'**
  String get account8f2788c0;

  /// No description provided for @account8ce3e0cc.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get account8ce3e0cc;

  /// No description provided for @accountc3bb52b7.
  ///
  /// In en, this message translates to:
  /// **'Customer support'**
  String get accountc3bb52b7;

  /// No description provided for @accountaa6de5d4.
  ///
  /// In en, this message translates to:
  /// **'Privacy and terms'**
  String get accountaa6de5d4;

  /// No description provided for @account24c192cb.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get account24c192cb;

  /// No description provided for @account5bc457c0.
  ///
  /// In en, this message translates to:
  /// **'Refresh data'**
  String get account5bc457c0;

  /// No description provided for @account21f47442.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get account21f47442;

  /// No description provided for @growthcf594384.
  ///
  /// In en, this message translates to:
  /// **'The gift is unavailable now. You can continue using the app.'**
  String get growthcf594384;

  /// No description provided for @growthafffef98.
  ///
  /// In en, this message translates to:
  /// **'Offer terms could not be loaded. Retry from Invitations.'**
  String get growthafffef98;

  /// No description provided for @growthcc285252.
  ///
  /// In en, this message translates to:
  /// **'Your choice could not be saved. Check the code and try again.'**
  String get growthcc285252;

  /// No description provided for @growthedf50f6c.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VETO'**
  String get growthedf50f6c;

  /// No description provided for @growth9586813a.
  ///
  /// In en, this message translates to:
  /// **'Have an invitation code? Add it now. Campaign terms and budget apply. Incentives and waiting charges are excluded from the discount.'**
  String get growth9586813a;

  /// No description provided for @growthf132a39e.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get growthf132a39e;

  /// No description provided for @growth47d263ad.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get growth47d263ad;

  /// No description provided for @growth2952dce5.
  ///
  /// In en, this message translates to:
  /// **'Apply code'**
  String get growth2952dce5;

  /// No description provided for @growtha3238c1d.
  ///
  /// In en, this message translates to:
  /// **'Skip and continue'**
  String get growtha3238c1d;

  /// No description provided for @growth46164e2c.
  ///
  /// In en, this message translates to:
  /// **'Review your invitation'**
  String get growth46164e2c;

  /// No description provided for @growth9a30dc2a.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get growth9a30dc2a;

  /// No description provided for @growth9bbb0792.
  ///
  /// In en, this message translates to:
  /// **'Open WhatsApp'**
  String get growth9bbb0792;

  /// No description provided for @growthfcf8b93c.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened. You can copy the link.'**
  String get growthfcf8b93c;

  /// No description provided for @growthede87845.
  ///
  /// In en, this message translates to:
  /// **'Share VETO and earn'**
  String get growthede87845;

  /// No description provided for @growthb7147d67.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend and earn'**
  String get growthb7147d67;

  /// No description provided for @growth77ac862f.
  ///
  /// In en, this message translates to:
  /// **'Invitation details could not be loaded'**
  String get growth77ac862f;

  /// No description provided for @growth14d5786f.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get growth14d5786f;

  /// No description provided for @growth574836bc.
  ///
  /// In en, this message translates to:
  /// **'Offers are currently disabled'**
  String get growth574836bc;

  /// No description provided for @growthc24481f6.
  ///
  /// In en, this message translates to:
  /// **'Share invitation'**
  String get growthc24481f6;

  /// No description provided for @growthfef8e3c9.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get growthfef8e3c9;

  /// No description provided for @growthf1979292.
  ///
  /// In en, this message translates to:
  /// **'Ride concerns and review requests'**
  String get growthf1979292;

  /// No description provided for @growthc5cb135c.
  ///
  /// In en, this message translates to:
  /// **'Car badge / motorcycle card'**
  String get growthc5cb135c;

  /// No description provided for @growth965d621f.
  ///
  /// In en, this message translates to:
  /// **'Earn EGP 15 after your friend’s first eligible ride is completed and settled. Credit applies only to transport fare and cannot be combined with another offer.'**
  String get growth965d621f;

  /// No description provided for @growth1b588c8a.
  ///
  /// In en, this message translates to:
  /// **'Friend invitation credit is promotional and cannot be withdrawn.'**
  String get growth1b588c8a;

  /// No description provided for @growtha3856838.
  ///
  /// In en, this message translates to:
  /// **'Allow app usage measurement'**
  String get growtha3856838;

  /// No description provided for @growthe98a92b2.
  ///
  /// In en, this message translates to:
  /// **'Measurement preference could not be loaded'**
  String get growthe98a92b2;

  /// No description provided for @growthb31335b2.
  ///
  /// In en, this message translates to:
  /// **'Optional. No phone number, location, or verification code.'**
  String get growthb31335b2;

  /// No description provided for @growth23af0f62.
  ///
  /// In en, this message translates to:
  /// **'Measurement preference could not be saved'**
  String get growth23af0f62;

  /// No description provided for @growth3899eb0a.
  ///
  /// In en, this message translates to:
  /// **'Startup sound'**
  String get growth3899eb0a;

  /// No description provided for @growth9c2791a1.
  ///
  /// In en, this message translates to:
  /// **'Preference could not be loaded'**
  String get growth9c2791a1;

  /// No description provided for @growthb85f466b.
  ///
  /// In en, this message translates to:
  /// **'Optional short system click. Off by default.'**
  String get growthb85f466b;

  /// No description provided for @growthf15e1487.
  ///
  /// In en, this message translates to:
  /// **'Sound preference could not be saved'**
  String get growthf15e1487;

  /// No description provided for @growth961fd493.
  ///
  /// In en, this message translates to:
  /// **'Badge generation is currently disabled'**
  String get growth961fd493;

  /// No description provided for @growthbff11b26.
  ///
  /// In en, this message translates to:
  /// **'The approved badge template could not be loaded'**
  String get growthbff11b26;

  /// No description provided for @growth75bc722a.
  ///
  /// In en, this message translates to:
  /// **'Invitation badge'**
  String get growth75bc722a;

  /// No description provided for @growthc12b43ff.
  ///
  /// In en, this message translates to:
  /// **'Place the badge behind a seat, clear of the driver’s view and airbags. For motorcycles, attach a small card to the delivery bag, clear of handlebars and wheels.'**
  String get growthc12b43ff;

  /// No description provided for @growthd0195c3b.
  ///
  /// In en, this message translates to:
  /// **'Scan to download the app'**
  String get growthd0195c3b;

  /// No description provided for @growtha660bd6f.
  ///
  /// In en, this message translates to:
  /// **'Print landscape A4 car badge'**
  String get growtha660bd6f;

  /// No description provided for @growth50f5b043.
  ///
  /// In en, this message translates to:
  /// **'Print motorcycle card 8 × 11 cm'**
  String get growth50f5b043;

  /// No description provided for @growthf12097cd.
  ///
  /// In en, this message translates to:
  /// **'Print at actual size. Do not use your phone as a badge while driving.'**
  String get growthf12097cd;

  /// No description provided for @invitationMessage.
  ///
  /// In en, this message translates to:
  /// **'Try VETO SANYA 🚗\nInvitation code: {code}\nEnter the code during registration to see the offer available to your account.\n{link}'**
  String invitationMessage(String code, String link);

  /// No description provided for @growthInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations: {value}'**
  String growthInvitations(String value);

  /// No description provided for @growthQualifiedFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends with an eligible completed ride: {value}'**
  String growthQualifiedFriends(String value);

  /// No description provided for @growthQualifiedTrips.
  ///
  /// In en, this message translates to:
  /// **'Eligible rides: {value}'**
  String growthQualifiedTrips(String value);

  /// No description provided for @growthDue.
  ///
  /// In en, this message translates to:
  /// **'Rewards due: EGP {value}'**
  String growthDue(String value);

  /// No description provided for @growthPaid.
  ///
  /// In en, this message translates to:
  /// **'Rewards paid: EGP {value}'**
  String growthPaid(String value);

  /// No description provided for @growthCredit.
  ///
  /// In en, this message translates to:
  /// **'Available promotional credit: EGP {value}'**
  String growthCredit(String value);

  /// No description provided for @growthCode.
  ///
  /// In en, this message translates to:
  /// **'Invitation code: {value}'**
  String growthCode(String value);

  /// No description provided for @growthEventsFailed.
  ///
  /// In en, this message translates to:
  /// **'{value} optional measurement events could not be sent. Rides were unaffected.'**
  String growthEventsFailed(String value);

  /// No description provided for @zeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Two hours of zero commission'**
  String get zeroTitle;

  /// No description provided for @zeroLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Zero commission reward could not be loaded.'**
  String get zeroLoadFailed;

  /// No description provided for @zeroActivateFailed.
  ///
  /// In en, this message translates to:
  /// **'Activation could not be confirmed. Refresh before retrying; the server stores reward timing.'**
  String get zeroActivateFailed;

  /// No description provided for @zeroActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate now — timing starts on the server'**
  String get zeroActivate;

  /// No description provided for @zeroExpired.
  ///
  /// In en, this message translates to:
  /// **'The activation deadline has passed'**
  String get zeroExpired;

  /// No description provided for @zeroAcceptedPreserved.
  ///
  /// In en, this message translates to:
  /// **'The acceptance window has ended; eligible rides keep their exemption'**
  String get zeroAcceptedPreserved;

  /// No description provided for @zeroNoTripCap.
  ///
  /// In en, this message translates to:
  /// **'No ride count limit'**
  String get zeroNoTripCap;

  /// No description provided for @zeroNoCostCap.
  ///
  /// In en, this message translates to:
  /// **'No cost limit'**
  String get zeroNoCostCap;

  /// No description provided for @zeroIndependent.
  ///
  /// In en, this message translates to:
  /// **'Covers fare and waiting commission. Incentive and debt rules remain unchanged.'**
  String get zeroIndependent;

  /// No description provided for @zeroRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh rewards'**
  String get zeroRefresh;

  /// No description provided for @zeroDeadline.
  ///
  /// In en, this message translates to:
  /// **'Activate before: {value}'**
  String zeroDeadline(String value);

  /// No description provided for @zeroServices.
  ///
  /// In en, this message translates to:
  /// **'Eligible services: {value}'**
  String zeroServices(String value);

  /// No description provided for @zeroRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining {value}'**
  String zeroRemaining(String value);

  /// No description provided for @zeroSaved.
  ///
  /// In en, this message translates to:
  /// **'Actual commission saved: EGP {value}'**
  String zeroSaved(String value);

  /// No description provided for @zeroTripCap.
  ///
  /// In en, this message translates to:
  /// **'Completed ride limit: {value}'**
  String zeroTripCap(String value);

  /// No description provided for @zeroCostCap.
  ///
  /// In en, this message translates to:
  /// **'Cost limit: EGP {value}. Eligible rides keep their full exemption.'**
  String zeroCostCap(String value);

  /// No description provided for @live284968d7.
  ///
  /// In en, this message translates to:
  /// **'This ride is currently unavailable.'**
  String get live284968d7;

  /// No description provided for @live182cb52e.
  ///
  /// In en, this message translates to:
  /// **'Ride status refreshed'**
  String get live182cb52e;

  /// No description provided for @live6ef3859c.
  ///
  /// In en, this message translates to:
  /// **'Ride status could not be refreshed. Try again.'**
  String get live6ef3859c;

  /// No description provided for @liveeed45423.
  ///
  /// In en, this message translates to:
  /// **'the amount set by administration'**
  String get liveeed45423;

  /// No description provided for @livefc43d3fe.
  ///
  /// In en, this message translates to:
  /// **'You are still searching. Cancellation is free. Any wallet amount held for this ride is refunded once.'**
  String get livefc43d3fe;

  /// No description provided for @live47420271.
  ///
  /// In en, this message translates to:
  /// **'You are within the grace period, so cancellation is free. Any held wallet funds are refunded once.'**
  String get live47420271;

  /// No description provided for @live3006aec8.
  ///
  /// In en, this message translates to:
  /// **'Cancellation fees may apply based on captain acceptance time and administration rules. Check the amount due in your account.'**
  String get live3006aec8;

  /// No description provided for @live6aef022f.
  ///
  /// In en, this message translates to:
  /// **'Cancel ride'**
  String get live6aef022f;

  /// No description provided for @livecb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get livecb822418;

  /// No description provided for @livede0b18e1.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get livede0b18e1;

  /// No description provided for @liveac9ac0e6.
  ///
  /// In en, this message translates to:
  /// **'You can request a new ride. Held wallet funds are refunded once according to the cancellation statement.'**
  String get liveac9ac0e6;

  /// No description provided for @live65d25b44.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get live65d25b44;

  /// No description provided for @live2f225a03.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get live2f225a03;

  /// No description provided for @live6539544e.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened.'**
  String get live6539544e;

  /// No description provided for @live37ccdeb7.
  ///
  /// In en, this message translates to:
  /// **'Ride support'**
  String get live37ccdeb7;

  /// No description provided for @live99f2c8a6.
  ///
  /// In en, this message translates to:
  /// **'Current ride'**
  String get live99f2c8a6;

  /// No description provided for @livedcf45bf6.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get livedcf45bf6;

  /// No description provided for @live9a86a128.
  ///
  /// In en, this message translates to:
  /// **'The ride could not be loaded'**
  String get live9a86a128;

  /// No description provided for @live14d5786f.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get live14d5786f;

  /// No description provided for @live5a6daebf.
  ///
  /// In en, this message translates to:
  /// **'Waiting for captain acceptance'**
  String get live5a6daebf;

  /// No description provided for @live3c6518b4.
  ///
  /// In en, this message translates to:
  /// **'Searching for a captain'**
  String get live3c6518b4;

  /// No description provided for @live4babb638.
  ///
  /// In en, this message translates to:
  /// **'Searching for available captains eligible for your service.'**
  String get live4babb638;

  /// No description provided for @live606af07c.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get live606af07c;

  /// No description provided for @live5a0374f3.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get live5a0374f3;

  /// No description provided for @livea674a023.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get livea674a023;

  /// No description provided for @liveb075cda8.
  ///
  /// In en, this message translates to:
  /// **'Ride details'**
  String get liveb075cda8;

  /// No description provided for @liveae7ae56d.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get liveae7ae56d;

  /// No description provided for @live8b068efc.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get live8b068efc;

  /// No description provided for @livedd00b654.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get livedd00b654;

  /// No description provided for @livea7947509.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get livea7947509;

  /// No description provided for @live65fc6a0a.
  ///
  /// In en, this message translates to:
  /// **'Customer note for captain'**
  String get live65fc6a0a;

  /// No description provided for @live15d8bb61.
  ///
  /// In en, this message translates to:
  /// **'Chat with captain'**
  String get live15d8bb61;

  /// No description provided for @liveb7d72a98.
  ///
  /// In en, this message translates to:
  /// **'Captain assigned'**
  String get liveb7d72a98;

  /// No description provided for @live2f7a3366.
  ///
  /// In en, this message translates to:
  /// **'Captain is on the way'**
  String get live2f7a3366;

  /// No description provided for @live0676addf.
  ///
  /// In en, this message translates to:
  /// **'Captain has arrived'**
  String get live0676addf;

  /// No description provided for @liveda8838dc.
  ///
  /// In en, this message translates to:
  /// **'Ride in progress'**
  String get liveda8838dc;

  /// No description provided for @livece7c7ba9.
  ///
  /// In en, this message translates to:
  /// **'Ride completed'**
  String get livece7c7ba9;

  /// No description provided for @live8c2ae1f8.
  ///
  /// In en, this message translates to:
  /// **'Updating ride'**
  String get live8c2ae1f8;

  /// No description provided for @livebdfe2de5.
  ///
  /// In en, this message translates to:
  /// **'Your captain accepted the ride and is preparing to come to you.'**
  String get livebdfe2de5;

  /// No description provided for @live6467fed6.
  ///
  /// In en, this message translates to:
  /// **'Follow your captain on the map until arrival.'**
  String get live6467fed6;

  /// No description provided for @live1a58a508.
  ///
  /// In en, this message translates to:
  /// **'Your captain has reached pickup. Please be ready.'**
  String get live1a58a508;

  /// No description provided for @live340df273.
  ///
  /// In en, this message translates to:
  /// **'Your ride has started. Captain location updates appear on the map.'**
  String get live340df273;

  /// No description provided for @live08e09e69.
  ///
  /// In en, this message translates to:
  /// **'Your ride has ended. Review the final statement and rate your experience.'**
  String get live08e09e69;

  /// No description provided for @live4a4aa18a.
  ///
  /// In en, this message translates to:
  /// **'The ride was cancelled. Check the cancellation statement for any applicable amount.'**
  String get live4a4aa18a;

  /// No description provided for @livea7ecc2bc.
  ///
  /// In en, this message translates to:
  /// **'Status refreshes automatically.'**
  String get livea7ecc2bc;

  /// No description provided for @live89aef3a3.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get live89aef3a3;

  /// No description provided for @live80a51d6a.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get live80a51d6a;

  /// No description provided for @live113cb058.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get live113cb058;

  /// No description provided for @livec9a1bb1e.
  ///
  /// In en, this message translates to:
  /// **'The phone app could not be opened.'**
  String get livec9a1bb1e;

  /// No description provided for @liveCancellationAfterGrace.
  ///
  /// In en, this message translates to:
  /// **'The grace period has ended. Current cancellation compensation of {fee} goes to the captain under administration rules. The server checks it again on confirmation.'**
  String liveCancellationAfterGrace(String fee);

  /// No description provided for @liveCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'{message}\n\nContinue and cancel this ride?'**
  String liveCancelConfirm(String message);

  /// No description provided for @liveSupportMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello, I need support with ride {trip}.'**
  String liveSupportMessage(String trip);

  /// No description provided for @liveIncentive.
  ///
  /// In en, this message translates to:
  /// **'Ride incentive: EGP {value}'**
  String liveIncentive(String value);

  /// No description provided for @growthDiscountTerms.
  ///
  /// In en, this message translates to:
  /// **'First three eligible ride discounts: {discounts}% · Discount cap: EGP {cap}'**
  String growthDiscountTerms(String discounts, String cap);

  /// No description provided for @growthOfferExpiry.
  ///
  /// In en, this message translates to:
  /// **'Valid until {value}, subject to eligible services and campaign budget. Excludes incentives, waiting charges, and prior debts.'**
  String growthOfferExpiry(String value);

  /// No description provided for @growthLinkReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The link code could not be read automatically. You can enter it manually.'**
  String get growthLinkReadFailed;

  /// No description provided for @home86b9f2f0.
  ///
  /// In en, this message translates to:
  /// **'Request your ride again?'**
  String get home86b9f2f0;

  /// No description provided for @home0708df98.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get home0708df98;

  /// No description provided for @home76509239.
  ///
  /// In en, this message translates to:
  /// **'Request again'**
  String get home76509239;

  /// No description provided for @homeeefa3156.
  ///
  /// In en, this message translates to:
  /// **'Finding your city…'**
  String get homeeefa3156;

  /// No description provided for @home80e0d09a.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup on the map'**
  String get home80e0d09a;

  /// No description provided for @home6d6c1e9b.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup on the map for an accurate fare'**
  String get home6d6c1e9b;

  /// No description provided for @home71bcd653.
  ///
  /// In en, this message translates to:
  /// **'Finding your current area'**
  String get home71bcd653;

  /// No description provided for @homea5ba6dc1.
  ///
  /// In en, this message translates to:
  /// **'Other app services remain available'**
  String get homea5ba6dc1;

  /// No description provided for @home96a80d01.
  ///
  /// In en, this message translates to:
  /// **'You can continue and choose your destination'**
  String get home96a80d01;

  /// No description provided for @home57b420fe.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup to calculate the fare'**
  String get home57b420fe;

  /// No description provided for @home53f070d4.
  ///
  /// In en, this message translates to:
  /// **'Choose city'**
  String get home53f070d4;

  /// No description provided for @home9874ac8e.
  ///
  /// In en, this message translates to:
  /// **'Refresh city'**
  String get home9874ac8e;

  /// No description provided for @home13e32830.
  ///
  /// In en, this message translates to:
  /// **'New offers could not be checked. You can continue booking normally.'**
  String get home13e32830;

  /// No description provided for @homeb7147d67.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend and earn'**
  String get homeb7147d67;

  /// No description provided for @home6397a101.
  ///
  /// In en, this message translates to:
  /// **'Track VETO Market order'**
  String get home6397a101;

  /// No description provided for @home8e0c6845.
  ///
  /// In en, this message translates to:
  /// **'Waiting for store acceptance'**
  String get home8e0c6845;

  /// No description provided for @home797b2da9.
  ///
  /// In en, this message translates to:
  /// **'Store accepted the order'**
  String get home797b2da9;

  /// No description provided for @home8594c09a.
  ///
  /// In en, this message translates to:
  /// **'Your order is being prepared'**
  String get home8594c09a;

  /// No description provided for @homee08d6fd7.
  ///
  /// In en, this message translates to:
  /// **'Ready for captain pickup'**
  String get homee08d6fd7;

  /// No description provided for @home58387cb4.
  ///
  /// In en, this message translates to:
  /// **'Captain assigned — open to contact'**
  String get home58387cb4;

  /// No description provided for @homebaac8162.
  ///
  /// In en, this message translates to:
  /// **'Captain picked up the order'**
  String get homebaac8162;

  /// No description provided for @home2f7a3366.
  ///
  /// In en, this message translates to:
  /// **'Captain is on the way'**
  String get home2f7a3366;

  /// No description provided for @homebae11587.
  ///
  /// In en, this message translates to:
  /// **'Track order status'**
  String get homebae11587;

  /// No description provided for @homeeb4cee6e.
  ///
  /// In en, this message translates to:
  /// **'Add your name in seconds'**
  String get homeeb4cee6e;

  /// No description provided for @home05fb123d.
  ///
  /// In en, this message translates to:
  /// **'Add your name so we can welcome you personally.'**
  String get home05fb123d;

  /// No description provided for @home4fabeda0.
  ///
  /// In en, this message translates to:
  /// **'Enter a name with at least two characters'**
  String get home4fabeda0;

  /// No description provided for @home0bfd0492.
  ///
  /// In en, this message translates to:
  /// **'Your name could not be saved. Try again.'**
  String get home0bfd0492;

  /// No description provided for @homeb658c871.
  ///
  /// In en, this message translates to:
  /// **'Let us welcome you by name ✨'**
  String get homeb658c871;

  /// No description provided for @homed017c069.
  ///
  /// In en, this message translates to:
  /// **'Enter your name once for a personal welcome.'**
  String get homed017c069;

  /// No description provided for @home84e2331e.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get home84e2331e;

  /// No description provided for @home2bd32fda.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get home2bd32fda;

  /// No description provided for @homea49e25ed.
  ///
  /// In en, this message translates to:
  /// **'Save my name'**
  String get homea49e25ed;

  /// No description provided for @profile6db47f1c.
  ///
  /// In en, this message translates to:
  /// **'Your photo could not be uploaded'**
  String get profile6db47f1c;

  /// No description provided for @profilec3bb52b7.
  ///
  /// In en, this message translates to:
  /// **'Customer support'**
  String get profilec3bb52b7;

  /// No description provided for @profile606af07c.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get profile606af07c;

  /// No description provided for @profile8e10b7d8.
  ///
  /// In en, this message translates to:
  /// **'Hello, I need help with VETO SANYA'**
  String get profile8e10b7d8;

  /// No description provided for @profile9193bd6a.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get profile9193bd6a;

  /// No description provided for @profile41e29a2a.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get profile41e29a2a;

  /// No description provided for @profile7272be04.
  ///
  /// In en, this message translates to:
  /// **'Captain account'**
  String get profile7272be04;

  /// No description provided for @profilee979acbd.
  ///
  /// In en, this message translates to:
  /// **'Register as captain'**
  String get profilee979acbd;

  /// No description provided for @profileb9eaeabe.
  ///
  /// In en, this message translates to:
  /// **'Open captain mode with your account'**
  String get profileb9eaeabe;

  /// No description provided for @profilebad7739d.
  ///
  /// In en, this message translates to:
  /// **'Apply to join the captain team'**
  String get profilebad7739d;

  /// No description provided for @profile3ef541b9.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get profile3ef541b9;

  /// No description provided for @profileafe5d60a.
  ///
  /// In en, this message translates to:
  /// **'My VETO account'**
  String get profileafe5d60a;

  /// No description provided for @profile3f3089b7.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get profile3f3089b7;

  /// No description provided for @profile6b1fd308.
  ///
  /// In en, this message translates to:
  /// **'Refresh profile'**
  String get profile6b1fd308;

  /// No description provided for @profile4f95f432.
  ///
  /// In en, this message translates to:
  /// **'New member'**
  String get profile4f95f432;

  /// No description provided for @profile05f99bc8.
  ///
  /// In en, this message translates to:
  /// **'VETO member'**
  String get profile05f99bc8;

  /// No description provided for @profile2df1f491.
  ///
  /// In en, this message translates to:
  /// **'Profile • Edit photo and details'**
  String get profile2df1f491;

  /// No description provided for @profile89e7f927.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get profile89e7f927;

  /// No description provided for @profile9092f905.
  ///
  /// In en, this message translates to:
  /// **'Switch to captain'**
  String get profile9092f905;

  /// No description provided for @profile30db229c.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get profile30db229c;

  /// No description provided for @profile69cb4d81.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get profile69cb4d81;

  /// No description provided for @profile92d05589.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get profile92d05589;

  /// No description provided for @profile09f41ce6.
  ///
  /// In en, this message translates to:
  /// **'Account and features'**
  String get profile09f41ce6;

  /// No description provided for @profilec8c5d575.
  ///
  /// In en, this message translates to:
  /// **'My frames and rewards'**
  String get profilec8c5d575;

  /// No description provided for @profilebfa6d7fd.
  ///
  /// In en, this message translates to:
  /// **'Your rating, rides, and available frames'**
  String get profilebfa6d7fd;

  /// No description provided for @profile158bcacd.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend and earn EGP 15'**
  String get profile158bcacd;

  /// No description provided for @profileb62e7ee8.
  ///
  /// In en, this message translates to:
  /// **'Separate promotional credit after your friend’s first eligible ride'**
  String get profileb62e7ee8;

  /// No description provided for @profile8ce3e0cc.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profile8ce3e0cc;

  /// No description provided for @profile45d7fc3c.
  ///
  /// In en, this message translates to:
  /// **'Ride and account updates'**
  String get profile45d7fc3c;

  /// No description provided for @profileed230578.
  ///
  /// In en, this message translates to:
  /// **'Receive rides with the same account'**
  String get profileed230578;

  /// No description provided for @profile1614cb5d.
  ///
  /// In en, this message translates to:
  /// **'Register as captain'**
  String get profile1614cb5d;

  /// No description provided for @profileba0e24fa.
  ///
  /// In en, this message translates to:
  /// **'Apply to join the captain team'**
  String get profileba0e24fa;

  /// No description provided for @profiled2016401.
  ///
  /// In en, this message translates to:
  /// **'Quick verification'**
  String get profiled2016401;

  /// No description provided for @profile72081e80.
  ///
  /// In en, this message translates to:
  /// **'Verification and WhatsApp requests'**
  String get profile72081e80;

  /// No description provided for @profile52233a23.
  ///
  /// In en, this message translates to:
  /// **'Support and security'**
  String get profile52233a23;

  /// No description provided for @profile5fe46ac6.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get profile5fe46ac6;

  /// No description provided for @profile615e6b1d.
  ///
  /// In en, this message translates to:
  /// **'Share an idea to improve VETO SANYA'**
  String get profile615e6b1d;

  /// No description provided for @profile12506e99.
  ///
  /// In en, this message translates to:
  /// **'Complaint'**
  String get profile12506e99;

  /// No description provided for @profileb0500561.
  ///
  /// In en, this message translates to:
  /// **'Our support team is ready to help'**
  String get profileb0500561;

  /// No description provided for @profileaa6de5d4.
  ///
  /// In en, this message translates to:
  /// **'Privacy and terms'**
  String get profileaa6de5d4;

  /// No description provided for @profile86c46fe1.
  ///
  /// In en, this message translates to:
  /// **'Policies, your rights, and your data'**
  String get profile86c46fe1;

  /// No description provided for @profile24c192cb.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get profile24c192cb;

  /// No description provided for @profile70224a06.
  ///
  /// In en, this message translates to:
  /// **'Request deletion through the official channels'**
  String get profile70224a06;

  /// No description provided for @profile21f47442.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profile21f47442;

  /// No description provided for @profileda1d0e35.
  ///
  /// In en, this message translates to:
  /// **'Sign out safely'**
  String get profileda1d0e35;

  /// No description provided for @profile14009384.
  ///
  /// In en, this message translates to:
  /// **'VETO SANYA • Your journey, made simple'**
  String get profile14009384;

  /// No description provided for @wallet30454aef.
  ///
  /// In en, this message translates to:
  /// **'Ride hold refund'**
  String get wallet30454aef;

  /// No description provided for @wallet94d8f009.
  ///
  /// In en, this message translates to:
  /// **'Cancellation compensation'**
  String get wallet94d8f009;

  /// No description provided for @wallet08b4509e.
  ///
  /// In en, this message translates to:
  /// **'Cancellation fee'**
  String get wallet08b4509e;

  /// No description provided for @wallet73a173f7.
  ///
  /// In en, this message translates to:
  /// **'Balance correction'**
  String get wallet73a173f7;

  /// No description provided for @wallet7a70ab91.
  ///
  /// In en, this message translates to:
  /// **'Top-up reward'**
  String get wallet7a70ab91;

  /// No description provided for @wallet4626aabc.
  ///
  /// In en, this message translates to:
  /// **'Wallet top-up'**
  String get wallet4626aabc;

  /// No description provided for @wallet9da2b774.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get wallet9da2b774;

  /// No description provided for @walletdd1bba5b.
  ///
  /// In en, this message translates to:
  /// **'Change from captain'**
  String get walletdd1bba5b;

  /// No description provided for @walletec9ccd93.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get walletec9ccd93;

  /// No description provided for @walletf11b8c52.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get walletf11b8c52;

  /// No description provided for @walleta674a023.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get walleta674a023;

  /// No description provided for @wallet113d570d.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get wallet113d570d;

  /// No description provided for @wallet1cae7479.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get wallet1cae7479;

  /// No description provided for @wallete343e4a4.
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get wallete343e4a4;

  /// No description provided for @walleta94f951d.
  ///
  /// In en, this message translates to:
  /// **'Settlement credit'**
  String get walleta94f951d;

  /// No description provided for @wallete1853a0c.
  ///
  /// In en, this message translates to:
  /// **'Settlement payment'**
  String get wallete1853a0c;

  /// No description provided for @wallet6432e51d.
  ///
  /// In en, this message translates to:
  /// **'Incentive'**
  String get wallet6432e51d;

  /// No description provided for @wallet40c7d7e2.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance'**
  String get wallet40c7d7e2;

  /// No description provided for @wallet9b7f8de8.
  ///
  /// In en, this message translates to:
  /// **'Top up securely. Offers and rewards are applied after the transfer is reviewed.'**
  String get wallet9b7f8de8;

  /// No description provided for @wallet6a50382f.
  ///
  /// In en, this message translates to:
  /// **'Top up wallet'**
  String get wallet6a50382f;

  /// No description provided for @walletaf7fb819.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get walletaf7fb819;

  /// No description provided for @walletf0795392.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get walletf0795392;

  /// No description provided for @auth4b6a0d56.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get auth4b6a0d56;

  /// No description provided for @auth94b8b549.
  ///
  /// In en, this message translates to:
  /// **'The code must contain four digits'**
  String get auth94b8b549;

  /// No description provided for @auth8ba78f82.
  ///
  /// In en, this message translates to:
  /// **'This number is linked to different customer and captain accounts. Contact administration to review the account links.'**
  String get auth8ba78f82;

  /// No description provided for @auth877ec1c8.
  ///
  /// In en, this message translates to:
  /// **'Please wait. Administration has not sent the code yet.'**
  String get auth877ec1c8;

  /// No description provided for @auth2fb0282a.
  ///
  /// In en, this message translates to:
  /// **'This request expired. Request a new code.'**
  String get auth2fb0282a;

  /// No description provided for @authf4eb3c84.
  ///
  /// In en, this message translates to:
  /// **'Attempt limit reached. Request a new code.'**
  String get authf4eb3c84;

  /// No description provided for @auth7cf0e2f5.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code.'**
  String get auth7cf0e2f5;

  /// No description provided for @auth5063b733.
  ///
  /// In en, this message translates to:
  /// **'This number is not linked to an active store.'**
  String get auth5063b733;

  /// No description provided for @auth00d3d260.
  ///
  /// In en, this message translates to:
  /// **'The store account could not be prepared. The server recorded the cause; administration must review the store login service.'**
  String get auth00d3d260;

  /// No description provided for @authc9ff542b.
  ///
  /// In en, this message translates to:
  /// **'The account was created, but store access could not be linked. Administration must review the store account link.'**
  String get authc9ff542b;

  /// No description provided for @auth9736c215.
  ///
  /// In en, this message translates to:
  /// **'The code was verified, but a secure session could not be opened. Request a new code and retry.'**
  String get auth9736c215;

  /// No description provided for @auth7525bff1.
  ///
  /// In en, this message translates to:
  /// **'Store login failed. Contact administration.'**
  String get auth7525bff1;

  /// No description provided for @authac9e317b.
  ///
  /// In en, this message translates to:
  /// **'This request expired. Go back and request verification again.'**
  String get authac9e317b;

  /// No description provided for @auth7474039f.
  ///
  /// In en, this message translates to:
  /// **'Attempt limit reached. Request verification again.'**
  String get auth7474039f;

  /// No description provided for @authef7a895a.
  ///
  /// In en, this message translates to:
  /// **'This number is not registered as a captain.'**
  String get authef7a895a;

  /// No description provided for @auth8d4c6591.
  ///
  /// In en, this message translates to:
  /// **'The captain account is currently inactive.'**
  String get auth8d4c6591;

  /// No description provided for @authe1e92bab.
  ///
  /// In en, this message translates to:
  /// **'The captain account is not ready for login.'**
  String get authe1e92bab;

  /// No description provided for @authbf47817e.
  ///
  /// In en, this message translates to:
  /// **'The captain account could not be secured. Contact administration.'**
  String get authbf47817e;

  /// No description provided for @auth095e455e.
  ///
  /// In en, this message translates to:
  /// **'Administration must review the captain account details.'**
  String get auth095e455e;

  /// No description provided for @auth767a6bf3.
  ///
  /// In en, this message translates to:
  /// **'Captain login failed. Try again.'**
  String get auth767a6bf3;

  /// No description provided for @autha18be99f.
  ///
  /// In en, this message translates to:
  /// **'This number belongs to a captain. Use the captain login code.'**
  String get autha18be99f;

  /// No description provided for @auth9ec825fc.
  ///
  /// In en, this message translates to:
  /// **'The customer account is inactive. Contact support.'**
  String get auth9ec825fc;

  /// No description provided for @auth6c804eff.
  ///
  /// In en, this message translates to:
  /// **'Administration must review the customer account.'**
  String get auth6c804eff;

  /// No description provided for @auth6dd32123.
  ///
  /// In en, this message translates to:
  /// **'The customer account could not be prepared. Try again.'**
  String get auth6dd32123;

  /// No description provided for @authe2341633.
  ///
  /// In en, this message translates to:
  /// **'The account could not be secured. Try again.'**
  String get authe2341633;

  /// No description provided for @auth51953e13.
  ///
  /// In en, this message translates to:
  /// **'The customer profile could not be prepared. Try again.'**
  String get auth51953e13;

  /// No description provided for @authd7cba707.
  ///
  /// In en, this message translates to:
  /// **'The customer profile could not be linked to the account. Contact administration.'**
  String get authd7cba707;

  /// No description provided for @authc15acdd8.
  ///
  /// In en, this message translates to:
  /// **'A login session could not be created. Request a new code after administration reviews the issue.'**
  String get authc15acdd8;

  /// No description provided for @authd41a26b6.
  ///
  /// In en, this message translates to:
  /// **'The customer account could not be linked. Contact administration.'**
  String get authd41a26b6;

  /// No description provided for @authe4a12e31.
  ///
  /// In en, this message translates to:
  /// **'This account is blocked. Contact support.'**
  String get authe4a12e31;

  /// No description provided for @auth517e8c1a.
  ///
  /// In en, this message translates to:
  /// **'Administration must review the account status.'**
  String get auth517e8c1a;

  /// No description provided for @authac51cf01.
  ///
  /// In en, this message translates to:
  /// **'Verification is temporarily unavailable. Try later.'**
  String get authac51cf01;

  /// No description provided for @authf7179060.
  ///
  /// In en, this message translates to:
  /// **'The code is incorrect or expired.'**
  String get authf7179060;

  /// No description provided for @auth51721be4.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Try again.'**
  String get auth51721be4;

  /// No description provided for @auth160e784b.
  ///
  /// In en, this message translates to:
  /// **'The connection is unavailable. Check your network and retry.'**
  String get auth160e784b;

  /// No description provided for @auth54d4f443.
  ///
  /// In en, this message translates to:
  /// **'Administration must update the login service.'**
  String get auth54d4f443;

  /// No description provided for @auth7b3824d7.
  ///
  /// In en, this message translates to:
  /// **'The login service is not fully configured.'**
  String get auth7b3824d7;

  /// No description provided for @auth7513ec76.
  ///
  /// In en, this message translates to:
  /// **'The customer account could not be linked. Contact administration.'**
  String get auth7513ec76;

  /// No description provided for @authd2227474.
  ///
  /// In en, this message translates to:
  /// **'The customer account could not be created. Contact administration.'**
  String get authd2227474;

  /// No description provided for @auth010fd34d.
  ///
  /// In en, this message translates to:
  /// **'The login session could not be created. Contact administration.'**
  String get auth010fd34d;

  /// No description provided for @auth31654349.
  ///
  /// In en, this message translates to:
  /// **'This account is blocked. Contact support.'**
  String get auth31654349;

  /// No description provided for @auth334c0562.
  ///
  /// In en, this message translates to:
  /// **'Verification is temporarily unavailable.'**
  String get auth334c0562;

  /// No description provided for @auth4c5573f4.
  ///
  /// In en, this message translates to:
  /// **'Administration has not configured the support number'**
  String get auth4c5573f4;

  /// No description provided for @auth56a1b88a.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened'**
  String get auth56a1b88a;

  /// No description provided for @auth653fd437.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get auth653fd437;

  /// No description provided for @auth4bf997e8.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get auth4bf997e8;

  /// No description provided for @authaff91568.
  ///
  /// In en, this message translates to:
  /// **'Your verification code will be sent through WhatsApp after administration reviews your request.'**
  String get authaff91568;

  /// No description provided for @authc1717a62.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get authc1717a62;

  /// No description provided for @authec6b1f69.
  ///
  /// In en, this message translates to:
  /// **'Code not received? Contact support through WhatsApp'**
  String get authec6b1f69;

  /// No description provided for @topupfb743f85.
  ///
  /// In en, this message translates to:
  /// **'Top-up service could not be loaded. Please retry.'**
  String get topupfb743f85;

  /// No description provided for @topup120e8520.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount or choose the offer amount.'**
  String get topup120e8520;

  /// No description provided for @topup85a2d105.
  ///
  /// In en, this message translates to:
  /// **'Choose an available payment method first.'**
  String get topup85a2d105;

  /// No description provided for @topup42c2949d.
  ///
  /// In en, this message translates to:
  /// **'Enter the number you transferred from.'**
  String get topup42c2949d;

  /// No description provided for @topup8c6dd9dd.
  ///
  /// In en, this message translates to:
  /// **'Your request was received for review. No balance has been added yet.'**
  String get topup8c6dd9dd;

  /// No description provided for @topupf5d7c7d6.
  ///
  /// In en, this message translates to:
  /// **'The top-up request could not be confirmed. Check its status before retrying.'**
  String get topupf5d7c7d6;

  /// No description provided for @topup4d96fe71.
  ///
  /// In en, this message translates to:
  /// **'✨ Wallet offers'**
  String get topup4d96fe71;

  /// No description provided for @topup6a50382f.
  ///
  /// In en, this message translates to:
  /// **'Top up your wallet'**
  String get topup6a50382f;

  /// No description provided for @topup78775dc3.
  ///
  /// In en, this message translates to:
  /// **'Top up for your next ride'**
  String get topup78775dc3;

  /// No description provided for @topup1eb95ad4.
  ///
  /// In en, this message translates to:
  /// **'Reward terms are shown clearly. Balance is added after transfer verification.'**
  String get topup1eb95ad4;

  /// No description provided for @topupd2016477.
  ///
  /// In en, this message translates to:
  /// **'✦ Top-up offer'**
  String get topupd2016477;

  /// No description provided for @topup292f3529.
  ///
  /// In en, this message translates to:
  /// **'Choose this offer'**
  String get topup292f3529;

  /// No description provided for @topupf5e67eb7.
  ///
  /// In en, this message translates to:
  /// **'Available offers'**
  String get topupf5e67eb7;

  /// No description provided for @topupd27033c9.
  ///
  /// In en, this message translates to:
  /// **'Choose an offer. The reward is shown separately from your transfer.'**
  String get topupd27033c9;

  /// No description provided for @topupc2ef5692.
  ///
  /// In en, this message translates to:
  /// **'Choose your own top-up amount without a reward'**
  String get topupc2ef5692;

  /// No description provided for @topupe0607388.
  ///
  /// In en, this message translates to:
  /// **'Payment methods are not enabled. Administration must add a verified transfer number.'**
  String get topupe0607388;

  /// No description provided for @topup1768325b.
  ///
  /// In en, this message translates to:
  /// **'01 / Choose amount'**
  String get topup1768325b;

  /// No description provided for @topupb7231cbd.
  ///
  /// In en, this message translates to:
  /// **'Selected offer'**
  String get topupb7231cbd;

  /// No description provided for @topup1223dbd6.
  ///
  /// In en, this message translates to:
  /// **'The offer amount is fixed to protect your reward. Go back to choose another offer.'**
  String get topup1223dbd6;

  /// No description provided for @topupac3d43ad.
  ///
  /// In en, this message translates to:
  /// **'Transfer amount in EGP'**
  String get topupac3d43ad;

  /// No description provided for @topup29bc32d5.
  ///
  /// In en, this message translates to:
  /// **'Required transfer amount'**
  String get topup29bc32d5;

  /// No description provided for @topup346be366.
  ///
  /// In en, this message translates to:
  /// **'Offer reward'**
  String get topup346be366;

  /// No description provided for @topup663ba8dc.
  ///
  /// In en, this message translates to:
  /// **'Total added after approval'**
  String get topup663ba8dc;

  /// No description provided for @topup43f4b708.
  ///
  /// In en, this message translates to:
  /// **'02 / Choose payment method'**
  String get topup43f4b708;

  /// No description provided for @topupb14b98c9.
  ///
  /// In en, this message translates to:
  /// **'No payment method is currently active. Do not transfer until administration adds one.'**
  String get topupb14b98c9;

  /// No description provided for @topupd85df9ec.
  ///
  /// In en, this message translates to:
  /// **'Transfer details appear in the next step'**
  String get topupd85df9ec;

  /// No description provided for @topup1d09cf88.
  ///
  /// In en, this message translates to:
  /// **'Continue to transfer instructions'**
  String get topup1d09cf88;

  /// No description provided for @topup114df589.
  ///
  /// In en, this message translates to:
  /// **'03 / Transfer details'**
  String get topup114df589;

  /// No description provided for @topup08e262ba.
  ///
  /// In en, this message translates to:
  /// **'Copy transfer number'**
  String get topup08e262ba;

  /// No description provided for @topupa914d518.
  ///
  /// In en, this message translates to:
  /// **'Transfer details copied'**
  String get topupa914d518;

  /// No description provided for @topup58890d41.
  ///
  /// In en, this message translates to:
  /// **'Transfer instructions'**
  String get topup58890d41;

  /// No description provided for @topup9f05f6f1.
  ///
  /// In en, this message translates to:
  /// **'Check the transfer number and amount before sending.'**
  String get topup9f05f6f1;

  /// No description provided for @topup9296abef.
  ///
  /// In en, this message translates to:
  /// **'Sender number *'**
  String get topup9296abef;

  /// No description provided for @topup9895aa5d.
  ///
  /// In en, this message translates to:
  /// **'Sender wallet or account number'**
  String get topup9895aa5d;

  /// No description provided for @topup18f7532a.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference (if available)'**
  String get topup18f7532a;

  /// No description provided for @topupceedefc4.
  ///
  /// In en, this message translates to:
  /// **'Reference shown on your transfer receipt'**
  String get topupceedefc4;

  /// No description provided for @topup218b7624.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Protecting your balance'**
  String get topup218b7624;

  /// No description provided for @topupd6c8e2d2.
  ///
  /// In en, this message translates to:
  /// **'Submitting a request does not add balance. Your payment and reward are credited once after an authorized employee verifies and approves the transfer.'**
  String get topupd6c8e2d2;

  /// No description provided for @topup838c527e.
  ///
  /// In en, this message translates to:
  /// **'Submitting request…'**
  String get topup838c527e;

  /// No description provided for @topup2bc6aebc.
  ///
  /// In en, this message translates to:
  /// **'Submit top-up request'**
  String get topup2bc6aebc;

  /// No description provided for @topup4a807954.
  ///
  /// In en, this message translates to:
  /// **'Approved • Balance credited'**
  String get topup4a807954;

  /// No description provided for @topup5d969a71.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get topup5d969a71;

  /// No description provided for @topup8aac5fac.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get topup8aac5fac;

  /// No description provided for @topupd44d4435.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get topupd44d4435;

  /// No description provided for @topup90aa4d47.
  ///
  /// In en, this message translates to:
  /// **'04 / Track top-up request'**
  String get topup90aa4d47;

  /// No description provided for @topup007c4718.
  ///
  /// In en, this message translates to:
  /// **'We received your request and are checking the transfer. Status updates after review.'**
  String get topup007c4718;

  /// No description provided for @topupc769438a.
  ///
  /// In en, this message translates to:
  /// **'Your transfer was verified and your wallet credited.'**
  String get topupc769438a;

  /// No description provided for @topupca711e4a.
  ///
  /// In en, this message translates to:
  /// **'Your request was not approved. Review the rejection reason with support before a new attempt.'**
  String get topupca711e4a;

  /// No description provided for @topupd84c4984.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get topupd84c4984;

  /// No description provided for @topup558ab445.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get topup558ab445;

  /// No description provided for @topup36bba20f.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get topup36bba20f;

  /// No description provided for @topupf3471840.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get topupf3471840;

  /// No description provided for @topup82e926cb.
  ///
  /// In en, this message translates to:
  /// **'Received at'**
  String get topup82e926cb;

  /// No description provided for @topupc875c278.
  ///
  /// In en, this message translates to:
  /// **'Refresh request status'**
  String get topupc875c278;

  /// No description provided for @topup066febb5.
  ///
  /// In en, this message translates to:
  /// **'View all requests'**
  String get topup066febb5;

  /// No description provided for @topupe5f00560.
  ///
  /// In en, this message translates to:
  /// **'Top-up request history'**
  String get topupe5f00560;

  /// No description provided for @topup102df0aa.
  ///
  /// In en, this message translates to:
  /// **'You have not submitted a top-up request yet.'**
  String get topup102df0aa;

  /// No description provided for @topup152d5282.
  ///
  /// In en, this message translates to:
  /// **'My wallet'**
  String get topup152d5282;

  /// No description provided for @topup45513074.
  ///
  /// In en, this message translates to:
  /// **'Top-up history'**
  String get topup45513074;

  /// No description provided for @topupf3b40143.
  ///
  /// In en, this message translates to:
  /// **'Back to offers'**
  String get topupf3b40143;

  /// No description provided for @topupcb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get topupcb822418;

  /// No description provided for @captain278d3e8e.
  ///
  /// In en, this message translates to:
  /// **'Update your location to receive requests. Check GPS and connectivity.'**
  String get captain278d3e8e;

  /// No description provided for @captainf6174ae5.
  ///
  /// In en, this message translates to:
  /// **'The dashboard could not be loaded. Retry.'**
  String get captainf6174ae5;

  /// No description provided for @captain5d90693a.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current ride action to be confirmed, then retry.'**
  String get captain5d90693a;

  /// No description provided for @captain0e3338be.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to start receiving rides.'**
  String get captain0e3338be;

  /// No description provided for @captain13e4b9b7.
  ///
  /// In en, this message translates to:
  /// **'Your location could not be confirmed. Check permission and connectivity, then retry.'**
  String get captain13e4b9b7;

  /// No description provided for @captain199848b2.
  ///
  /// In en, this message translates to:
  /// **'You reached the debt limit. Open your payment statement; availability returns after an approved payment reduces debt below the limit.'**
  String get captain199848b2;

  /// No description provided for @captain9c360bcd.
  ///
  /// In en, this message translates to:
  /// **'Complete your current ride before going offline.'**
  String get captain9c360bcd;

  /// No description provided for @captain37cdd354.
  ///
  /// In en, this message translates to:
  /// **'Your captain account is not approved. Contact support.'**
  String get captain37cdd354;

  /// No description provided for @captain0028fab8.
  ///
  /// In en, this message translates to:
  /// **'Your captain account is temporarily suspended. Check app notices or contact support.'**
  String get captain0028fab8;

  /// No description provided for @captain20d90f0e.
  ///
  /// In en, this message translates to:
  /// **'Update your location to receive rides. Check GPS and connectivity.'**
  String get captain20d90f0e;

  /// No description provided for @captaineaa58c01.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Enable them in phone settings.'**
  String get captaineaa58c01;

  /// No description provided for @captainae5e5078.
  ///
  /// In en, this message translates to:
  /// **'Allow location access while using the app in its settings.'**
  String get captainae5e5078;

  /// No description provided for @captainb91e4e01.
  ///
  /// In en, this message translates to:
  /// **'Location is enabled, but no fix is available yet. Try near a window or outdoors, then go online.'**
  String get captainb91e4e01;

  /// No description provided for @captain4d71e045.
  ///
  /// In en, this message translates to:
  /// **'Your device location could not be read. Check permission and retry.'**
  String get captain4d71e045;

  /// No description provided for @captain0c8c1ed6.
  ///
  /// In en, this message translates to:
  /// **'Your session on this device has ended. Sign out and log in again.'**
  String get captain0c8c1ed6;

  /// No description provided for @captain6779d8a9.
  ///
  /// In en, this message translates to:
  /// **'The server rejected your status update. Log in again; contact support if the issue persists.'**
  String get captain6779d8a9;

  /// No description provided for @captain1c8a49fe.
  ///
  /// In en, this message translates to:
  /// **'Your captain account could not be verified. Log in again.'**
  String get captain1c8a49fe;

  /// No description provided for @captain96de460e.
  ///
  /// In en, this message translates to:
  /// **'Your online status could not be saved on the server. Retry.'**
  String get captain96de460e;

  /// No description provided for @captain07ec3438.
  ///
  /// In en, this message translates to:
  /// **'Your location was found, but could not be sent to the server. Check connectivity and go online again.'**
  String get captain07ec3438;

  /// No description provided for @captain4d8aa1e0.
  ///
  /// In en, this message translates to:
  /// **'Purchase instructions appear before request acceptance.'**
  String get captain4d8aa1e0;

  /// No description provided for @captain4bd12227.
  ///
  /// In en, this message translates to:
  /// **'You cannot accept a request while on an active ride'**
  String get captain4bd12227;

  /// No description provided for @captain961fe263.
  ///
  /// In en, this message translates to:
  /// **'This request is unavailable'**
  String get captain961fe263;

  /// No description provided for @captaind292c0f8.
  ///
  /// In en, this message translates to:
  /// **'This request is no longer available'**
  String get captaind292c0f8;

  /// No description provided for @captain61f278b9.
  ///
  /// In en, this message translates to:
  /// **'Ride accepted'**
  String get captain61f278b9;

  /// No description provided for @captain6aad32b8.
  ///
  /// In en, this message translates to:
  /// **'Another captain accepted this ride first'**
  String get captain6aad32b8;

  /// No description provided for @captaine28fe29b.
  ///
  /// In en, this message translates to:
  /// **'You are currently on another ride'**
  String get captaine28fe29b;

  /// No description provided for @captain817dceb0.
  ///
  /// In en, this message translates to:
  /// **'The request could not be accepted. It may no longer be available; refresh and retry.'**
  String get captain817dceb0;

  /// No description provided for @captain3e4011c0.
  ///
  /// In en, this message translates to:
  /// **'The request could not be declined'**
  String get captain3e4011c0;

  /// No description provided for @captain9947a71a.
  ///
  /// In en, this message translates to:
  /// **'This step is unavailable'**
  String get captain9947a71a;

  /// No description provided for @captain82963d4d.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get captain82963d4d;

  /// No description provided for @captain583a75cf.
  ///
  /// In en, this message translates to:
  /// **'Detailed ride statement'**
  String get captain583a75cf;

  /// No description provided for @captainfee7f899.
  ///
  /// In en, this message translates to:
  /// **'Server-approved amount to collect from the customer'**
  String get captainfee7f899;

  /// No description provided for @captaind922438f.
  ///
  /// In en, this message translates to:
  /// **'After wallet payments, discounts, and prior amounts due, as confirmed by the server'**
  String get captaind922438f;

  /// No description provided for @captain7f29d28a.
  ///
  /// In en, this message translates to:
  /// **'Base fare'**
  String get captain7f29d28a;

  /// No description provided for @captaine8ea6cc8.
  ///
  /// In en, this message translates to:
  /// **'Waiting charges'**
  String get captaine8ea6cc8;

  /// No description provided for @captainb593a645.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get captainb593a645;

  /// No description provided for @captain48f62d04.
  ///
  /// In en, this message translates to:
  /// **'Full incentive'**
  String get captain48f62d04;

  /// No description provided for @captaind8148f15.
  ///
  /// In en, this message translates to:
  /// **'Previous company amount due'**
  String get captaind8148f15;

  /// No description provided for @captaindf9cee25.
  ///
  /// In en, this message translates to:
  /// **'Customer statement total'**
  String get captaindf9cee25;

  /// No description provided for @captainccfb9ede.
  ///
  /// In en, this message translates to:
  /// **'Paid from customer wallet'**
  String get captainccfb9ede;

  /// No description provided for @captain8b296d76.
  ///
  /// In en, this message translates to:
  /// **'Collect cash from customer'**
  String get captain8b296d76;

  /// No description provided for @captain3bdc9404.
  ///
  /// In en, this message translates to:
  /// **'Company commission'**
  String get captain3bdc9404;

  /// No description provided for @captain79fe765a.
  ///
  /// In en, this message translates to:
  /// **'Company incentive share'**
  String get captain79fe765a;

  /// No description provided for @captainc3b788c0.
  ///
  /// In en, this message translates to:
  /// **'Your incentive share'**
  String get captainc3b788c0;

  /// No description provided for @captain986f250b.
  ///
  /// In en, this message translates to:
  /// **'Your net entitlement'**
  String get captain986f250b;

  /// No description provided for @captaind3aa4069.
  ///
  /// In en, this message translates to:
  /// **'Settlement account change'**
  String get captaind3aa4069;

  /// No description provided for @captain233aea82.
  ///
  /// In en, this message translates to:
  /// **'Settlement balance after ride'**
  String get captain233aea82;

  /// No description provided for @captain3ef541b9.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get captain3ef541b9;

  /// No description provided for @captainaa0eba0d.
  ///
  /// In en, this message translates to:
  /// **'The statement could not be shown. Pull to refresh and retry.'**
  String get captainaa0eba0d;

  /// No description provided for @captaindb6c6f4e.
  ///
  /// In en, this message translates to:
  /// **'The phone app could not be opened'**
  String get captaindb6c6f4e;

  /// No description provided for @captain2b50d9f0.
  ///
  /// In en, this message translates to:
  /// **'Administration has not configured support details'**
  String get captain2b50d9f0;

  /// No description provided for @captainc3bb52b7.
  ///
  /// In en, this message translates to:
  /// **'Customer support'**
  String get captainc3bb52b7;

  /// No description provided for @captainebfead75.
  ///
  /// In en, this message translates to:
  /// **'Call customer support'**
  String get captainebfead75;

  /// No description provided for @captain56a1b88a.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened'**
  String get captain56a1b88a;

  /// No description provided for @captain14d5786f.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get captain14d5786f;

  /// No description provided for @captainbfcf4830.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get captainbfcf4830;

  /// No description provided for @captainf3683943.
  ///
  /// In en, this message translates to:
  /// **'My rides'**
  String get captainf3683943;

  /// No description provided for @captain166aea7d.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get captain166aea7d;

  /// No description provided for @captain62d6fd3d.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get captain62d6fd3d;

  /// No description provided for @captain478c486f.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get captain478c486f;

  /// No description provided for @captain00eab31f.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get captain00eab31f;

  /// No description provided for @captain2443fd0d.
  ///
  /// In en, this message translates to:
  /// **'Ride offers could not be synchronized. Refresh and check connectivity.'**
  String get captain2443fd0d;

  /// No description provided for @captainee9201f4.
  ///
  /// In en, this message translates to:
  /// **'New ride request'**
  String get captainee9201f4;

  /// No description provided for @captain99f2c8a6.
  ///
  /// In en, this message translates to:
  /// **'Current ride'**
  String get captain99f2c8a6;

  /// No description provided for @captaind6004d47.
  ///
  /// In en, this message translates to:
  /// **'Captain offers and rewards'**
  String get captaind6004d47;

  /// No description provided for @captain4abac2da.
  ///
  /// In en, this message translates to:
  /// **'VETO Market assignment'**
  String get captain4abac2da;

  /// No description provided for @captaindee9712a.
  ///
  /// In en, this message translates to:
  /// **'Today and account details'**
  String get captaindee9712a;

  /// No description provided for @captain33e9156d.
  ///
  /// In en, this message translates to:
  /// **'Today’s summary — Cairo time'**
  String get captain33e9156d;

  /// No description provided for @captainb13e131c.
  ///
  /// In en, this message translates to:
  /// **'Today’s ride count'**
  String get captainb13e131c;

  /// No description provided for @captain4c103c55.
  ///
  /// In en, this message translates to:
  /// **'Today’s income (net rides)'**
  String get captain4c103c55;

  /// No description provided for @captainf8e8dfb6.
  ///
  /// In en, this message translates to:
  /// **'Today’s summary could not be refreshed. Pull to retry.'**
  String get captainf8e8dfb6;

  /// No description provided for @captain80098418.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get captain80098418;

  /// No description provided for @captainfcd34918.
  ///
  /// In en, this message translates to:
  /// **'Captain app'**
  String get captainfcd34918;

  /// No description provided for @captain8ce3e0cc.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get captain8ce3e0cc;

  /// No description provided for @captain8448690a.
  ///
  /// In en, this message translates to:
  /// **'Confirming status…'**
  String get captain8448690a;

  /// No description provided for @captain7b3b2ab3.
  ///
  /// In en, this message translates to:
  /// **'Go offline'**
  String get captain7b3b2ab3;

  /// No description provided for @captainb074b07c.
  ///
  /// In en, this message translates to:
  /// **'Go online'**
  String get captainb074b07c;

  /// No description provided for @captain3c02a45d.
  ///
  /// In en, this message translates to:
  /// **'Store order'**
  String get captain3c02a45d;

  /// No description provided for @captainbef9383c.
  ///
  /// In en, this message translates to:
  /// **'This assignment was allocated automatically. No acceptance or rejection is required.'**
  String get captainbef9383c;

  /// No description provided for @captainf86852a4.
  ///
  /// In en, this message translates to:
  /// **'Track assignment and go to store'**
  String get captainf86852a4;

  /// No description provided for @captaind83efdf5.
  ///
  /// In en, this message translates to:
  /// **'Review rides, VETO Market orders, and their statements.'**
  String get captaind83efdf5;

  /// No description provided for @captain4bf40b6a.
  ///
  /// In en, this message translates to:
  /// **'Market history could not be loaded. Refresh or contact support.'**
  String get captain4bf40b6a;

  /// No description provided for @captainaf4b3178.
  ///
  /// In en, this message translates to:
  /// **'VETO Market orders'**
  String get captainaf4b3178;

  /// No description provided for @captaincf83fb17.
  ///
  /// In en, this message translates to:
  /// **'No previous rides'**
  String get captaincf83fb17;

  /// No description provided for @captainda3de6e3.
  ///
  /// In en, this message translates to:
  /// **'Completed rides appear here.'**
  String get captainda3de6e3;

  /// No description provided for @captain2823f378.
  ///
  /// In en, this message translates to:
  /// **'Earnings and settlements'**
  String get captain2823f378;

  /// No description provided for @pendingDraftUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The pending request on this device could not be read. Retry before sending a new request.'**
  String get pendingDraftUnavailable;

  /// No description provided for @suggestionConfirmedStorage.
  ///
  /// In en, this message translates to:
  /// **'Your suggestion reached review, but the local retry receipt could not be cleared. Retry to close without submitting again.'**
  String get suggestionConfirmedStorage;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @captainReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Captain referral code'**
  String get captainReferralCode;

  /// No description provided for @captainCodeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your code could not be loaded. Retry.'**
  String get captainCodeLoadFailed;

  /// No description provided for @cancelServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cancellation is unavailable on this server version. Your request was not confirmed as cancelled; contact support.'**
  String get cancelServiceUnavailable;

  /// No description provided for @cancelAcceptanceRace.
  ///
  /// In en, this message translates to:
  /// **'A captain accepted while you were cancelling. Review the updated ride status.'**
  String get cancelAcceptanceRace;

  /// No description provided for @cancelFinancialGuard.
  ///
  /// In en, this message translates to:
  /// **'The server stopped cancellation to protect your balance because of a financial conflict. Send the ride ID to support.'**
  String get cancelFinancialGuard;

  /// No description provided for @cancelSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your session could not be verified. Log in and review request status.'**
  String get cancelSessionUnavailable;

  /// No description provided for @cancelUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The server has not confirmed cancellation. Refresh request status before retrying, and reconnect if offline.'**
  String get cancelUnconfirmed;

  /// No description provided for @bookingCreatedDistributionFailed.
  ///
  /// In en, this message translates to:
  /// **'Your request was created, but delivery of captain offers was not confirmed. Refresh its status; do not create another request.'**
  String get bookingCreatedDistributionFailed;

  /// No description provided for @bookingCreateUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Request creation was not confirmed. Refresh your rides before retrying to avoid a duplicate request.'**
  String get bookingCreateUnconfirmed;

  /// No description provided for @bookingCreateRejected.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this request. Review the address, price and payment method, or contact support if the problem persists.'**
  String get bookingCreateRejected;

  /// No description provided for @bookingCoverageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Booking is unavailable in this city. You can submit an address suggestion for review, but cannot book outside service coverage.'**
  String get bookingCoverageUnavailable;

  /// No description provided for @bookingSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your account session could not be verified. Log in and check your rides before requesting again.'**
  String get bookingSessionUnavailable;

  /// No description provided for @bookingPromoExpired.
  ///
  /// In en, this message translates to:
  /// **'This promo code expired. Review the discount before requesting.'**
  String get bookingPromoExpired;

  /// No description provided for @bookingPromoTotalLimit.
  ///
  /// In en, this message translates to:
  /// **'This code reached its usage limit.'**
  String get bookingPromoTotalLimit;

  /// No description provided for @bookingPromoPeopleLimit.
  ///
  /// In en, this message translates to:
  /// **'This offer reached its customer limit.'**
  String get bookingPromoPeopleLimit;

  /// No description provided for @bookingPromoUserLimit.
  ///
  /// In en, this message translates to:
  /// **'You reached your usage limit for this code.'**
  String get bookingPromoUserLimit;

  /// No description provided for @bookingPromoInactive.
  ///
  /// In en, this message translates to:
  /// **'This promo code is inactive.'**
  String get bookingPromoInactive;

  /// No description provided for @bookingPromoNotStarted.
  ///
  /// In en, this message translates to:
  /// **'This offer has not started.'**
  String get bookingPromoNotStarted;

  /// No description provided for @bookingPromoInvalid.
  ///
  /// In en, this message translates to:
  /// **'This promo code was not found.'**
  String get bookingPromoInvalid;

  /// No description provided for @bookingPromoReview.
  ///
  /// In en, this message translates to:
  /// **'Administration must review this code.'**
  String get bookingPromoReview;

  /// No description provided for @bookingStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Ride status could not be confirmed by the server. Refresh again or contact support; do not create a second request.'**
  String get bookingStatusUnavailable;

  /// No description provided for @bookingStillSearching.
  ///
  /// In en, this message translates to:
  /// **'Status refreshed: still searching for a captain.'**
  String get bookingStillSearching;

  /// No description provided for @bookingRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Your ride request was cancelled.'**
  String get bookingRequestCancelled;

  /// No description provided for @captainCodePending.
  ///
  /// In en, this message translates to:
  /// **'Your referral code is awaiting administration setup'**
  String get captainCodePending;

  /// No description provided for @captainCodeCapacityHelp.
  ///
  /// In en, this message translates to:
  /// **'Current code capacity is full. Your account, rides and accounting remain available; no unapproved code or QR will be shown.'**
  String get captainCodeCapacityHelp;

  /// No description provided for @registrationb214d2cc.
  ///
  /// In en, this message translates to:
  /// **'Application status updated'**
  String get registrationb214d2cc;

  /// No description provided for @registration9496b651.
  ///
  /// In en, this message translates to:
  /// **'Your application could not be loaded. Check the connection and retry.'**
  String get registration9496b651;

  /// No description provided for @registration3cfb232e.
  ///
  /// In en, this message translates to:
  /// **'Your birth date does not match the national ID. Review and correct your details.'**
  String get registration3cfb232e;

  /// No description provided for @registration3f4f4ac8.
  ///
  /// In en, this message translates to:
  /// **'A detail is missing or invalid. Review your personal and vehicle details.'**
  String get registration3f4f4ac8;

  /// No description provided for @registration0e85de07.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Log in to VETO before submitting.'**
  String get registration0e85de07;

  /// No description provided for @registration8574ec84.
  ///
  /// In en, this message translates to:
  /// **'Your account has a different role. Contact VETO administration to review the application without changing your account.'**
  String get registration8574ec84;

  /// No description provided for @registrationad110af9.
  ///
  /// In en, this message translates to:
  /// **'An image is invalid. Use JPG, PNG or WebP smaller than 8 MB.'**
  String get registrationad110af9;

  /// No description provided for @registration6d21b4e2.
  ///
  /// In en, this message translates to:
  /// **'This application has already been reviewed. Contact administration to change details.'**
  String get registration6d21b4e2;

  /// No description provided for @registrationb23d2d69.
  ///
  /// In en, this message translates to:
  /// **'Application images could not be saved. Retry, or contact support if the problem persists.'**
  String get registrationb23d2d69;

  /// No description provided for @registrationb4eecfa9.
  ///
  /// In en, this message translates to:
  /// **'Captain applications are currently unavailable. Contact support.'**
  String get registrationb4eecfa9;

  /// No description provided for @registration6d45fa59.
  ///
  /// In en, this message translates to:
  /// **'Service permissions prevented saving your application. Contact VETO administration.'**
  String get registration6d45fa59;

  /// No description provided for @registration6a52abd7.
  ///
  /// In en, this message translates to:
  /// **'The connection was interrupted during submission. Reconnect and check your application status before retrying.'**
  String get registration6a52abd7;

  /// No description provided for @registration41d01feb.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed. Check your connection and retry.'**
  String get registration41d01feb;

  /// No description provided for @registration53b824de.
  ///
  /// In en, this message translates to:
  /// **'Submission was not confirmed. Check application status before retrying, or contact support.'**
  String get registration53b824de;

  /// No description provided for @registration3659b0f0.
  ///
  /// In en, this message translates to:
  /// **'Make sure the image is clear and all edges are visible before uploading.'**
  String get registration3659b0f0;

  /// No description provided for @registrationb99f84a8.
  ///
  /// In en, this message translates to:
  /// **'Choose again'**
  String get registrationb99f84a8;

  /// No description provided for @registration09a46335.
  ///
  /// In en, this message translates to:
  /// **'Use image'**
  String get registration09a46335;

  /// No description provided for @registration5460351a.
  ///
  /// In en, this message translates to:
  /// **'Your national ID and birth date do not match. Check the first seven ID digits and select the correct birth date.'**
  String get registration5460351a;

  /// No description provided for @registration9709cc61.
  ///
  /// In en, this message translates to:
  /// **'Some images are missing. Add all required images first.'**
  String get registration9709cc61;

  /// No description provided for @registration93a7a9fd.
  ///
  /// In en, this message translates to:
  /// **'Your application was received, but the team code was not saved. Review it with support.'**
  String get registration93a7a9fd;

  /// No description provided for @registration217825d5.
  ///
  /// In en, this message translates to:
  /// **'Your application was received. The VETO team will review it.'**
  String get registration217825d5;

  /// No description provided for @registrationd5a02f88.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get registrationd5a02f88;

  /// No description provided for @registrationcd844480.
  ///
  /// In en, this message translates to:
  /// **'Enter your 14-digit national ID'**
  String get registrationcd844480;

  /// No description provided for @registration3190ac91.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Egyptian mobile number'**
  String get registration3190ac91;

  /// No description provided for @registration056e90e2.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid manufacture year'**
  String get registration056e90e2;

  /// No description provided for @registration50f73ca9.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get registration50f73ca9;

  /// No description provided for @registrationb44d35b0.
  ///
  /// In en, this message translates to:
  /// **'Join VETO captains'**
  String get registrationb44d35b0;

  /// No description provided for @registration71763395.
  ///
  /// In en, this message translates to:
  /// **'Enter your details, photograph your documents and submit your application. The VETO team will review it and contact you.'**
  String get registration71763395;

  /// No description provided for @registrationb5e7acfe.
  ///
  /// In en, this message translates to:
  /// **'Your Egyptian mobile number'**
  String get registrationb5e7acfe;

  /// No description provided for @registration6c2ab9bd.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registration6c2ab9bd;

  /// No description provided for @registration6541a8c6.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get registration6541a8c6;

  /// No description provided for @registration2625e95c.
  ///
  /// In en, this message translates to:
  /// **'Team code (optional)'**
  String get registration2625e95c;

  /// No description provided for @registration3d9e6c97.
  ///
  /// In en, this message translates to:
  /// **'Check the team code'**
  String get registration3d9e6c97;

  /// No description provided for @registration33646453.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get registration33646453;

  /// No description provided for @registration6f667536.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 18'**
  String get registration6f667536;

  /// No description provided for @registration39f0be0f.
  ///
  /// In en, this message translates to:
  /// **'Operating area'**
  String get registration39f0be0f;

  /// No description provided for @registration491712d6.
  ///
  /// In en, this message translates to:
  /// **'Full address'**
  String get registration491712d6;

  /// No description provided for @registration9d55adc6.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get registration9d55adc6;

  /// No description provided for @registration89aef3a3.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get registration89aef3a3;

  /// No description provided for @registration80a51d6a.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get registration80a51d6a;

  /// No description provided for @registration0adf93a2.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get registration0adf93a2;

  /// No description provided for @registrationc3e10fad.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get registrationc3e10fad;

  /// No description provided for @registrationae42906b.
  ///
  /// In en, this message translates to:
  /// **'Manufacture year'**
  String get registrationae42906b;

  /// No description provided for @registration041b469d.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get registration041b469d;

  /// No description provided for @registration67fa5912.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get registration67fa5912;

  /// No description provided for @registration427f9e30.
  ///
  /// In en, this message translates to:
  /// **'Good lighting • no glare • all edges visible\nVehicle registration is required for cars and motorcycles.'**
  String get registration427f9e30;

  /// No description provided for @registratione52577dc.
  ///
  /// In en, this message translates to:
  /// **'✓ Image stored privately'**
  String get registratione52577dc;

  /// No description provided for @registration33b4d832.
  ///
  /// In en, this message translates to:
  /// **'✓ Image ready to submit'**
  String get registration33b4d832;

  /// No description provided for @registrationb0014815.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get registrationb0014815;

  /// No description provided for @registrationa3f9bb7c.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get registrationa3f9bb7c;

  /// No description provided for @registration3a375696.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get registration3a375696;

  /// No description provided for @registration0b2cbdfb.
  ///
  /// In en, this message translates to:
  /// **'Review your details before submitting'**
  String get registration0b2cbdfb;

  /// No description provided for @registration3a64c036.
  ///
  /// In en, this message translates to:
  /// **'Make sure your details and images are clear and correct, then submit to the VETO team. Keep the original documents for review.'**
  String get registration3a64c036;

  /// No description provided for @registration35516879.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get registration35516879;

  /// No description provided for @registration12e27be4.
  ///
  /// In en, this message translates to:
  /// **'Initial review completed'**
  String get registration12e27be4;

  /// No description provided for @registrationc7dac90b.
  ///
  /// In en, this message translates to:
  /// **'You were approved. You can sign in to your captain account as usual.'**
  String get registrationc7dac90b;

  /// No description provided for @registration6a4555f7.
  ///
  /// In en, this message translates to:
  /// **'Your status will be updated here after review.'**
  String get registration6a4555f7;

  /// No description provided for @registration541ca893.
  ///
  /// In en, this message translates to:
  /// **'Your application passed initial review. The VETO team will contact you to complete onboarding.'**
  String get registration541ca893;

  /// No description provided for @registration2a0486aa.
  ///
  /// In en, this message translates to:
  /// **'You can follow review team notes here.'**
  String get registration2a0486aa;

  /// No description provided for @registrationa9e9d067.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get registrationa9e9d067;

  /// No description provided for @registration27ae3a38.
  ///
  /// In en, this message translates to:
  /// **'Select your birth date'**
  String get registration27ae3a38;

  /// No description provided for @registration7b27fbaf.
  ///
  /// In en, this message translates to:
  /// **'Complete all documents'**
  String get registration7b27fbaf;

  /// No description provided for @registration322b7b61.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get registration322b7b61;

  /// No description provided for @applicationPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get applicationPortrait;

  /// No description provided for @applicationIdFront.
  ///
  /// In en, this message translates to:
  /// **'National ID • front'**
  String get applicationIdFront;

  /// No description provided for @applicationIdBack.
  ///
  /// In en, this message translates to:
  /// **'National ID • back'**
  String get applicationIdBack;

  /// No description provided for @applicationLicenseFront.
  ///
  /// In en, this message translates to:
  /// **'Driving licence • front'**
  String get applicationLicenseFront;

  /// No description provided for @applicationLicenseBack.
  ///
  /// In en, this message translates to:
  /// **'Driving licence • back'**
  String get applicationLicenseBack;

  /// No description provided for @applicationVehicleFront.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration • front'**
  String get applicationVehicleFront;

  /// No description provided for @applicationVehicleBack.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration • back'**
  String get applicationVehicleBack;

  /// No description provided for @applicationPending.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get applicationPending;

  /// No description provided for @applicationNeedsInfo.
  ///
  /// In en, this message translates to:
  /// **'More information required'**
  String get applicationNeedsInfo;

  /// No description provided for @applicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get applicationApproved;

  /// No description provided for @applicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get applicationRejected;

  /// No description provided for @applicationPersonalStep.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get applicationPersonalStep;

  /// No description provided for @applicationVehicleStep.
  ///
  /// In en, this message translates to:
  /// **'Vehicle details'**
  String get applicationVehicleStep;

  /// No description provided for @applicationDocumentsStep.
  ///
  /// In en, this message translates to:
  /// **'Document images'**
  String get applicationDocumentsStep;

  /// No description provided for @applicationReviewStep.
  ///
  /// In en, this message translates to:
  /// **'Review and submit'**
  String get applicationReviewStep;

  /// No description provided for @applicationStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 4 • {label}'**
  String applicationStep(int step, String label);

  /// No description provided for @applicationDocumentCount.
  ///
  /// In en, this message translates to:
  /// **'Documents: {count} / 7'**
  String applicationDocumentCount(int count);

  /// No description provided for @presencecbc96ded.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get presencecbc96ded;

  /// No description provided for @presencee6302b21.
  ///
  /// In en, this message translates to:
  /// **'Updating connection and location'**
  String get presencee6302b21;

  /// No description provided for @presencea781f074.
  ///
  /// In en, this message translates to:
  /// **'Online and ready for rides'**
  String get presencea781f074;

  /// No description provided for @presence0aeaba38.
  ///
  /// In en, this message translates to:
  /// **'Busy with a ride'**
  String get presence0aeaba38;

  /// No description provided for @presence05691d14.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted'**
  String get presence05691d14;

  /// No description provided for @presencee28d58d1.
  ///
  /// In en, this message translates to:
  /// **'Account unavailable'**
  String get presencee28d58d1;

  /// No description provided for @presencec81ed735.
  ///
  /// In en, this message translates to:
  /// **'Start when you are ready. Your location is checked before receiving requests.'**
  String get presencec81ed735;

  /// No description provided for @presencee267108e.
  ///
  /// In en, this message translates to:
  /// **'Confirming your status with the server…'**
  String get presencee267108e;

  /// No description provided for @presence6d021561.
  ///
  /// In en, this message translates to:
  /// **'You will be alerted by sound and vibration when a suitable offer arrives.'**
  String get presence6d021561;

  /// No description provided for @presence2dbd1bcf.
  ///
  /// In en, this message translates to:
  /// **'Complete your current task. The server checks whether your availability can change.'**
  String get presence2dbd1bcf;

  /// No description provided for @presence2038f1aa.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting automatically. Your receiving status has not yet been confirmed.'**
  String get presence2038f1aa;

  /// No description provided for @presence94d187fa.
  ///
  /// In en, this message translates to:
  /// **'Review approval and settlement status, or contact support.'**
  String get presence94d187fa;

  /// No description provided for @presence7b43f77f.
  ///
  /// In en, this message translates to:
  /// **'Confirming'**
  String get presence7b43f77f;

  /// No description provided for @presence7b3b2ab3.
  ///
  /// In en, this message translates to:
  /// **'Stop receiving rides'**
  String get presence7b3b2ab3;

  /// No description provided for @presence52edad40.
  ///
  /// In en, this message translates to:
  /// **'Start receiving rides'**
  String get presence52edad40;

  /// No description provided for @presenceecaefa5c.
  ///
  /// In en, this message translates to:
  /// **'Offer expired'**
  String get presenceecaefa5c;

  /// No description provided for @captainOfferSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds left to accept'**
  String captainOfferSeconds(int seconds);

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride chat'**
  String get chatTitle;

  /// No description provided for @chatCaptain.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get chatCaptain;

  /// No description provided for @chatCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get chatCustomer;

  /// No description provided for @chatNotReady.
  ///
  /// In en, this message translates to:
  /// **'Chat opens after a captain accepts the ride.'**
  String get chatNotReady;

  /// No description provided for @chatParticipantOnly.
  ///
  /// In en, this message translates to:
  /// **'Chat is available only to this ride’s customer and captain.'**
  String get chatParticipantOnly;

  /// No description provided for @chatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Messages could not be loaded. Check your connection and retry.'**
  String get chatLoadFailed;

  /// No description provided for @chatSendUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Message delivery was not confirmed. Check the chat, then retry the same message.'**
  String get chatSendUnconfirmed;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with the other ride participant'**
  String get chatEmpty;

  /// No description provided for @chatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatYou;

  /// No description provided for @chatRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatRetry;

  /// No description provided for @chatCompose.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get chatCompose;

  /// No description provided for @chatQuickReplies.
  ///
  /// In en, this message translates to:
  /// **'Quick replies · tap to send'**
  String get chatQuickReplies;

  /// No description provided for @chatRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Messages were sent too quickly. Wait a moment before retrying.'**
  String get chatRateLimited;

  /// No description provided for @chatRequestConflict.
  ///
  /// In en, this message translates to:
  /// **'The server detected a message request conflict. Check the chat and contact support if it persists.'**
  String get chatRequestConflict;

  /// No description provided for @chatInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a message of no more than 1,000 characters.'**
  String get chatInvalidMessage;

  /// No description provided for @chatSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your session could not be verified. Log in before sending a message.'**
  String get chatSessionUnavailable;

  /// No description provided for @replyCustomerWaiting.
  ///
  /// In en, this message translates to:
  /// **'Hello, I am waiting at the pickup point.'**
  String get replyCustomerWaiting;

  /// No description provided for @replyCustomerEta.
  ///
  /// In en, this message translates to:
  /// **'Could you let me know your estimated arrival time?'**
  String get replyCustomerEta;

  /// No description provided for @replyCustomerGate.
  ///
  /// In en, this message translates to:
  /// **'I am at the gate now.'**
  String get replyCustomerGate;

  /// No description provided for @replyCustomerCall.
  ///
  /// In en, this message translates to:
  /// **'Could you call me when you arrive?'**
  String get replyCustomerCall;

  /// No description provided for @replyCustomerReady.
  ///
  /// In en, this message translates to:
  /// **'Thank you, I will be ready.'**
  String get replyCustomerReady;

  /// No description provided for @replyCaptainEnRoute.
  ///
  /// In en, this message translates to:
  /// **'Hello, I am on my way to you.'**
  String get replyCaptainEnRoute;

  /// No description provided for @replyCaptainArrived.
  ///
  /// In en, this message translates to:
  /// **'I have arrived at the pickup point and am waiting for you.'**
  String get replyCaptainArrived;

  /// No description provided for @replyCaptainMeeting.
  ///
  /// In en, this message translates to:
  /// **'Could you confirm the meeting point?'**
  String get replyCaptainMeeting;

  /// No description provided for @replyCaptainLandmark.
  ///
  /// In en, this message translates to:
  /// **'Could you share a nearby landmark?'**
  String get replyCaptainLandmark;

  /// No description provided for @replyCaptainUpdate.
  ///
  /// In en, this message translates to:
  /// **'Thank you, I will let you know when I arrive.'**
  String get replyCaptainUpdate;

  /// No description provided for @receiptf1d6d15f.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get receiptf1d6d15f;

  /// No description provided for @receiptd87ae61b.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get receiptd87ae61b;

  /// No description provided for @receiptc74d3b21.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get receiptc74d3b21;

  /// No description provided for @receipt30d5d6b5.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get receipt30d5d6b5;

  /// No description provided for @receipt2de6d001.
  ///
  /// In en, this message translates to:
  /// **'Captain on the way'**
  String get receipt2de6d001;

  /// No description provided for @receipt39ac9d30.
  ///
  /// In en, this message translates to:
  /// **'Captain arrived'**
  String get receipt39ac9d30;

  /// No description provided for @receiptc20f27ab.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get receiptc20f27ab;

  /// No description provided for @receipt42816de2.
  ///
  /// In en, this message translates to:
  /// **'VETO Car'**
  String get receipt42816de2;

  /// No description provided for @receiptf8748198.
  ///
  /// In en, this message translates to:
  /// **'VETO Motorcycle'**
  String get receiptf8748198;

  /// No description provided for @receiptccd99512.
  ///
  /// In en, this message translates to:
  /// **'VETO Package'**
  String get receiptccd99512;

  /// No description provided for @receiptc99f71b7.
  ///
  /// In en, this message translates to:
  /// **'VETO ride'**
  String get receiptc99f71b7;

  /// No description provided for @receiptdadf5afd.
  ///
  /// In en, this message translates to:
  /// **'No captain was assigned to this ride'**
  String get receiptdadf5afd;

  /// No description provided for @receipt2f225a03.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get receipt2f225a03;

  /// No description provided for @receiptc634600a.
  ///
  /// In en, this message translates to:
  /// **'Your captain'**
  String get receiptc634600a;

  /// No description provided for @receipte12a8659.
  ///
  /// In en, this message translates to:
  /// **'Ride details'**
  String get receipte12a8659;

  /// No description provided for @receipt4d7d679f.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get receipt4d7d679f;

  /// No description provided for @receipt97fe3fe5.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get receipt97fe3fe5;

  /// No description provided for @receipt4fe4aa51.
  ///
  /// In en, this message translates to:
  /// **'Captain details could not be refreshed'**
  String get receipt4fe4aa51;

  /// No description provided for @receipt17d786d8.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get receipt17d786d8;

  /// No description provided for @receipt7f29d28a.
  ///
  /// In en, this message translates to:
  /// **'Base fare'**
  String get receipt7f29d28a;

  /// No description provided for @receipt4d1a2a15.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get receipt4d1a2a15;

  /// No description provided for @receipt6432e51d.
  ///
  /// In en, this message translates to:
  /// **'Incentive'**
  String get receipt6432e51d;

  /// No description provided for @receiptec9ccd93.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get receiptec9ccd93;

  /// No description provided for @receiptf28e3f71.
  ///
  /// In en, this message translates to:
  /// **'Previous amount due'**
  String get receiptf28e3f71;

  /// No description provided for @receiptc5496762.
  ///
  /// In en, this message translates to:
  /// **'Ride total'**
  String get receiptc5496762;

  /// No description provided for @receipta455b08a.
  ///
  /// In en, this message translates to:
  /// **'Not yet confirmed'**
  String get receipta455b08a;

  /// No description provided for @receipt48c3380c.
  ///
  /// In en, this message translates to:
  /// **'From wallet'**
  String get receipt48c3380c;

  /// No description provided for @receipt1881ccb3.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get receipt1881ccb3;

  /// No description provided for @receiptDistance.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String receiptDistance(String value);

  /// No description provided for @receiptMinutes.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String receiptMinutes(String value);

  /// No description provided for @receiptCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed {value}'**
  String receiptCompletedAt(String value);

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTitle;

  /// No description provided for @notificationReadAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationReadAll;

  /// No description provided for @notificationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationEmpty;

  /// No description provided for @notificationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be loaded. Tap to retry.'**
  String get notificationLoadFailed;

  /// No description provided for @notificationReadFailed.
  ///
  /// In en, this message translates to:
  /// **'This notification could not be marked as read. Please retry.'**
  String get notificationReadFailed;

  /// No description provided for @notificationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be updated'**
  String get notificationUpdateFailed;

  /// No description provided for @captainRide182cb52e.
  ///
  /// In en, this message translates to:
  /// **'Ride status refreshed'**
  String get captainRide182cb52e;

  /// No description provided for @captainRide0f653eb8.
  ///
  /// In en, this message translates to:
  /// **'This ride could not be found.'**
  String get captainRide0f653eb8;

  /// No description provided for @captainRide3acc32e9.
  ///
  /// In en, this message translates to:
  /// **'Ride status could not be verified. Refresh or contact support.'**
  String get captainRide3acc32e9;

  /// No description provided for @captainRide5332028e.
  ///
  /// In en, this message translates to:
  /// **'You are now heading to the customer.'**
  String get captainRide5332028e;

  /// No description provided for @captainRide73187c4e.
  ///
  /// In en, this message translates to:
  /// **'Your arrival has been recorded.'**
  String get captainRide73187c4e;

  /// No description provided for @captainRide3ab5268d.
  ///
  /// In en, this message translates to:
  /// **'The ride has started.'**
  String get captainRide3ab5268d;

  /// No description provided for @captainRided8d96922.
  ///
  /// In en, this message translates to:
  /// **'Ride status updated.'**
  String get captainRided8d96922;

  /// No description provided for @captainRidea042411e.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get captainRidea042411e;

  /// No description provided for @captainRide9947a71a.
  ///
  /// In en, this message translates to:
  /// **'This action is unavailable in the current ride state.'**
  String get captainRide9947a71a;

  /// No description provided for @captainRide3c0f919c.
  ///
  /// In en, this message translates to:
  /// **'Cancellation is available only before starting the ride.'**
  String get captainRide3c0f919c;

  /// No description provided for @captainRidef20a786e.
  ///
  /// In en, this message translates to:
  /// **'Cancellation eligibility could not be verified. Please retry.'**
  String get captainRidef20a786e;

  /// No description provided for @captainRidebe27c947.
  ///
  /// In en, this message translates to:
  /// **'Confirm ride cancellation'**
  String get captainRidebe27c947;

  /// No description provided for @captainRidefd11f805.
  ///
  /// In en, this message translates to:
  /// **'No compensation is currently due. Eligibility is checked again when you confirm.'**
  String get captainRidefd11f805;

  /// No description provided for @captainRidecb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get captainRidecb822418;

  /// No description provided for @captainRideadfc99d3.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get captainRideadfc99d3;

  /// No description provided for @captainRide82963d4d.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get captainRide82963d4d;

  /// No description provided for @captainRide54940fb7.
  ///
  /// In en, this message translates to:
  /// **'Ride invoice'**
  String get captainRide54940fb7;

  /// No description provided for @captainRide18b3b709.
  ///
  /// In en, this message translates to:
  /// **'Collection amount comes from the server invoice. Existing accounting and settlements apply.'**
  String get captainRide18b3b709;

  /// No description provided for @captainRide7f29d28a.
  ///
  /// In en, this message translates to:
  /// **'Base fare'**
  String get captainRide7f29d28a;

  /// No description provided for @captainRidee8ea6cc8.
  ///
  /// In en, this message translates to:
  /// **'Waiting charges'**
  String get captainRidee8ea6cc8;

  /// No description provided for @captainRideb593a645.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get captainRideb593a645;

  /// No description provided for @captainRide3eab5144.
  ///
  /// In en, this message translates to:
  /// **'Incentive'**
  String get captainRide3eab5144;

  /// No description provided for @captainRide500e1d79.
  ///
  /// In en, this message translates to:
  /// **'Previous amount collected for the company'**
  String get captainRide500e1d79;

  /// No description provided for @captainRidec5496762.
  ///
  /// In en, this message translates to:
  /// **'Ride total'**
  String get captainRidec5496762;

  /// No description provided for @captainRideb245e20d.
  ///
  /// In en, this message translates to:
  /// **'From customer wallet'**
  String get captainRideb245e20d;

  /// No description provided for @captainRide6b6e59d4.
  ///
  /// In en, this message translates to:
  /// **'Cash to collect from customer'**
  String get captainRide6b6e59d4;

  /// No description provided for @captainRide53f0a84e.
  ///
  /// In en, this message translates to:
  /// **'Company ride commission'**
  String get captainRide53f0a84e;

  /// No description provided for @captainRide79fe765a.
  ///
  /// In en, this message translates to:
  /// **'Company incentive share'**
  String get captainRide79fe765a;

  /// No description provided for @captainRide4bbacf57.
  ///
  /// In en, this message translates to:
  /// **'Your incentive share'**
  String get captainRide4bbacf57;

  /// No description provided for @captainRide9c8ac33a.
  ///
  /// In en, this message translates to:
  /// **'Your net ride entitlement'**
  String get captainRide9c8ac33a;

  /// No description provided for @captainRide493a9f67.
  ///
  /// In en, this message translates to:
  /// **'Settlement wallet change'**
  String get captainRide493a9f67;

  /// No description provided for @captainRide233aea82.
  ///
  /// In en, this message translates to:
  /// **'Settlement balance after ride'**
  String get captainRide233aea82;

  /// No description provided for @captainRide3ef541b9.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get captainRide3ef541b9;

  /// No description provided for @captainRide9af289d1.
  ///
  /// In en, this message translates to:
  /// **'Invoice could not be loaded.'**
  String get captainRide9af289d1;

  /// No description provided for @captainRide6ff5cf85.
  ///
  /// In en, this message translates to:
  /// **'Amount to collect now'**
  String get captainRide6ff5cf85;

  /// No description provided for @captainRideaab7cc3e.
  ///
  /// In en, this message translates to:
  /// **'Amount unavailable'**
  String get captainRideaab7cc3e;

  /// No description provided for @captainRide4bbd31a2.
  ///
  /// In en, this message translates to:
  /// **'The server collection amount is unavailable. Refresh the invoice or contact support before collecting payment.'**
  String get captainRide4bbd31a2;

  /// No description provided for @captainRideba6f0140.
  ///
  /// In en, this message translates to:
  /// **'Server-approved amount after wallet payment, discounts and any previous amount due.'**
  String get captainRideba6f0140;

  /// No description provided for @captainRide0b915e74.
  ///
  /// In en, this message translates to:
  /// **'Navigation is unavailable in this ride state. Refresh the status.'**
  String get captainRide0b915e74;

  /// No description provided for @captainRide5b455cbb.
  ///
  /// In en, this message translates to:
  /// **'Exact destination is unavailable. Ask the customer to confirm the address.'**
  String get captainRide5b455cbb;

  /// No description provided for @captainRide87bf7175.
  ///
  /// In en, this message translates to:
  /// **'Exact pickup is unavailable. Contact the customer to confirm it.'**
  String get captainRide87bf7175;

  /// No description provided for @captainRide765e075b.
  ///
  /// In en, this message translates to:
  /// **'Maps could not be opened. Check that a map app or browser is available.'**
  String get captainRide765e075b;

  /// No description provided for @captainRide94920016.
  ///
  /// In en, this message translates to:
  /// **'Directions could not be opened. Please retry or contact support.'**
  String get captainRide94920016;

  /// No description provided for @captainRide186db0ab.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened. Contact support from the menu.'**
  String get captainRide186db0ab;

  /// No description provided for @captainRidedc09f493.
  ///
  /// In en, this message translates to:
  /// **'The support number has not been configured by an administrator.'**
  String get captainRidedc09f493;

  /// No description provided for @captainRidef034b7ea.
  ///
  /// In en, this message translates to:
  /// **'Support could not be opened. Please retry.'**
  String get captainRidef034b7ea;

  /// No description provided for @captainRide0c1c76d8.
  ///
  /// In en, this message translates to:
  /// **'Ride assigned'**
  String get captainRide0c1c76d8;

  /// No description provided for @captainRide7a8d87be.
  ///
  /// In en, this message translates to:
  /// **'Heading to customer'**
  String get captainRide7a8d87be;

  /// No description provided for @captainRide36e931f5.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get captainRide36e931f5;

  /// No description provided for @captainRidea6fa5196.
  ///
  /// In en, this message translates to:
  /// **'Ride in progress'**
  String get captainRidea6fa5196;

  /// No description provided for @captainRidece7c7ba9.
  ///
  /// In en, this message translates to:
  /// **'Ride completed'**
  String get captainRidece7c7ba9;

  /// No description provided for @captainRidede0b18e1.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get captainRidede0b18e1;

  /// No description provided for @captainRide6a95aeca.
  ///
  /// In en, this message translates to:
  /// **'Refresh ride'**
  String get captainRide6a95aeca;

  /// No description provided for @captainRide3010a9b6.
  ///
  /// In en, this message translates to:
  /// **'Head to customer'**
  String get captainRide3010a9b6;

  /// No description provided for @captainRide058c0950.
  ///
  /// In en, this message translates to:
  /// **'Mark arrival'**
  String get captainRide058c0950;

  /// No description provided for @captainRide2cb6f5f1.
  ///
  /// In en, this message translates to:
  /// **'Start ride'**
  String get captainRide2cb6f5f1;

  /// No description provided for @captainRide11c70484.
  ///
  /// In en, this message translates to:
  /// **'Complete ride'**
  String get captainRide11c70484;

  /// No description provided for @captainRide9a86a128.
  ///
  /// In en, this message translates to:
  /// **'Ride could not be loaded.'**
  String get captainRide9a86a128;

  /// No description provided for @captainRide8bbee7af.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get captainRide8bbee7af;

  /// No description provided for @captainRide97044b5c.
  ///
  /// In en, this message translates to:
  /// **'Back to requests'**
  String get captainRide97044b5c;

  /// No description provided for @captainRidedcf45bf6.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get captainRidedcf45bf6;

  /// No description provided for @captainRidef7776e80.
  ///
  /// In en, this message translates to:
  /// **'Complete or cancel this ride before leaving. Support and chat remain available.'**
  String get captainRidef7776e80;

  /// No description provided for @captainRide1c184d79.
  ///
  /// In en, this message translates to:
  /// **'This ride is no longer active. You can return to receive new requests.'**
  String get captainRide1c184d79;

  /// No description provided for @captainRidec99f7794.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get captainRidec99f7794;

  /// No description provided for @captainRide606af07c.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get captainRide606af07c;

  /// No description provided for @captainRide287b4011.
  ///
  /// In en, this message translates to:
  /// **'Ride support'**
  String get captainRide287b4011;

  /// No description provided for @captainRideae7ae56d.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get captainRideae7ae56d;

  /// No description provided for @captainRide8b068efc.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get captainRide8b068efc;

  /// No description provided for @captainRide3c2c2a12.
  ///
  /// In en, this message translates to:
  /// **'Current stage: heading to destination'**
  String get captainRide3c2c2a12;

  /// No description provided for @captainRide28582b4d.
  ///
  /// In en, this message translates to:
  /// **'Current stage: heading to customer'**
  String get captainRide28582b4d;

  /// No description provided for @captainRidef73184e0.
  ///
  /// In en, this message translates to:
  /// **'Navigate to destination'**
  String get captainRidef73184e0;

  /// No description provided for @captainRide7b2fdccc.
  ///
  /// In en, this message translates to:
  /// **'Navigate to pickup'**
  String get captainRide7b2fdccc;

  /// No description provided for @captainRidede501d19.
  ///
  /// In en, this message translates to:
  /// **'Customer waiting time'**
  String get captainRidede501d19;

  /// No description provided for @captainRidef6c538ef.
  ///
  /// In en, this message translates to:
  /// **'Waiting charges and free minutes follow the administrator pricing rules. The final amount is confirmed in the invoice.'**
  String get captainRidef6c538ef;

  /// No description provided for @captainRide6aef022f.
  ///
  /// In en, this message translates to:
  /// **'Cancel ride'**
  String get captainRide6aef022f;

  /// No description provided for @captainRide69ca2e6b.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get captainRide69ca2e6b;

  /// No description provided for @captainRide7e5dbf26.
  ///
  /// In en, this message translates to:
  /// **'To pickup'**
  String get captainRide7e5dbf26;

  /// No description provided for @captainRideceb508b1.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get captainRideceb508b1;

  /// No description provided for @captainRidedaa86941.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get captainRidedaa86941;

  /// No description provided for @captainRide3398d2be.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get captainRide3398d2be;

  /// No description provided for @captainCancellationFee.
  ///
  /// In en, this message translates to:
  /// **'Current cancellation compensation: EGP {amount}, deducted from your balance and credited to the customer. Checked again at confirmation.'**
  String captainCancellationFee(String amount);

  /// No description provided for @captainSupportRide.
  ///
  /// In en, this message translates to:
  /// **'Hello, I need support during ride {id}.'**
  String captainSupportRide(String id);

  /// No description provided for @captainExtraRequests.
  ///
  /// In en, this message translates to:
  /// **'Extra requests: {value}'**
  String captainExtraRequests(String value);

  /// No description provided for @captainCustomerNote.
  ///
  /// In en, this message translates to:
  /// **'Customer note: {value}'**
  String captainCustomerNote(String value);

  /// No description provided for @captainWaitingPolicy.
  ///
  /// In en, this message translates to:
  /// **'First {minutes} minutes are free, then EGP {rate} per minute under administrator pricing. The final amount appears in the invoice.'**
  String captainWaitingPolicy(String minutes, String rate);

  /// No description provided for @financialCard82963d4d.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get financialCard82963d4d;

  /// No description provided for @financialCarde62437f7.
  ///
  /// In en, this message translates to:
  /// **'Final amounts cannot be confirmed until the receipt is loaded.'**
  String get financialCarde62437f7;

  /// No description provided for @financialCard5164d8be.
  ///
  /// In en, this message translates to:
  /// **'Final receipt'**
  String get financialCard5164d8be;

  /// No description provided for @financialCard02d58fca.
  ///
  /// In en, this message translates to:
  /// **'Available after completion and financial settlement'**
  String get financialCard02d58fca;

  /// No description provided for @financialCard8b296d76.
  ///
  /// In en, this message translates to:
  /// **'Collect cash from customer'**
  String get financialCard8b296d76;

  /// No description provided for @financialCarda98cf68f.
  ///
  /// In en, this message translates to:
  /// **'Cash remaining for captain'**
  String get financialCarda98cf68f;

  /// No description provided for @financialCardc5496762.
  ///
  /// In en, this message translates to:
  /// **'Ride total'**
  String get financialCardc5496762;

  /// No description provided for @financialCard4dcfdfe9.
  ///
  /// In en, this message translates to:
  /// **'Paid from wallet'**
  String get financialCard4dcfdfe9;

  /// No description provided for @financialCard3eab5144.
  ///
  /// In en, this message translates to:
  /// **'Incentive'**
  String get financialCard3eab5144;

  /// No description provided for @financialCarde8ea6cc8.
  ///
  /// In en, this message translates to:
  /// **'Waiting charges'**
  String get financialCarde8ea6cc8;

  /// No description provided for @financialCardcfea168e.
  ///
  /// In en, this message translates to:
  /// **'Previous amount due included'**
  String get financialCardcfea168e;

  /// No description provided for @financialCardb593a645.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get financialCardb593a645;

  /// No description provided for @financialCard10217aa6.
  ///
  /// In en, this message translates to:
  /// **'Change transferred to customer wallet'**
  String get financialCard10217aa6;

  /// No description provided for @financialCard3bdc9404.
  ///
  /// In en, this message translates to:
  /// **'Company commission'**
  String get financialCard3bdc9404;

  /// No description provided for @financialCardc3b788c0.
  ///
  /// In en, this message translates to:
  /// **'Your incentive share'**
  String get financialCardc3b788c0;

  /// No description provided for @financialCard986f250b.
  ///
  /// In en, this message translates to:
  /// **'Your net entitlement'**
  String get financialCard986f250b;

  /// No description provided for @financialCardf22ebe52.
  ///
  /// In en, this message translates to:
  /// **'The server collection amount is unavailable. Open the invoice or contact support before collecting payment.'**
  String get financialCardf22ebe52;

  /// No description provided for @financialCardf9ba759e.
  ///
  /// In en, this message translates to:
  /// **'Wallet payment is already deducted. Collect only the cash amount shown above.'**
  String get financialCardf9ba759e;

  /// No description provided for @financialCard16361e3f.
  ///
  /// In en, this message translates to:
  /// **'Collect only the cash amount shown above.'**
  String get financialCard16361e3f;

  /// No description provided for @financialCard6392399b.
  ///
  /// In en, this message translates to:
  /// **'Cancellation receipt'**
  String get financialCard6392399b;

  /// No description provided for @financialCardef59f590.
  ///
  /// In en, this message translates to:
  /// **'The receipt could not be loaded. Refund status and amount are unconfirmed.'**
  String get financialCardef59f590;

  /// No description provided for @financialCard95d3accb.
  ///
  /// In en, this message translates to:
  /// **'Wallet refund'**
  String get financialCard95d3accb;

  /// No description provided for @financialCardb4549ee9.
  ///
  /// In en, this message translates to:
  /// **'Cancellation compensation after grace period'**
  String get financialCardb4549ee9;

  /// No description provided for @financialCard1da6648d.
  ///
  /// In en, this message translates to:
  /// **'This receipt shows recorded transactions and does not collect or refund money.'**
  String get financialCard1da6648d;

  /// No description provided for @rideLoadingDetails.
  ///
  /// In en, this message translates to:
  /// **'Loading your ride details…'**
  String get rideLoadingDetails;

  /// No description provided for @captainHomea9f18daf.
  ///
  /// In en, this message translates to:
  /// **'Amounts are read from the server and cannot be changed on this phone.'**
  String get captainHomea9f18daf;

  /// No description provided for @captainHomed704e9bc.
  ///
  /// In en, this message translates to:
  /// **'Net earnings'**
  String get captainHomed704e9bc;

  /// No description provided for @captainHomecf1aadab.
  ///
  /// In en, this message translates to:
  /// **'Current settlement balance'**
  String get captainHomecf1aadab;

  /// No description provided for @captainHome227f09b8.
  ///
  /// In en, this message translates to:
  /// **'A positive balance is due to you; a negative balance is due to the company. Ride earnings remain separate from store accounts.'**
  String get captainHome227f09b8;

  /// No description provided for @captainHomeed440205.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get captainHomeed440205;

  /// No description provided for @captainHome96dede8e.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get captainHome96dede8e;

  /// No description provided for @captainHome2f8aa27c.
  ///
  /// In en, this message translates to:
  /// **'Earnings, commissions and settlements will appear here.'**
  String get captainHome2f8aa27c;

  /// No description provided for @captainHome3fcf112b.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get captainHome3fcf112b;

  /// No description provided for @captainHomeaf9189ea.
  ///
  /// In en, this message translates to:
  /// **'Finish the ride and go offline before opening customer mode.'**
  String get captainHomeaf9189ea;

  /// No description provided for @captainHome3dc57bb8.
  ///
  /// In en, this message translates to:
  /// **'The customer account is not linked to this identity. Contact support for review.'**
  String get captainHome3dc57bb8;

  /// No description provided for @captainHome31e75c6d.
  ///
  /// In en, this message translates to:
  /// **'Finish your ride and go offline first.'**
  String get captainHome31e75c6d;

  /// No description provided for @captainHomeffc8991e.
  ///
  /// In en, this message translates to:
  /// **'Complete or cancel the active ride before signing out.'**
  String get captainHomeffc8991e;

  /// No description provided for @captainHome59807bee.
  ///
  /// In en, this message translates to:
  /// **'Captain details'**
  String get captainHome59807bee;

  /// No description provided for @captainHome52ab0984.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get captainHome52ab0984;

  /// No description provided for @captainHome94b59a51.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get captainHome94b59a51;

  /// No description provided for @captainHome4309e001.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get captainHome4309e001;

  /// No description provided for @captainHome936290d6.
  ///
  /// In en, this message translates to:
  /// **'License plate'**
  String get captainHome936290d6;

  /// No description provided for @captainHome9643e947.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get captainHome9643e947;

  /// No description provided for @captainHome9d6ea6f4.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your dashboard'**
  String get captainHome9d6ea6f4;

  /// No description provided for @captainHome5bc457c0.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get captainHome5bc457c0;

  /// No description provided for @captainHome85c00f9b.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get captainHome85c00f9b;

  /// No description provided for @captainHome19e6729c.
  ///
  /// In en, this message translates to:
  /// **'Completed rides'**
  String get captainHome19e6729c;

  /// No description provided for @captainHome490a4c57.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get captainHome490a4c57;

  /// No description provided for @captainHomecbc96ded.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get captainHomecbc96ded;

  /// No description provided for @captainHome7a151ab7.
  ///
  /// In en, this message translates to:
  /// **'Receiving requests'**
  String get captainHome7a151ab7;

  /// No description provided for @captainHome6a746fbd.
  ///
  /// In en, this message translates to:
  /// **'Go online'**
  String get captainHome6a746fbd;

  /// No description provided for @captainHomec0ec8bb3.
  ///
  /// In en, this message translates to:
  /// **'Your debt limit has been reached. Contact support to settle the balance.'**
  String get captainHomec0ec8bb3;

  /// No description provided for @captainHome59003b32.
  ///
  /// In en, this message translates to:
  /// **'Your account needs review or approval before receiving rides.'**
  String get captainHome59003b32;

  /// No description provided for @captainHome134f277e.
  ///
  /// In en, this message translates to:
  /// **'Request details could not be loaded. Please reopen it.'**
  String get captainHome134f277e;

  /// No description provided for @captainHomecb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get captainHomecb822418;

  /// No description provided for @captainHomea042411e.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get captainHomea042411e;

  /// No description provided for @captainHome8c66b1c1.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get captainHome8c66b1c1;

  /// No description provided for @captainHomec06144c2.
  ///
  /// In en, this message translates to:
  /// **'Accept ride'**
  String get captainHomec06144c2;

  /// No description provided for @captainHome3fb68bff.
  ///
  /// In en, this message translates to:
  /// **'Extra shopping requests 🛍️'**
  String get captainHome3fb68bff;

  /// No description provided for @captainHomede8700b0.
  ///
  /// In en, this message translates to:
  /// **'New ride request'**
  String get captainHomede8700b0;

  /// No description provided for @captainHome80a51d6a.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get captainHome80a51d6a;

  /// No description provided for @captainHome113cb058.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get captainHome113cb058;

  /// No description provided for @captainHome89aef3a3.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get captainHome89aef3a3;

  /// No description provided for @captainHome9703ff57.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get captainHome9703ff57;

  /// No description provided for @captainHomeeb3b1bcc.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get captainHomeeb3b1bcc;

  /// No description provided for @captainHome3a7baec4.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get captainHome3a7baec4;

  /// No description provided for @captainHomeceb508b1.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get captainHomeceb508b1;

  /// No description provided for @captainHome2cb6f5f1.
  ///
  /// In en, this message translates to:
  /// **'Start ride'**
  String get captainHome2cb6f5f1;

  /// No description provided for @captainHome11c70484.
  ///
  /// In en, this message translates to:
  /// **'Complete ride'**
  String get captainHome11c70484;

  /// No description provided for @captainHome606af07c.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get captainHome606af07c;

  /// No description provided for @captainHome212e5d4b.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get captainHome212e5d4b;

  /// No description provided for @captainHome0c1c76d8.
  ///
  /// In en, this message translates to:
  /// **'Ride assigned'**
  String get captainHome0c1c76d8;

  /// No description provided for @captainHome7a8d87be.
  ///
  /// In en, this message translates to:
  /// **'Heading to customer'**
  String get captainHome7a8d87be;

  /// No description provided for @captainHome36e931f5.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get captainHome36e931f5;

  /// No description provided for @captainHomea6fa5196.
  ///
  /// In en, this message translates to:
  /// **'Ride in progress'**
  String get captainHomea6fa5196;

  /// No description provided for @captainHomea674a023.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get captainHomea674a023;

  /// No description provided for @captainHome54940fb7.
  ///
  /// In en, this message translates to:
  /// **'Ride invoice'**
  String get captainHome54940fb7;

  /// No description provided for @captainHome196a7a12.
  ///
  /// In en, this message translates to:
  /// **'Waiting for assignment'**
  String get captainHome196a7a12;

  /// No description provided for @captainHome156d85a1.
  ///
  /// In en, this message translates to:
  /// **'Ride accepted'**
  String get captainHome156d85a1;

  /// No description provided for @captainHome83ab21ee.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get captainHome83ab21ee;

  /// No description provided for @captainHome888bd5a4.
  ///
  /// In en, this message translates to:
  /// **'Ride started'**
  String get captainHome888bd5a4;

  /// No description provided for @captainHomef1d6d15f.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get captainHomef1d6d15f;

  /// No description provided for @captainHomed87ae61b.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get captainHomed87ae61b;

  /// No description provided for @captainHomefa8729c1.
  ///
  /// In en, this message translates to:
  /// **'Ride status updated'**
  String get captainHomefa8729c1;

  /// No description provided for @captainHome1cabb6f1.
  ///
  /// In en, this message translates to:
  /// **'Settlement is up to date'**
  String get captainHome1cabb6f1;

  /// No description provided for @captainHome9cef3446.
  ///
  /// In en, this message translates to:
  /// **'Open payment statement'**
  String get captainHome9cef3446;

  /// No description provided for @captainHome5a0374f3.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get captainHome5a0374f3;

  /// No description provided for @captainHomed528cf79.
  ///
  /// In en, this message translates to:
  /// **'online status'**
  String get captainHomed528cf79;

  /// No description provided for @captainHome8937faa1.
  ///
  /// In en, this message translates to:
  /// **'location'**
  String get captainHome8937faa1;

  /// No description provided for @captainHome234766dc.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get captainHome234766dc;

  /// No description provided for @captainHome5f7b65d5.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get captainHome5f7b65d5;

  /// No description provided for @captainHome616d302c.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get captainHome616d302c;

  /// No description provided for @captainHomeNewRating.
  ///
  /// In en, this message translates to:
  /// **'New rating received ⭐ {value}'**
  String captainHomeNewRating(String value);

  /// No description provided for @captainHomeCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer: {value}'**
  String captainHomeCustomer(String value);

  /// No description provided for @captainHomePartialEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings for {count} completed rides are unavailable. Displayed income is partial.'**
  String captainHomePartialEarnings(String count);

  /// No description provided for @captainHomeToDestination.
  ///
  /// In en, this message translates to:
  /// **'To {value}'**
  String captainHomeToDestination(String value);

  /// No description provided for @captainHomeStatus.
  ///
  /// In en, this message translates to:
  /// **'Ride status: {value}'**
  String captainHomeStatus(String value);

  /// No description provided for @captainHomeDistance.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String captainHomeDistance(String value);

  /// No description provided for @captainHomePickupDistance.
  ///
  /// In en, this message translates to:
  /// **'{value} km to pickup'**
  String captainHomePickupDistance(String value);

  /// No description provided for @captainHomeArrival.
  ///
  /// In en, this message translates to:
  /// **'{value} min to arrive'**
  String captainHomeArrival(String value);

  /// No description provided for @captainHomeCompanyDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due to company: EGP {value}'**
  String captainHomeCompanyDue(String value);

  /// No description provided for @captainHomeYourSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement credit due to you: EGP {value}'**
  String captainHomeYourSettlement(String value);

  /// No description provided for @captainHomeDebtLimit.
  ///
  /// In en, this message translates to:
  /// **'Your debt limit (EGP {value}) has been reached. Open the statement and contact support. The balance changes only after payment approval.'**
  String captainHomeDebtLimit(String value);

  /// No description provided for @captainHomeMissingRpc.
  ///
  /// In en, this message translates to:
  /// **'The captain presence service is incompatible with the database. Send support error code {code}.'**
  String captainHomeMissingRpc(String code);

  /// No description provided for @captainHomeServerSave.
  ///
  /// In en, this message translates to:
  /// **'The server could not save {field}. Error code: {code}.'**
  String captainHomeServerSave(String field, String code);

  /// No description provided for @captainMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'VETO Market — {store}{window}'**
  String captainMarketTitle(String store, String window);

  /// No description provided for @captainMarketWindow.
  ///
  /// In en, this message translates to:
  /// **' — counter {number}'**
  String captainMarketWindow(String number);

  /// No description provided for @captainMarketNet.
  ///
  /// In en, this message translates to:
  /// **'{status} • Net delivery: {amount}'**
  String captainMarketNet(String status, String amount);

  /// No description provided for @captainRideOfferDetails.
  ///
  /// In en, this message translates to:
  /// **'From: {pickup}\nTo: {destination}\nDistance: {distance} km\nDuration: {minutes} min\nBase fare: EGP {fare}\nIncentive: EGP {incentive}'**
  String captainRideOfferDetails(
    String pickup,
    String destination,
    String distance,
    String minutes,
    String fare,
    String incentive,
  );

  /// No description provided for @captainOfferExtras.
  ///
  /// In en, this message translates to:
  /// **'Customer requests: {extras}\n{estimate}'**
  String captainOfferExtras(String extras, String estimate);

  /// No description provided for @captainExtrasLimit.
  ///
  /// In en, this message translates to:
  /// **'Maximum EGP 500'**
  String get captainExtrasLimit;

  /// No description provided for @captainExtrasEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated: EGP {amount}'**
  String captainExtrasEstimate(String amount);

  /// No description provided for @profile9cb77234.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get profile9cb77234;

  /// No description provided for @profileecc98e31.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileecc98e31;

  /// No description provided for @profilecb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get profilecb822418;

  /// No description provided for @profileddfcaf9d.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileddfcaf9d;

  /// No description provided for @profile0b9ef884.
  ///
  /// In en, this message translates to:
  /// **'VETO customer'**
  String get profile0b9ef884;

  /// No description provided for @profiled256b773.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get profiled256b773;

  /// No description provided for @profileba69e2b8.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get profileba69e2b8;

  /// No description provided for @profile995846e9.
  ///
  /// In en, this message translates to:
  /// **'Completed rides'**
  String get profile995846e9;

  /// No description provided for @profile957084b6.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get profile957084b6;

  /// No description provided for @profiled51f9d8d.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get profiled51f9d8d;

  /// No description provided for @profilea7b2860b.
  ///
  /// In en, this message translates to:
  /// **'My details'**
  String get profilea7b2860b;

  /// No description provided for @profilecaa3f2bb.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profilecaa3f2bb;

  /// No description provided for @profilefdcd3da0.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get profilefdcd3da0;

  /// No description provided for @profile2f13379b.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profile2f13379b;

  /// No description provided for @profiled2ee47ec.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profiled2ee47ec;

  /// No description provided for @profile163e063e.
  ///
  /// In en, this message translates to:
  /// **'Ride preferences'**
  String get profile163e063e;

  /// No description provided for @profilead0b4e2d.
  ///
  /// In en, this message translates to:
  /// **'Choose up to four preferences, visible only to your assigned captain.'**
  String get profilead0b4e2d;

  /// No description provided for @profile57141c0a.
  ///
  /// In en, this message translates to:
  /// **'Ride preferences are not available on the server. Other profile features remain available.'**
  String get profile57141c0a;

  /// No description provided for @profile17ed4b4f.
  ///
  /// In en, this message translates to:
  /// **'My frames'**
  String get profile17ed4b4f;

  /// No description provided for @profile4a630f62.
  ///
  /// In en, this message translates to:
  /// **'Frames unlock after completed rides. You can choose any unlocked frame.'**
  String get profile4a630f62;

  /// No description provided for @profile60e389c8.
  ///
  /// In en, this message translates to:
  /// **'VETO frame'**
  String get profile60e389c8;

  /// No description provided for @profiled520070b.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get profiled520070b;

  /// No description provided for @profile774eeef9.
  ///
  /// In en, this message translates to:
  /// **'Refresh profile'**
  String get profile774eeef9;

  /// No description provided for @profileErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Your profile could not be loaded. Retry or contact support.'**
  String get profileErrorLoad;

  /// No description provided for @profileErrorFrame.
  ///
  /// In en, this message translates to:
  /// **'Your frame was not changed. Check ride eligibility and retry.'**
  String get profileErrorFrame;

  /// No description provided for @profileErrorPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your photo could not be updated. Please retry.'**
  String get profileErrorPhoto;

  /// No description provided for @profileErrorName.
  ///
  /// In en, this message translates to:
  /// **'Your name could not be updated.'**
  String get profileErrorName;

  /// No description provided for @profileErrorGender.
  ///
  /// In en, this message translates to:
  /// **'Your gender could not be updated.'**
  String get profileErrorGender;

  /// No description provided for @profileErrorLimit.
  ///
  /// In en, this message translates to:
  /// **'You can select up to four preferences.'**
  String get profileErrorLimit;

  /// No description provided for @profileErrorPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences could not be saved and will not appear to your captain until saved.'**
  String get profileErrorPreferences;

  /// No description provided for @profileInterest0.
  ///
  /// In en, this message translates to:
  /// **'Quiet ride'**
  String get profileInterest0;

  /// No description provided for @profileInterest1.
  ///
  /// In en, this message translates to:
  /// **'No music'**
  String get profileInterest1;

  /// No description provided for @profileInterest2.
  ///
  /// In en, this message translates to:
  /// **'Gentle air conditioning'**
  String get profileInterest2;

  /// No description provided for @profileInterest3.
  ///
  /// In en, this message translates to:
  /// **'No phone calls'**
  String get profileInterest3;

  /// No description provided for @profileInterest4.
  ///
  /// In en, this message translates to:
  /// **'Fastest route'**
  String get profileInterest4;

  /// No description provided for @profileInterest5.
  ///
  /// In en, this message translates to:
  /// **'Help with luggage'**
  String get profileInterest5;

  /// No description provided for @profileUnlockAfter.
  ///
  /// In en, this message translates to:
  /// **'Unlocks after {count} rides'**
  String profileUnlockAfter(String count);

  /// No description provided for @history6d43782b.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get history6d43782b;

  /// No description provided for @history0791d4ac.
  ///
  /// In en, this message translates to:
  /// **'Offers received'**
  String get history0791d4ac;

  /// No description provided for @historyf5fde9cb.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get historyf5fde9cb;

  /// No description provided for @history2de6d001.
  ///
  /// In en, this message translates to:
  /// **'Captain on the way'**
  String get history2de6d001;

  /// No description provided for @history39ac9d30.
  ///
  /// In en, this message translates to:
  /// **'Captain arrived'**
  String get history39ac9d30;

  /// No description provided for @history888bd5a4.
  ///
  /// In en, this message translates to:
  /// **'Ride started'**
  String get history888bd5a4;

  /// No description provided for @historyf1d6d15f.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get historyf1d6d15f;

  /// No description provided for @historyd87ae61b.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get historyd87ae61b;

  /// No description provided for @history62853165.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get history62853165;

  /// No description provided for @history1318e3f2.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get history1318e3f2;

  /// No description provided for @history06f3d61f.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get history06f3d61f;

  /// No description provided for @history5f7b65d5.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get history5f7b65d5;

  /// No description provided for @history285fe647.
  ///
  /// In en, this message translates to:
  /// **'🚗 Car ride'**
  String get history285fe647;

  /// No description provided for @history13b46160.
  ///
  /// In en, this message translates to:
  /// **'🛵 Motorcycle ride'**
  String get history13b46160;

  /// No description provided for @history040fc12a.
  ///
  /// In en, this message translates to:
  /// **'📦 Package'**
  String get history040fc12a;

  /// No description provided for @history91392c59.
  ///
  /// In en, this message translates to:
  /// **'🛒 VETO Market'**
  String get history91392c59;

  /// No description provided for @historyc951ef09.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get historyc951ef09;

  /// No description provided for @historyb5fae2e2.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get historyb5fae2e2;

  /// No description provided for @history22a82a2c.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get history22a82a2c;

  /// No description provided for @history452d2aff.
  ///
  /// In en, this message translates to:
  /// **'Repeat ride at standard fare'**
  String get history452d2aff;

  /// No description provided for @historyaf4b3178.
  ///
  /// In en, this message translates to:
  /// **'VETO Market orders'**
  String get historyaf4b3178;

  /// No description provided for @history578c9670.
  ///
  /// In en, this message translates to:
  /// **'VETO Market order'**
  String get history578c9670;

  /// No description provided for @historyAmountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Amount unavailable'**
  String get historyAmountUnavailable;

  /// No description provided for @historyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Orders could not be loaded. Tap to retry.'**
  String get historyLoadFailed;

  /// No description provided for @marketCheckout583fb62f.
  ///
  /// In en, this message translates to:
  /// **'This promo code is invalid for this store or has expired.'**
  String get marketCheckout583fb62f;

  /// No description provided for @marketCheckout5c851b29.
  ///
  /// In en, this message translates to:
  /// **'The area\'s delivery fee could not be loaded.'**
  String get marketCheckout5c851b29;

  /// No description provided for @marketCheckout85907225.
  ///
  /// In en, this message translates to:
  /// **'Your account details could not be loaded. Sign in again and retry.'**
  String get marketCheckout85907225;

  /// No description provided for @marketCheckout7e25319d.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery address.'**
  String get marketCheckout7e25319d;

  /// No description provided for @marketCheckout6bd931d4.
  ///
  /// In en, this message translates to:
  /// **'This address has no valid coordinates. Tap Change and select a location on the map.'**
  String get marketCheckout6bd931d4;

  /// No description provided for @marketCheckout022a299f.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again to confirm your order.'**
  String get marketCheckout022a299f;

  /// No description provided for @marketCheckoute6356df7.
  ///
  /// In en, this message translates to:
  /// **'You already have an active order. Open it from home before creating another.'**
  String get marketCheckoute6356df7;

  /// No description provided for @marketCheckout22bbfe23.
  ///
  /// In en, this message translates to:
  /// **'A product or quantity is unavailable. Return to your cart and refresh it.'**
  String get marketCheckout22bbfe23;

  /// No description provided for @marketCheckout9b041b34.
  ///
  /// In en, this message translates to:
  /// **'This store is unavailable. Choose another store or retry later.'**
  String get marketCheckout9b041b34;

  /// No description provided for @marketCheckoute957f73e.
  ///
  /// In en, this message translates to:
  /// **'Your wallet balance is insufficient. Choose cash or wallet plus cash.'**
  String get marketCheckoute957f73e;

  /// No description provided for @marketCheckoutfb4a312e.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get marketCheckoutfb4a312e;

  /// No description provided for @marketCheckout4cb08bb2.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get marketCheckout4cb08bb2;

  /// No description provided for @marketCheckout4793cceb.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get marketCheckout4793cceb;

  /// No description provided for @marketCheckoutaa63ea8f.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get marketCheckoutaa63ea8f;

  /// No description provided for @marketCheckoutbaed6e99.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get marketCheckoutbaed6e99;

  /// No description provided for @marketCheckout65397569.
  ///
  /// In en, this message translates to:
  /// **'VETO Market promo code'**
  String get marketCheckout65397569;

  /// No description provided for @marketCheckout40cf4d30.
  ///
  /// In en, this message translates to:
  /// **'Enter an optional promo code'**
  String get marketCheckout40cf4d30;

  /// No description provided for @marketCheckout268974da.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get marketCheckout268974da;

  /// No description provided for @marketCheckout0d08b83a.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get marketCheckout0d08b83a;

  /// No description provided for @marketCheckout3efc34e3.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get marketCheckout3efc34e3;

  /// No description provided for @marketCheckout7b7b0404.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get marketCheckout7b7b0404;

  /// No description provided for @marketCheckoutaae85882.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get marketCheckoutaae85882;

  /// No description provided for @marketCheckout74190f4b.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get marketCheckout74190f4b;

  /// No description provided for @marketCheckoutb03c96ad.
  ///
  /// In en, this message translates to:
  /// **'Choose delivery address'**
  String get marketCheckoutb03c96ad;

  /// No description provided for @marketCheckoutae2d6005.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get marketCheckoutae2d6005;

  /// No description provided for @marketCheckout1881ccb3.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get marketCheckout1881ccb3;

  /// No description provided for @marketCheckout91f328d3.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses'**
  String get marketCheckout91f328d3;

  /// No description provided for @marketCheckout8d30f720.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get marketCheckout8d30f720;

  /// No description provided for @marketCheckout5dc8b4dc.
  ///
  /// In en, this message translates to:
  /// **'Allow location access, then tap Use my location.'**
  String get marketCheckout5dc8b4dc;

  /// No description provided for @marketCheckout1c4408e5.
  ///
  /// In en, this message translates to:
  /// **'Enable location services and retry.'**
  String get marketCheckout1c4408e5;

  /// No description provided for @marketCheckoutb4e4ffee.
  ///
  /// In en, this message translates to:
  /// **'Your location could not be determined. Retry near a window or choose an address manually.'**
  String get marketCheckoutb4e4ffee;

  /// No description provided for @marketCheckout75c427ae.
  ///
  /// In en, this message translates to:
  /// **'Location settings'**
  String get marketCheckout75c427ae;

  /// No description provided for @marketCheckoutd49bcb58.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get marketCheckoutd49bcb58;

  /// No description provided for @marketCheckout20fa724b.
  ///
  /// In en, this message translates to:
  /// **'Location selected ✓ Add your area letter and building number to help the captain find you.'**
  String get marketCheckout20fa724b;

  /// No description provided for @marketCheckout784ff5e6.
  ///
  /// In en, this message translates to:
  /// **'Label (for example: Home)'**
  String get marketCheckout784ff5e6;

  /// No description provided for @marketCheckoutbc20c882.
  ///
  /// In en, this message translates to:
  /// **'Choose your area letter in Hadayek Al Ahram'**
  String get marketCheckoutbc20c882;

  /// No description provided for @marketCheckouteca4806f.
  ///
  /// In en, this message translates to:
  /// **'Building number'**
  String get marketCheckouteca4806f;

  /// No description provided for @marketCheckoutde69d94f.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get marketCheckoutde69d94f;

  /// No description provided for @marketCheckoutbf021870.
  ///
  /// In en, this message translates to:
  /// **'Apartment number'**
  String get marketCheckoutbf021870;

  /// No description provided for @marketCheckout9a30dc2a.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get marketCheckout9a30dc2a;

  /// No description provided for @marketCheckout8a0c87e3.
  ///
  /// In en, this message translates to:
  /// **'Choose the area letter and building number first.'**
  String get marketCheckout8a0c87e3;

  /// No description provided for @marketCheckout0a19bc85.
  ///
  /// In en, this message translates to:
  /// **'Allow location access, then tap Save.'**
  String get marketCheckout0a19bc85;

  /// No description provided for @marketCheckout70d4e1aa.
  ///
  /// In en, this message translates to:
  /// **'Enable location services, then tap Save.'**
  String get marketCheckout70d4e1aa;

  /// No description provided for @marketCheckoute908ffef.
  ///
  /// In en, this message translates to:
  /// **'Your location is not available yet. Retry near a window, then tap Save.'**
  String get marketCheckoute908ffef;

  /// No description provided for @marketCheckout9b62db02.
  ///
  /// In en, this message translates to:
  /// **'Your address could not be saved. Please retry.'**
  String get marketCheckout9b62db02;

  /// No description provided for @marketCheckoutddfcaf9d.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get marketCheckoutddfcaf9d;

  /// No description provided for @marketOrderUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order confirmation is unavailable. Check your orders or contact support before retrying.'**
  String get marketOrderUnconfirmed;

  /// No description provided for @marketPromoUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The promo code could not be verified. It has not been confirmed invalid; please retry.'**
  String get marketPromoUnconfirmed;

  /// No description provided for @marketPromoApplied.
  ///
  /// In en, this message translates to:
  /// **'Promo discount ({code})'**
  String marketPromoApplied(String code);

  /// No description provided for @marketWalletChoice.
  ///
  /// In en, this message translates to:
  /// **'Wallet (EGP {amount})'**
  String marketWalletChoice(String amount);

  /// No description provided for @marketWalletCashChoice.
  ///
  /// In en, this message translates to:
  /// **'Wallet + cash (EGP {amount} from wallet, remaining in cash)'**
  String marketWalletCashChoice(String amount);

  /// No description provided for @ratingExperience.
  ///
  /// In en, this message translates to:
  /// **'How was your ride with this passenger?'**
  String get ratingExperience;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @ratingVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Very good'**
  String get ratingVeryGood;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingImprove.
  ///
  /// In en, this message translates to:
  /// **'Needs improvement'**
  String get ratingImprove;

  /// No description provided for @ratingUncomfortable.
  ///
  /// In en, this message translates to:
  /// **'Uncomfortable experience'**
  String get ratingUncomfortable;

  /// No description provided for @ratingWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get ratingWhatHappened;

  /// No description provided for @ratingBlocked.
  ///
  /// In en, this message translates to:
  /// **'You will no longer receive requests from this passenger.'**
  String get ratingBlocked;

  /// No description provided for @ratingBlockOption.
  ///
  /// In en, this message translates to:
  /// **'Stop receiving their requests'**
  String get ratingBlockOption;

  /// No description provided for @ratingNote.
  ///
  /// In en, this message translates to:
  /// **'Additional note (optional)'**
  String get ratingNote;

  /// No description provided for @ratingSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get ratingSending;

  /// No description provided for @ratingSend.
  ///
  /// In en, this message translates to:
  /// **'Send rating'**
  String get ratingSend;

  /// No description provided for @ratingLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get ratingLater;

  /// No description provided for @ratingReason0.
  ///
  /// In en, this message translates to:
  /// **'Late to the pickup point'**
  String get ratingReason0;

  /// No description provided for @ratingReason1.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate behaviour'**
  String get ratingReason1;

  /// No description provided for @ratingReason2.
  ///
  /// In en, this message translates to:
  /// **'Changed destination'**
  String get ratingReason2;

  /// No description provided for @ratingReason3.
  ///
  /// In en, this message translates to:
  /// **'Uncomfortable communication'**
  String get ratingReason3;

  /// No description provided for @ratingReason4.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get ratingReason4;

  /// No description provided for @ratingUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Rating completion could not be confirmed. Check its status or contact support before retrying.'**
  String get ratingUnconfirmed;

  /// No description provided for @ratingStars.
  ///
  /// In en, this message translates to:
  /// **'{count} out of 5'**
  String ratingStars(String count);

  /// No description provided for @customerRatingTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your ride?'**
  String get customerRatingTitle;

  /// No description provided for @customerRatingComment.
  ///
  /// In en, this message translates to:
  /// **'Optional comment'**
  String get customerRatingComment;

  /// No description provided for @customerRatingPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your reasons and comment are for the review team. The captain sees their updated rating without your name.'**
  String get customerRatingPrivacy;

  /// No description provided for @customerRatingSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get customerRatingSending;

  /// No description provided for @customerRatingReason0.
  ///
  /// In en, this message translates to:
  /// **'Late pickup'**
  String get customerRatingReason0;

  /// No description provided for @customerRatingReason1.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate behaviour'**
  String get customerRatingReason1;

  /// No description provided for @customerRatingReason2.
  ///
  /// In en, this message translates to:
  /// **'Uncomfortable driving'**
  String get customerRatingReason2;

  /// No description provided for @customerRatingReason3.
  ///
  /// In en, this message translates to:
  /// **'Requested extra money'**
  String get customerRatingReason3;

  /// No description provided for @customerRatingReason4.
  ///
  /// In en, this message translates to:
  /// **'Different vehicle'**
  String get customerRatingReason4;

  /// No description provided for @customerRatingReason5.
  ///
  /// In en, this message translates to:
  /// **'Unexpected route'**
  String get customerRatingReason5;

  /// No description provided for @customerRatingReason6.
  ///
  /// In en, this message translates to:
  /// **'Another issue'**
  String get customerRatingReason6;

  /// No description provided for @customerRatingReason7.
  ///
  /// In en, this message translates to:
  /// **'Arrived quickly'**
  String get customerRatingReason7;

  /// No description provided for @customerRatingReason8.
  ///
  /// In en, this message translates to:
  /// **'Respectful'**
  String get customerRatingReason8;

  /// No description provided for @customerRatingReason9.
  ///
  /// In en, this message translates to:
  /// **'Comfortable driving'**
  String get customerRatingReason9;

  /// No description provided for @customerRatingReason10.
  ///
  /// In en, this message translates to:
  /// **'Clean vehicle'**
  String get customerRatingReason10;

  /// No description provided for @customerRatingReason11.
  ///
  /// In en, this message translates to:
  /// **'Excellent experience'**
  String get customerRatingReason11;

  /// No description provided for @customerRatingCaptain.
  ///
  /// In en, this message translates to:
  /// **'Rate captain {name}'**
  String customerRatingCaptain(String name);

  /// No description provided for @customerRatingStars.
  ///
  /// In en, this message translates to:
  /// **'{count} stars'**
  String customerRatingStars(String count);

  /// No description provided for @marketStoresTitle.
  ///
  /// In en, this message translates to:
  /// **'VETO Market'**
  String get marketStoresTitle;

  /// No description provided for @marketStoresEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stores are available right now'**
  String get marketStoresEmpty;

  /// No description provided for @marketStoresOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get marketStoresOpen;

  /// No description provided for @marketStoresClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get marketStoresClosed;

  /// No description provided for @marketStoresFailed.
  ///
  /// In en, this message translates to:
  /// **'Stores could not be loaded. Please retry.'**
  String get marketStoresFailed;

  /// No description provided for @marketStoresMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String marketStoresMinutes(String count);

  /// No description provided for @marketProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get marketProductsTitle;

  /// No description provided for @marketProductsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products in this category'**
  String get marketProductsEmpty;

  /// No description provided for @marketProductsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get marketProductsAdd;

  /// No description provided for @marketProductsCart.
  ///
  /// In en, this message translates to:
  /// **'Shopping cart'**
  String get marketProductsCart;

  /// No description provided for @marketProductsTotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get marketProductsTotal;

  /// No description provided for @marketProductsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue order'**
  String get marketProductsContinue;

  /// No description provided for @marketProductsFailed.
  ///
  /// In en, this message translates to:
  /// **'Products could not be loaded. Please retry.'**
  String get marketProductsFailed;

  /// No description provided for @marketProductsViewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart ({count} items) - EGP {amount}'**
  String marketProductsViewCart(String count, String amount);

  /// No description provided for @marketProductsLine.
  ///
  /// In en, this message translates to:
  /// **'EGP {price} × {count} = EGP {amount}'**
  String marketProductsLine(String price, String count, String amount);

  /// No description provided for @marketHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'My VETO Market orders'**
  String get marketHistoryTitle;

  /// No description provided for @marketHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No previous orders.'**
  String get marketHistoryEmpty;

  /// No description provided for @marketHistoryReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder available items at current prices'**
  String get marketHistoryReorder;

  /// No description provided for @marketHistoryPartial.
  ///
  /// In en, this message translates to:
  /// **'Some items are not fully available'**
  String get marketHistoryPartial;

  /// No description provided for @marketHistoryCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get marketHistoryCancel;

  /// No description provided for @marketHistoryAccept.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get marketHistoryAccept;

  /// No description provided for @marketHistoryStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This store is closed or unavailable.'**
  String get marketHistoryStoreUnavailable;

  /// No description provided for @marketHistoryProductsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No items are currently available to reorder.'**
  String get marketHistoryProductsUnavailable;

  /// No description provided for @marketHistoryReorderFailed.
  ///
  /// In en, this message translates to:
  /// **'The reorder could not be prepared. Please retry.'**
  String get marketHistoryReorderFailed;

  /// No description provided for @marketHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Your orders could not be loaded. Retry or check your sign-in.'**
  String get marketHistoryFailed;

  /// No description provided for @marketHistoryStock.
  ///
  /// In en, this message translates to:
  /// **'{name} (only {count} available)'**
  String marketHistoryStock(String name, String count);

  /// No description provided for @marketHistoryMissing.
  ///
  /// In en, this message translates to:
  /// **'These items will be omitted or reduced:\n{items}\n\nContinue with the remaining items at current prices?'**
  String marketHistoryMissing(String items);

  /// No description provided for @marketHistoryOrder.
  ///
  /// In en, this message translates to:
  /// **'Order {id} • {status}'**
  String marketHistoryOrder(String id, String status);

  /// No description provided for @marketHistoryAmount.
  ///
  /// In en, this message translates to:
  /// **'Total when ordered: EGP {amount}'**
  String marketHistoryAmount(String amount);

  /// No description provided for @marketHistoryDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String marketHistoryDate(String date);

  /// No description provided for @marketTracking2335b680.
  ///
  /// In en, this message translates to:
  /// **'Your VETO Market order'**
  String get marketTracking2335b680;

  /// No description provided for @marketTrackingd8fd5c0d.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp support'**
  String get marketTrackingd8fd5c0d;

  /// No description provided for @marketTracking7a653e5a.
  ///
  /// In en, this message translates to:
  /// **'Order could not be loaded. Refresh or check your sign-in.'**
  String get marketTracking7a653e5a;

  /// No description provided for @marketTrackingd51f9d8d.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get marketTrackingd51f9d8d;

  /// No description provided for @marketTrackingf5fde9cb.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get marketTrackingf5fde9cb;

  /// No description provided for @marketTrackingbf6cf358.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get marketTrackingbf6cf358;

  /// No description provided for @marketTracking9643e947.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get marketTracking9643e947;

  /// No description provided for @marketTracking69ca2e6b.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get marketTracking69ca2e6b;

  /// No description provided for @marketTracking4452951b.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get marketTracking4452951b;

  /// No description provided for @marketTracking3ef541b9.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get marketTracking3ef541b9;

  /// No description provided for @marketTracking3b315330.
  ///
  /// In en, this message translates to:
  /// **'Your captain'**
  String get marketTracking3b315330;

  /// No description provided for @marketTrackinga6b2ea4b.
  ///
  /// In en, this message translates to:
  /// **'VETO captain'**
  String get marketTrackinga6b2ea4b;

  /// No description provided for @marketTracking606af07c.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get marketTracking606af07c;

  /// No description provided for @marketTracking3150a947.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get marketTracking3150a947;

  /// No description provided for @marketTrackinge9ffcc97.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get marketTrackinge9ffcc97;

  /// No description provided for @marketTracking771e11be.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get marketTracking771e11be;

  /// No description provided for @marketTracking78415ee3.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get marketTracking78415ee3;

  /// No description provided for @marketTracking48c3380c.
  ///
  /// In en, this message translates to:
  /// **'Paid from wallet'**
  String get marketTracking48c3380c;

  /// No description provided for @marketTrackingdbf303cb.
  ///
  /// In en, this message translates to:
  /// **'Cash due'**
  String get marketTrackingdbf303cb;

  /// No description provided for @marketTrackingbaed6e99.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get marketTrackingbaed6e99;

  /// No description provided for @marketTracking4c5cf17e.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get marketTracking4c5cf17e;

  /// No description provided for @marketTrackingae881876.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened.'**
  String get marketTrackingae881876;

  /// No description provided for @marketTracking376012df.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the store'**
  String get marketTracking376012df;

  /// No description provided for @marketTracking333cc412.
  ///
  /// In en, this message translates to:
  /// **'The store accepted your order'**
  String get marketTracking333cc412;

  /// No description provided for @marketTracking58837987.
  ///
  /// In en, this message translates to:
  /// **'Your order is being prepared'**
  String get marketTracking58837987;

  /// No description provided for @marketTracking07554e17.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get marketTracking07554e17;

  /// No description provided for @marketTrackingb7d72a98.
  ///
  /// In en, this message translates to:
  /// **'A captain has been assigned'**
  String get marketTrackingb7d72a98;

  /// No description provided for @marketTrackingff3274e0.
  ///
  /// In en, this message translates to:
  /// **'The captain collected your order'**
  String get marketTrackingff3274e0;

  /// No description provided for @marketTracking2f7a3366.
  ///
  /// In en, this message translates to:
  /// **'The captain is on the way to you'**
  String get marketTracking2f7a3366;

  /// No description provided for @marketTracking3a648805.
  ///
  /// In en, this message translates to:
  /// **'Order delivered'**
  String get marketTracking3a648805;

  /// No description provided for @marketTracking46c5b2fc.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get marketTracking46c5b2fc;

  /// No description provided for @marketTracking7430827b.
  ///
  /// In en, this message translates to:
  /// **'We will let you know when the store accepts.'**
  String get marketTracking7430827b;

  /// No description provided for @marketTracking3a216b91.
  ///
  /// In en, this message translates to:
  /// **'The store will prepare your order.'**
  String get marketTracking3a216b91;

  /// No description provided for @marketTracking80c40038.
  ///
  /// In en, this message translates to:
  /// **'The store is checking and preparing your items.'**
  String get marketTracking80c40038;

  /// No description provided for @marketTracking0f39c3d0.
  ///
  /// In en, this message translates to:
  /// **'Waiting for captain pickup.'**
  String get marketTracking0f39c3d0;

  /// No description provided for @marketTracking7451a3a0.
  ///
  /// In en, this message translates to:
  /// **'The captain is heading to the store.'**
  String get marketTracking7451a3a0;

  /// No description provided for @marketTracking8877e2b1.
  ///
  /// In en, this message translates to:
  /// **'You can now contact the captain.'**
  String get marketTracking8877e2b1;

  /// No description provided for @marketTracking55635fa8.
  ///
  /// In en, this message translates to:
  /// **'Follow the captain on the map.'**
  String get marketTracking55635fa8;

  /// No description provided for @marketTrackingc0e8e2e6.
  ///
  /// In en, this message translates to:
  /// **'Thank you for using VETO Market.'**
  String get marketTrackingc0e8e2e6;

  /// No description provided for @marketTrackinga952b3bf.
  ///
  /// In en, this message translates to:
  /// **'Check the cancellation reason or contact support.'**
  String get marketTrackinga952b3bf;

  /// No description provided for @marketTrackingaed070ad.
  ///
  /// In en, this message translates to:
  /// **'Order chat'**
  String get marketTrackingaed070ad;

  /// No description provided for @marketTrackingcb7741fc.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get marketTrackingcb7741fc;

  /// No description provided for @marketTrackingPhone.
  ///
  /// In en, this message translates to:
  /// **'Captain phone: {phone}'**
  String marketTrackingPhone(String phone);

  /// No description provided for @marketTrackingVehicle.
  ///
  /// In en, this message translates to:
  /// **'{vehicle} • {color} • Plate {plate}'**
  String marketTrackingVehicle(String vehicle, String color, String plate);

  /// No description provided for @marketTrackingCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter {number}'**
  String marketTrackingCounter(String number);

  /// No description provided for @marketChatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message delivery could not be confirmed. Check the conversation before retrying.'**
  String get marketChatSendFailed;

  /// No description provided for @marketChatSupportFailed.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened.'**
  String get marketChatSupportFailed;

  /// No description provided for @marketChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Order chat'**
  String get marketChatTitle;

  /// No description provided for @marketChatSupport.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp support'**
  String get marketChatSupport;

  /// No description provided for @marketChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation with a clear message.'**
  String get marketChatEmpty;

  /// No description provided for @marketChatInput.
  ///
  /// In en, this message translates to:
  /// **'Write a clear message…'**
  String get marketChatInput;

  /// No description provided for @marketChatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get marketChatYou;

  /// No description provided for @marketChatCaptain.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get marketChatCaptain;

  /// No description provided for @marketChatStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get marketChatStore;

  /// No description provided for @marketChatAdmin.
  ///
  /// In en, this message translates to:
  /// **'Review team'**
  String get marketChatAdmin;

  /// No description provided for @marketChatCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get marketChatCustomer;

  /// No description provided for @marketChatParticipant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get marketChatParticipant;

  /// No description provided for @marketChatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The conversation could not be loaded. Retry or check your sign-in.'**
  String get marketChatLoadFailed;

  /// No description provided for @marketChatReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The message read status could not be updated.'**
  String get marketChatReadFailed;

  /// No description provided for @captainFareBase.
  ///
  /// In en, this message translates to:
  /// **'Ride base fare'**
  String get captainFareBase;

  /// No description provided for @captainFareUpdating.
  ///
  /// In en, this message translates to:
  /// **'Fare is being updated'**
  String get captainFareUpdating;

  /// No description provided for @captainFareFinalInvoice.
  ///
  /// In en, this message translates to:
  /// **'Server fare. Final invoice after the ride.'**
  String get captainFareFinalInvoice;

  /// No description provided for @captainFareIncentive.
  ///
  /// In en, this message translates to:
  /// **'Extra incentive: +EGP {amount}'**
  String captainFareIncentive(String amount);

  /// No description provided for @activeCaptain9b2f45b6.
  ///
  /// In en, this message translates to:
  /// **'Ride status could not be confirmed. Refresh before retrying.'**
  String get activeCaptain9b2f45b6;

  /// No description provided for @activeCaptain99f2c8a6.
  ///
  /// In en, this message translates to:
  /// **'Current ride'**
  String get activeCaptain99f2c8a6;

  /// No description provided for @activeCaptainae7ae56d.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get activeCaptainae7ae56d;

  /// No description provided for @activeCaptain8b068efc.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get activeCaptain8b068efc;

  /// No description provided for @activeCaptain45a9a436.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get activeCaptain45a9a436;

  /// No description provided for @activeCaptain3eab5144.
  ///
  /// In en, this message translates to:
  /// **'Incentive'**
  String get activeCaptain3eab5144;

  /// No description provided for @activeCaptainf69cdd96.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get activeCaptainf69cdd96;

  /// No description provided for @activeCaptain3a7baec4.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get activeCaptain3a7baec4;

  /// No description provided for @activeCaptainceb508b1.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get activeCaptainceb508b1;

  /// No description provided for @activeCaptain888bd5a4.
  ///
  /// In en, this message translates to:
  /// **'Ride started'**
  String get activeCaptain888bd5a4;

  /// No description provided for @activeCaptainc20f27ab.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get activeCaptainc20f27ab;

  /// No description provided for @activeCaptaineef4662a.
  ///
  /// In en, this message translates to:
  /// **'Head to pickup'**
  String get activeCaptaineef4662a;

  /// No description provided for @activeCaptain2cb6f5f1.
  ///
  /// In en, this message translates to:
  /// **'Start ride'**
  String get activeCaptain2cb6f5f1;

  /// No description provided for @activeCaptain11c70484.
  ///
  /// In en, this message translates to:
  /// **'Finish ride'**
  String get activeCaptain11c70484;

  /// No description provided for @feedbackClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Please write a clearer message'**
  String get feedbackClearMessage;

  /// No description provided for @feedbackSent.
  ///
  /// In en, this message translates to:
  /// **'Your message was sent to the review team'**
  String get feedbackSent;

  /// No description provided for @feedbackComplaint.
  ///
  /// In en, this message translates to:
  /// **'Complaint'**
  String get feedbackComplaint;

  /// No description provided for @feedbackSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get feedbackSuggestion;

  /// No description provided for @feedbackType.
  ///
  /// In en, this message translates to:
  /// **'Message type'**
  String get feedbackType;

  /// No description provided for @feedbackComplaintHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your complaint…'**
  String get feedbackComplaintHint;

  /// No description provided for @feedbackSuggestionHint.
  ///
  /// In en, this message translates to:
  /// **'Share your suggestion to improve the app…'**
  String get feedbackSuggestionHint;

  /// No description provided for @feedbackSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get feedbackSending;

  /// No description provided for @feedbackSend.
  ///
  /// In en, this message translates to:
  /// **'Send to review team'**
  String get feedbackSend;

  /// No description provided for @feedbackUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Message submission could not be confirmed. Check with support before retrying.'**
  String get feedbackUnconfirmed;

  /// No description provided for @feedbackAccountChanged.
  ///
  /// In en, this message translates to:
  /// **'Check your sign-in and reopen this page from your current account.'**
  String get feedbackAccountChanged;

  /// No description provided for @legal23d4bbf5.
  ///
  /// In en, this message translates to:
  /// **'The link could not be opened. You can call 01031517830.'**
  String get legal23d4bbf5;

  /// No description provided for @legalbb7d2e6a.
  ///
  /// In en, this message translates to:
  /// **'The link could not be opened. Call 01031517830.'**
  String get legalbb7d2e6a;

  /// No description provided for @legal930c8cba.
  ///
  /// In en, this message translates to:
  /// **'Terms & Privacy'**
  String get legal930c8cba;

  /// No description provided for @legalcb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get legalcb822418;

  /// No description provided for @legal5d933de9.
  ///
  /// In en, this message translates to:
  /// **'Your rights and information in one place'**
  String get legal5d933de9;

  /// No description provided for @legal18f333af.
  ///
  /// In en, this message translates to:
  /// **'Read our policies and contact options, or start an account deletion request.'**
  String get legal18f333af;

  /// No description provided for @legalbcaecd4c.
  ///
  /// In en, this message translates to:
  /// **'Last updated: 22 September 2026'**
  String get legalbcaecd4c;

  /// No description provided for @legalf0942ede.
  ///
  /// In en, this message translates to:
  /// **'I request deletion of my VETO SANYA account and associated data. Please explain verification and follow-up steps.'**
  String get legalf0942ede;

  /// No description provided for @legal04f1727b.
  ///
  /// In en, this message translates to:
  /// **'Request deletion through WhatsApp'**
  String get legal04f1727b;

  /// No description provided for @legal0efc8201.
  ///
  /// In en, this message translates to:
  /// **'Call to request deletion'**
  String get legal0efc8201;

  /// No description provided for @legal94fb90ab.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp opens a way to send the request. It does not automatically delete your account.'**
  String get legal94fb90ab;

  /// No description provided for @legal3852d180.
  ///
  /// In en, this message translates to:
  /// **'View all legal pages'**
  String get legal3852d180;

  /// No description provided for @legal01b2add5.
  ///
  /// In en, this message translates to:
  /// **'Contact: وعد محمد'**
  String get legal01b2add5;

  /// No description provided for @legalb70c8e6c.
  ///
  /// In en, this message translates to:
  /// **'Call: 01031517830'**
  String get legalb70c8e6c;

  /// No description provided for @captainMarketd7768428.
  ///
  /// In en, this message translates to:
  /// **'Pickup recorded. You can now contact the customer.'**
  String get captainMarketd7768428;

  /// No description provided for @captainMarket14dc5df9.
  ///
  /// In en, this message translates to:
  /// **'The customer was notified that you are on the way.'**
  String get captainMarket14dc5df9;

  /// No description provided for @captainMarket53dcbe87.
  ///
  /// In en, this message translates to:
  /// **'Order delivered successfully.'**
  String get captainMarket53dcbe87;

  /// No description provided for @captainMarket6eae6542.
  ///
  /// In en, this message translates to:
  /// **'Order updated.'**
  String get captainMarket6eae6542;

  /// No description provided for @captainMarket6de2e125.
  ///
  /// In en, this message translates to:
  /// **'The update could not be confirmed. Refresh the order before retrying.'**
  String get captainMarket6de2e125;

  /// No description provided for @captainMarketd8fd5c0d.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp support'**
  String get captainMarketd8fd5c0d;

  /// No description provided for @captainMarkete8449fb2.
  ///
  /// In en, this message translates to:
  /// **'Cancel job — EGP 10 fee'**
  String get captainMarkete8449fb2;

  /// No description provided for @captainMarket14d5786f.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get captainMarket14d5786f;

  /// No description provided for @captainMarketd5d536cd.
  ///
  /// In en, this message translates to:
  /// **'Go to the store first. Customer details appear after pickup.'**
  String get captainMarketd5d536cd;

  /// No description provided for @captainMarketd8f14d9b.
  ///
  /// In en, this message translates to:
  /// **'Complete the steps in order. The customer and store will receive updates.'**
  String get captainMarketd8f14d9b;

  /// No description provided for @captainMarketdaf5d487.
  ///
  /// In en, this message translates to:
  /// **'First stop: store'**
  String get captainMarketdaf5d487;

  /// No description provided for @captainMarket97432797.
  ///
  /// In en, this message translates to:
  /// **'Store details'**
  String get captainMarket97432797;

  /// No description provided for @captainMarket4c5cf17e.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get captainMarket4c5cf17e;

  /// No description provided for @captainMarketd33daf8e.
  ///
  /// In en, this message translates to:
  /// **'Call store'**
  String get captainMarketd33daf8e;

  /// No description provided for @captainMarketc76b2601.
  ///
  /// In en, this message translates to:
  /// **'Open navigation'**
  String get captainMarketc76b2601;

  /// No description provided for @captainMarket8cc3de69.
  ///
  /// In en, this message translates to:
  /// **'Second stop: customer'**
  String get captainMarket8cc3de69;

  /// No description provided for @captainMarketa042411e.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get captainMarketa042411e;

  /// No description provided for @captainMarket606af07c.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get captainMarket606af07c;

  /// No description provided for @captainMarket3150a947.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get captainMarket3150a947;

  /// No description provided for @captainMarket467e6137.
  ///
  /// In en, this message translates to:
  /// **'Check the order items'**
  String get captainMarket467e6137;

  /// No description provided for @captainMarketf8720c74.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get captainMarketf8720c74;

  /// No description provided for @captainMarketc2b2b3af.
  ///
  /// In en, this message translates to:
  /// **'I collected the order'**
  String get captainMarketc2b2b3af;

  /// No description provided for @captainMarket58ed2a34.
  ///
  /// In en, this message translates to:
  /// **'On the way to customer'**
  String get captainMarket58ed2a34;

  /// No description provided for @captainMarket25cb347d.
  ///
  /// In en, this message translates to:
  /// **'Review invoice and confirm delivery'**
  String get captainMarket25cb347d;

  /// No description provided for @captainMarket310ca3cd.
  ///
  /// In en, this message translates to:
  /// **'Order finished'**
  String get captainMarket310ca3cd;

  /// No description provided for @captainMarket973ed905.
  ///
  /// In en, this message translates to:
  /// **'Collection and delivery invoice'**
  String get captainMarket973ed905;

  /// No description provided for @captainMarket95b5d1f4.
  ///
  /// In en, this message translates to:
  /// **'Collect from customer'**
  String get captainMarket95b5d1f4;

  /// No description provided for @captainMarketdf06bb32.
  ///
  /// In en, this message translates to:
  /// **'The order is paid. Do not collect money from the customer.'**
  String get captainMarketdf06bb32;

  /// No description provided for @captainMarket75d406d4.
  ///
  /// In en, this message translates to:
  /// **'Pay store on pickup'**
  String get captainMarket75d406d4;

  /// No description provided for @captainMarket02f77b39.
  ///
  /// In en, this message translates to:
  /// **'Paid from customer wallet'**
  String get captainMarket02f77b39;

  /// No description provided for @captainMarket25d3f39d.
  ///
  /// In en, this message translates to:
  /// **'Customer discount'**
  String get captainMarket25d3f39d;

  /// No description provided for @captainMarketaa63ea8f.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get captainMarketaa63ea8f;

  /// No description provided for @captainMarket78163c16.
  ///
  /// In en, this message translates to:
  /// **'Your net delivery earnings'**
  String get captainMarket78163c16;

  /// No description provided for @captainMarket15c48cd1.
  ///
  /// In en, this message translates to:
  /// **'Do not deduct commission from the customer payment or the store entitlement. Your balance settlement is recorded automatically once after delivery.'**
  String get captainMarket15c48cd1;

  /// No description provided for @captainMarket456e5cc8.
  ///
  /// In en, this message translates to:
  /// **'The invoice is incomplete. Refresh the order before confirming delivery.'**
  String get captainMarket456e5cc8;

  /// No description provided for @captainMarket981e9393.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery and collection'**
  String get captainMarket981e9393;

  /// No description provided for @captainMarketcce08954.
  ///
  /// In en, this message translates to:
  /// **'The order is paid. Deliver it without collecting cash.'**
  String get captainMarketcce08954;

  /// No description provided for @captainMarketcb822418.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get captainMarketcb822418;

  /// No description provided for @captainMarket25deb8cf.
  ///
  /// In en, this message translates to:
  /// **'Order delivered'**
  String get captainMarket25deb8cf;

  /// No description provided for @captainMarket8b4ef63a.
  ///
  /// In en, this message translates to:
  /// **'Payment collected and order delivered'**
  String get captainMarket8b4ef63a;

  /// No description provided for @captainMarketae881876.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened.'**
  String get captainMarketae881876;

  /// No description provided for @captainMarket3b88cefe.
  ///
  /// In en, this message translates to:
  /// **'Cancel this store job?'**
  String get captainMarket3b88cefe;

  /// No description provided for @captainMarket0ea97780.
  ///
  /// In en, this message translates to:
  /// **'Your assignment will be cancelled and the order returned to the administration. An EGP 10 fee will be deducted from your account.'**
  String get captainMarket0ea97780;

  /// No description provided for @captainMarket2e57d50e.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation and fee'**
  String get captainMarket2e57d50e;

  /// No description provided for @captainMarket206a9708.
  ///
  /// In en, this message translates to:
  /// **'The job was cancelled and the EGP 10 fee deducted.'**
  String get captainMarket206a9708;

  /// No description provided for @captainMarketff44f761.
  ///
  /// In en, this message translates to:
  /// **'Cancellation could not be confirmed. Refresh the order before retrying.'**
  String get captainMarketff44f761;

  /// No description provided for @captainMarket3ba053db.
  ///
  /// In en, this message translates to:
  /// **'Head to the store'**
  String get captainMarket3ba053db;

  /// No description provided for @captainMarket0b98ede2.
  ///
  /// In en, this message translates to:
  /// **'The order is ready at the store'**
  String get captainMarket0b98ede2;

  /// No description provided for @captainMarket0bbfeacc.
  ///
  /// In en, this message translates to:
  /// **'Collected — head to customer'**
  String get captainMarket0bbfeacc;

  /// No description provided for @captainMarketaf0ea2c8.
  ///
  /// In en, this message translates to:
  /// **'You are on the way to the customer'**
  String get captainMarketaf0ea2c8;

  /// No description provided for @captainMarketf711d592.
  ///
  /// In en, this message translates to:
  /// **'Delivered successfully'**
  String get captainMarketf711d592;

  /// No description provided for @captainMarket97b675e6.
  ///
  /// In en, this message translates to:
  /// **'Store delivery job'**
  String get captainMarket97b675e6;

  /// No description provided for @captainMarket67cf4a3e.
  ///
  /// In en, this message translates to:
  /// **'Customer chat'**
  String get captainMarket67cf4a3e;

  /// No description provided for @captainMarketcb7741fc.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get captainMarketcb7741fc;

  /// No description provided for @captainMarketLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The store job could not be loaded. Refresh or check your sign-in.'**
  String get captainMarketLoadFailed;

  /// No description provided for @captainMarketCommission.
  ///
  /// In en, this message translates to:
  /// **'Company commission ({percent}%)'**
  String captainMarketCommission(String percent);

  /// No description provided for @captainMarketConfirmCash.
  ///
  /// In en, this message translates to:
  /// **'Confirm you collected EGP {amount} from the customer.'**
  String captainMarketConfirmCash(String amount);

  /// No description provided for @captainMarketJobTitle.
  ///
  /// In en, this message translates to:
  /// **'VETO Market job — {order}'**
  String captainMarketJobTitle(String order);

  /// No description provided for @bookingFinalCopy1b070dab.
  ///
  /// In en, this message translates to:
  /// **'Offer settings could not be loaded. You can continue booking.'**
  String get bookingFinalCopy1b070dab;

  /// No description provided for @bookingFinalCopy372b98ca.
  ///
  /// In en, this message translates to:
  /// **'Amount details'**
  String get bookingFinalCopy372b98ca;

  /// No description provided for @bookingFinalCopybeed4dc9.
  ///
  /// In en, this message translates to:
  /// **'Current incentive'**
  String get bookingFinalCopybeed4dc9;

  /// No description provided for @bookingFinalCopy48c3380c.
  ///
  /// In en, this message translates to:
  /// **'From wallet'**
  String get bookingFinalCopy48c3380c;

  /// No description provided for @bookingFinalCopy2e243e7f.
  ///
  /// In en, this message translates to:
  /// **'Expected cash'**
  String get bookingFinalCopy2e243e7f;

  /// No description provided for @bookingFinalCopy955b4b7b.
  ///
  /// In en, this message translates to:
  /// **'Updating the fare from the server'**
  String get bookingFinalCopy955b4b7b;

  /// No description provided for @bookingFinalCopy4a2fae95.
  ///
  /// In en, this message translates to:
  /// **'The previous request could not be restored. Choose its details and review the current fare.'**
  String get bookingFinalCopy4a2fae95;

  /// No description provided for @bookingFinalCopy37a5d6fa.
  ///
  /// In en, this message translates to:
  /// **'The fare is currently unavailable for this service. Please retry.'**
  String get bookingFinalCopy37a5d6fa;

  /// No description provided for @bookingFinalCopy2f2b8b3e.
  ///
  /// In en, this message translates to:
  /// **'Choose your ride'**
  String get bookingFinalCopy2f2b8b3e;

  /// No description provided for @bookingFinalCopy89aef3a3.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get bookingFinalCopy89aef3a3;

  /// No description provided for @bookingFinalCopy80a51d6a.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get bookingFinalCopy80a51d6a;

  /// No description provided for @bookingFinalCopy113cb058.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get bookingFinalCopy113cb058;

  /// No description provided for @bookingFinalCopyda3ac454.
  ///
  /// In en, this message translates to:
  /// **'Fare after selection'**
  String get bookingFinalCopyda3ac454;

  /// No description provided for @bookingFinalCopyde62259f.
  ///
  /// In en, this message translates to:
  /// **'The server fare changed. Review the total and confirm again.'**
  String get bookingFinalCopyde62259f;

  /// No description provided for @bookingFinalCopy9d4632b1.
  ///
  /// In en, this message translates to:
  /// **'The fare could not be refreshed. Check the current quote before retrying.'**
  String get bookingFinalCopy9d4632b1;

  /// No description provided for @bookingFinalCopyb60ed4c8.
  ///
  /// In en, this message translates to:
  /// **'Additional purchase requests must not exceed EGP 500'**
  String get bookingFinalCopyb60ed4c8;

  /// No description provided for @bookingFinalCopyb9f67739.
  ///
  /// In en, this message translates to:
  /// **'The ride request was cancelled.'**
  String get bookingFinalCopyb9f67739;

  /// No description provided for @bookingFinalCopyd6bf4f47.
  ///
  /// In en, this message translates to:
  /// **'The incentive update could not be confirmed. Refresh the ride before retrying.'**
  String get bookingFinalCopyd6bf4f47;

  /// No description provided for @bookingFinalCopy6c65081c.
  ///
  /// In en, this message translates to:
  /// **'The choice could not be confirmed. Refresh the ride and payment details before retrying.'**
  String get bookingFinalCopy6c65081c;

  /// No description provided for @bookingFinalCopydd481f00.
  ///
  /// In en, this message translates to:
  /// **'The request is cancelled, but its recorded fees need support review. No historical balance was adjusted.'**
  String get bookingFinalCopydd481f00;

  /// No description provided for @bookingFinalCopy70377ee9.
  ///
  /// In en, this message translates to:
  /// **'Updating your ride fare…'**
  String get bookingFinalCopy70377ee9;

  /// No description provided for @bookingCurrentIncentive.
  ///
  /// In en, this message translates to:
  /// **'The current incentive is already +EGP {amount}. You can choose a higher amount.'**
  String bookingCurrentIncentive(String amount);

  /// No description provided for @legacyCaptainRewardb754feca.
  ///
  /// In en, this message translates to:
  /// **'The offer link could not be opened'**
  String get legacyCaptainRewardb754feca;

  /// No description provided for @legacyCaptainRewardbbe4ec79.
  ///
  /// In en, this message translates to:
  /// **'Captain rewards'**
  String get legacyCaptainRewardbbe4ec79;

  /// No description provided for @legacyCaptainRewardea201b37.
  ///
  /// In en, this message translates to:
  /// **'Eligible completed rides during the offer period count. Payment is manual after administrative review.'**
  String get legacyCaptainRewardea201b37;

  /// No description provided for @legacyCaptainReward06d1b76f.
  ///
  /// In en, this message translates to:
  /// **'The administration pays the reward through Vodafone Cash. It is not added to the app wallet.'**
  String get legacyCaptainReward06d1b76f;

  /// No description provided for @legacyCaptainRewarda73a4757.
  ///
  /// In en, this message translates to:
  /// **'Open offer details'**
  String get legacyCaptainRewarda73a4757;

  /// No description provided for @legacyCaptainReward9e6d9f56.
  ///
  /// In en, this message translates to:
  /// **'Reward paid'**
  String get legacyCaptainReward9e6d9f56;

  /// No description provided for @legacyCaptainReward9868ebaa.
  ///
  /// In en, this message translates to:
  /// **'Due — awaiting Vodafone Cash payment'**
  String get legacyCaptainReward9868ebaa;

  /// No description provided for @legacyCaptainReward6d269d00.
  ///
  /// In en, this message translates to:
  /// **'Recipient limit reached'**
  String get legacyCaptainReward6d269d00;

  /// No description provided for @legacyCaptainRewardecaefa5c.
  ///
  /// In en, this message translates to:
  /// **'Offer ended'**
  String get legacyCaptainRewardecaefa5c;

  /// No description provided for @legacyCaptainReward7a13f6b6.
  ///
  /// In en, this message translates to:
  /// **'Starts soon'**
  String get legacyCaptainReward7a13f6b6;

  /// No description provided for @legacyCaptainReward141a2c34.
  ///
  /// In en, this message translates to:
  /// **'Offer available'**
  String get legacyCaptainReward141a2c34;

  /// No description provided for @legacyCaptainReward683deff3.
  ///
  /// In en, this message translates to:
  /// **'Manual Vodafone Cash payment after administrative review'**
  String get legacyCaptainReward683deff3;

  /// No description provided for @legacyCaptainRewardTime.
  ///
  /// In en, this message translates to:
  /// **'Time remaining: {time}'**
  String legacyCaptainRewardTime(String time);

  /// No description provided for @legacyCaptainRewardProgress.
  ///
  /// In en, this message translates to:
  /// **'{progress} of {target} eligible rides'**
  String legacyCaptainRewardProgress(String progress, String target);

  /// No description provided for @bookingAccountChanged.
  ///
  /// In en, this message translates to:
  /// **'Your account changed. Return home and start from your current account.'**
  String get bookingAccountChanged;

  /// No description provided for @captainAssignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'VETO Market job'**
  String get captainAssignmentTitle;

  /// No description provided for @captainAssignmentRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get captainAssignmentRefresh;

  /// No description provided for @captainAssignmentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No store job is assigned to you right now'**
  String get captainAssignmentEmpty;

  /// No description provided for @captainAssignmentOpen.
  ///
  /// In en, this message translates to:
  /// **'Open assigned job'**
  String get captainAssignmentOpen;

  /// No description provided for @buildingNumberFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter a building number from 1 to 590 first.'**
  String get buildingNumberFirst;

  /// No description provided for @buildingConfirmFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm you are at the building first.'**
  String get buildingConfirmFirst;

  /// No description provided for @buildingGpsEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services in your phone settings.'**
  String get buildingGpsEnable;

  /// No description provided for @buildingGpsAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow location access in your device or browser settings.'**
  String get buildingGpsAllow;

  /// No description provided for @buildingOutside.
  ///
  /// In en, this message translates to:
  /// **'Your current location is outside the approximate Hadayek Al Ahram area.'**
  String get buildingOutside;

  /// No description provided for @buildingNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a building number from 1 to 590.'**
  String get buildingNumberInvalid;

  /// No description provided for @buildingLocateFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm you are at the building, then choose Locate me.'**
  String get buildingLocateFirst;

  /// No description provided for @buildingReviewed.
  ///
  /// In en, this message translates to:
  /// **'This building has already been reviewed. Go back and select it from search.'**
  String get buildingReviewed;

  /// No description provided for @buildingDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'You reached today’s building submission limit. Try tomorrow.'**
  String get buildingDailyLimit;

  /// No description provided for @buildingSession.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again.'**
  String get buildingSession;

  /// No description provided for @buildingLocationInvalid.
  ///
  /// In en, this message translates to:
  /// **'The location or its accuracy is unsuitable. Enable GPS and try in an open area.'**
  String get buildingLocationInvalid;

  /// No description provided for @buildingCustomerRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in with an active customer account.'**
  String get buildingCustomerRequired;

  /// No description provided for @buildingUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Saving could not be confirmed. Check the submission status before retrying.'**
  String get buildingUnconfirmed;

  /// No description provided for @buildingTitle.
  ///
  /// In en, this message translates to:
  /// **'Building missing? Suggest its location'**
  String get buildingTitle;

  /// No description provided for @buildingAreaLetter.
  ///
  /// In en, this message translates to:
  /// **'Area letter'**
  String get buildingAreaLetter;

  /// No description provided for @buildingNumberHint.
  ///
  /// In en, this message translates to:
  /// **'From 1 to 590'**
  String get buildingNumberHint;

  /// No description provided for @buildingAtLocation.
  ///
  /// In en, this message translates to:
  /// **'I am at my building now'**
  String get buildingAtLocation;

  /// No description provided for @buildingLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating you…'**
  String get buildingLocating;

  /// No description provided for @buildingLocate.
  ///
  /// In en, this message translates to:
  /// **'Locate me'**
  String get buildingLocate;

  /// No description provided for @buildingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buildingCancel;

  /// No description provided for @buildingSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get buildingSaving;

  /// No description provided for @buildingSave.
  ///
  /// In en, this message translates to:
  /// **'Save and use this pickup'**
  String get buildingSave;

  /// No description provided for @buildingIntro.
  ///
  /// In en, this message translates to:
  /// **'Help the captain find you. Stand at the building and allow location access.'**
  String get buildingIntro;

  /// No description provided for @buildingReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'You can use this pickup for the current request. The administration reviews it before it appears for other customers.'**
  String get buildingReviewNotice;

  /// No description provided for @buildingAccuracyWeak.
  ///
  /// In en, this message translates to:
  /// **'Location accuracy is low ({accuracy} m). Try again in an open area.'**
  String buildingAccuracyWeak(String accuracy);

  /// No description provided for @buildingAreaValue.
  ///
  /// In en, this message translates to:
  /// **'Area {letter}'**
  String buildingAreaValue(String letter);

  /// No description provided for @buildingAccuracyCaptured.
  ///
  /// In en, this message translates to:
  /// **'Location captured — approximate accuracy {accuracy} m'**
  String buildingAccuracyCaptured(String accuracy);

  /// No description provided for @captainMapDemandError.
  ///
  /// In en, this message translates to:
  /// **'Areas could not be refreshed. Previous data may be outdated.'**
  String get captainMapDemandError;

  /// No description provided for @captainMapHighDemand.
  ///
  /// In en, this message translates to:
  /// **'High demand'**
  String get captainMapHighDemand;

  /// No description provided for @captainMapConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get captainMapConnected;

  /// No description provided for @captainMapOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get captainMapOffline;

  /// No description provided for @captainMapOpen.
  ///
  /// In en, this message translates to:
  /// **'Open area map'**
  String get captainMapOpen;

  /// No description provided for @captainMapMissingLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location is unavailable. The map shows a default centre.'**
  String get captainMapMissingLocation;

  /// No description provided for @captainMapHotspots.
  ///
  /// In en, this message translates to:
  /// **'High-demand areas'**
  String get captainMapHotspots;

  /// No description provided for @captainMapRange.
  ///
  /// In en, this message translates to:
  /// **'Range:'**
  String get captainMapRange;

  /// No description provided for @captainMapRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh areas'**
  String get captainMapRefresh;

  /// No description provided for @captainMapNearby.
  ///
  /// In en, this message translates to:
  /// **'Active areas nearby'**
  String get captainMapNearby;

  /// No description provided for @captainMapMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Highest published multiplier'**
  String get captainMapMultiplier;

  /// No description provided for @captainMapSearchRange.
  ///
  /// In en, this message translates to:
  /// **'Search range'**
  String get captainMapSearchRange;

  /// No description provided for @captainMapOpenFull.
  ///
  /// In en, this message translates to:
  /// **'View the full area map'**
  String get captainMapOpenFull;

  /// No description provided for @captainMapEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable this to see high-demand areas around your location.'**
  String get captainMapEnable;

  /// No description provided for @captainMapKilometres.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String captainMapKilometres(String distance);

  /// No description provided for @captainMapRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests: {count}'**
  String captainMapRequests(String count);

  /// No description provided for @captainMapUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time} • Server multipliers only'**
  String captainMapUpdated(String time);

  /// No description provided for @partnerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The partnership report could not be loaded. Refresh or check your sign-in.'**
  String get partnerLoadFailed;

  /// No description provided for @partnerPayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout wallet'**
  String get partnerPayoutTitle;

  /// No description provided for @partnerWalletNumber.
  ///
  /// In en, this message translates to:
  /// **'Wallet number'**
  String get partnerWalletNumber;

  /// No description provided for @partnerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get partnerCancel;

  /// No description provided for @partnerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get partnerSave;

  /// No description provided for @partnerWalletUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The payout wallet update could not be confirmed. Refresh before retrying.'**
  String get partnerWalletUnconfirmed;

  /// No description provided for @partnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Partnership account'**
  String get partnerTitle;

  /// No description provided for @partnerInactive.
  ///
  /// In en, this message translates to:
  /// **'Partnership is inactive'**
  String get partnerInactive;

  /// No description provided for @partnerTeamCode.
  ///
  /// In en, this message translates to:
  /// **'Your team code'**
  String get partnerTeamCode;

  /// No description provided for @partnerCaptains.
  ///
  /// In en, this message translates to:
  /// **'Captains'**
  String get partnerCaptains;

  /// No description provided for @partnerTrips.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get partnerTrips;

  /// No description provided for @partnerDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get partnerDue;

  /// No description provided for @partnerPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get partnerPaid;

  /// No description provided for @partnerSettledOnly.
  ///
  /// In en, this message translates to:
  /// **'After ride completion and settlement'**
  String get partnerSettledOnly;

  /// No description provided for @partnerCommissionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Commission is currently inactive'**
  String get partnerCommissionDisabled;

  /// No description provided for @partnerPayoutWallet.
  ///
  /// In en, this message translates to:
  /// **'Payout wallet'**
  String get partnerPayoutWallet;

  /// No description provided for @partnerAddWallet.
  ///
  /// In en, this message translates to:
  /// **'Add your wallet number'**
  String get partnerAddWallet;

  /// No description provided for @partnerSchedule.
  ///
  /// In en, this message translates to:
  /// **'Settlement every Saturday • 11 PM Cairo time'**
  String get partnerSchedule;

  /// No description provided for @partnerTeam.
  ///
  /// In en, this message translates to:
  /// **'Your team'**
  String get partnerTeam;

  /// No description provided for @partnerCaptain.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get partnerCaptain;

  /// No description provided for @partnerMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get partnerMotorcycle;

  /// No description provided for @partnerCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get partnerCar;

  /// No description provided for @partnerMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
  String get partnerMonthly;

  /// No description provided for @partnerStatements.
  ///
  /// In en, this message translates to:
  /// **'Settlement statements'**
  String get partnerStatements;

  /// No description provided for @partnerTransferred.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get partnerTransferred;

  /// No description provided for @partnerPendingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Awaiting transfer'**
  String get partnerPendingTransfer;

  /// No description provided for @partnerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open partnership account'**
  String get partnerOpen;

  /// No description provided for @partnerShare.
  ///
  /// In en, this message translates to:
  /// **'Your commission: {percent}% of the fare'**
  String partnerShare(String percent);

  /// No description provided for @partnerTeamRides.
  ///
  /// In en, this message translates to:
  /// **'{vehicle} • {count} rides'**
  String partnerTeamRides(String vehicle, String count);

  /// No description provided for @partnerMonthValues.
  ///
  /// In en, this message translates to:
  /// **'Due: EGP {due} • Paid: EGP {paid}'**
  String partnerMonthValues(String due, String paid);

  /// No description provided for @partnerMonthlyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The monthly report is unavailable. The rest of the partnership report shows server results.'**
  String get partnerMonthlyUnavailable;

  /// No description provided for @addressSearchPartial.
  ///
  /// In en, this message translates to:
  /// **'Part of address search is unavailable. Results are from responding sources; you can choose an address manually.'**
  String get addressSearchPartial;

  /// No description provided for @vectorMapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The map could not be displayed. You can use a saved address or return to address selection.'**
  String get vectorMapUnavailable;

  /// No description provided for @newsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Posts could not be loaded. Refresh to retry.'**
  String get newsLoadFailed;

  /// No description provided for @newsReactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Your reaction could not be confirmed. Refresh before retrying.'**
  String get newsReactionFailed;

  /// No description provided for @newsNicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your community nickname'**
  String get newsNicknameTitle;

  /// No description provided for @newsNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the name you want to display.'**
  String get newsNicknameHint;

  /// No description provided for @newsNicknameExample.
  ///
  /// In en, this message translates to:
  /// **'Example: VETO rider'**
  String get newsNicknameExample;

  /// No description provided for @newsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get newsCancel;

  /// No description provided for @newsSaveNickname.
  ///
  /// In en, this message translates to:
  /// **'Save nickname'**
  String get newsSaveNickname;

  /// No description provided for @newsNicknameSaved.
  ///
  /// In en, this message translates to:
  /// **'Nickname saved'**
  String get newsNicknameSaved;

  /// No description provided for @newsNicknameFailed.
  ///
  /// In en, this message translates to:
  /// **'The nickname update could not be confirmed. Refresh before retrying.'**
  String get newsNicknameFailed;

  /// No description provided for @newsTitle.
  ///
  /// In en, this message translates to:
  /// **'VETO News'**
  String get newsTitle;

  /// No description provided for @newsDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get newsDisplayName;

  /// No description provided for @newsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get newsRefresh;

  /// No description provided for @newsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get newsRetry;

  /// No description provided for @newsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get newsEmpty;

  /// No description provided for @newsCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community news'**
  String get newsCommunity;

  /// No description provided for @newsImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get newsImageUnavailable;

  /// No description provided for @newsComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get newsComments;

  /// No description provided for @newsCommentsFailed.
  ///
  /// In en, this message translates to:
  /// **'Comments are unavailable. Try again later.'**
  String get newsCommentsFailed;

  /// No description provided for @newsCommentFailed.
  ///
  /// In en, this message translates to:
  /// **'Comment posting could not be confirmed. Refresh before retrying.'**
  String get newsCommentFailed;

  /// No description provided for @newsMember.
  ///
  /// In en, this message translates to:
  /// **'VETO member'**
  String get newsMember;

  /// No description provided for @newsUseNickname.
  ///
  /// In en, this message translates to:
  /// **'Post using your nickname'**
  String get newsUseNickname;

  /// No description provided for @newsWriteComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get newsWriteComment;

  /// No description provided for @newsPostComment.
  ///
  /// In en, this message translates to:
  /// **'Post comment'**
  String get newsPostComment;

  /// No description provided for @newsLikes.
  ///
  /// In en, this message translates to:
  /// **'Like {count}'**
  String newsLikes(String count);

  /// No description provided for @liveMapStale.
  ///
  /// In en, this message translates to:
  /// **'Location needs an update — waiting for the captain'**
  String get liveMapStale;

  /// No description provided for @liveMapEtaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Arrival estimate is unavailable'**
  String get liveMapEtaUnavailable;

  /// No description provided for @liveMapCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating arrival time'**
  String get liveMapCalculating;

  /// No description provided for @liveMapNearTarget.
  ///
  /// In en, this message translates to:
  /// **'Near the destination point'**
  String get liveMapNearTarget;

  /// No description provided for @liveMapEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get liveMapEstimate;

  /// No description provided for @liveMapEtaDistance.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min • {distance} km'**
  String liveMapEtaDistance(int minutes, String distance);

  /// No description provided for @homeLoyaltySilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get homeLoyaltySilver;

  /// No description provided for @homeLoyaltyGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get homeLoyaltyGold;

  /// No description provided for @homeLoyaltyRank.
  ///
  /// In en, this message translates to:
  /// **'Your rank: {rank}'**
  String homeLoyaltyRank(int rank);

  /// No description provided for @homeLoyaltyProgress.
  ///
  /// In en, this message translates to:
  /// **'{remaining} rides to the next level · {completed} completed'**
  String homeLoyaltyProgress(int remaining, int completed);

  /// No description provided for @homeLoyaltyCompleted.
  ///
  /// In en, this message translates to:
  /// **'{completed} rides completed'**
  String homeLoyaltyCompleted(int completed);

  /// No description provided for @homeLoyaltyRewardCredited.
  ///
  /// In en, this message translates to:
  /// **'Your ride reward was credited to your wallet'**
  String get homeLoyaltyRewardCredited;

  /// No description provided for @homeLoyaltyRewardRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} rides to a reward of {amount} EGP'**
  String homeLoyaltyRewardRemaining(int remaining, String amount);

  /// No description provided for @homeSavedPickupVerified.
  ///
  /// In en, this message translates to:
  /// **'Saved pickup — you can change it before confirmation'**
  String get homeSavedPickupVerified;

  /// No description provided for @homeSelectedCity.
  ///
  /// In en, this message translates to:
  /// **'Selected city: {city}'**
  String homeSelectedCity(String city);

  /// No description provided for @homeCityLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location: {city}'**
  String homeCityLocation(String city);

  /// No description provided for @homeCityLookupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Pickup city could not be confirmed. Choose it manually or retry.'**
  String get homeCityLookupUnavailable;

  /// No description provided for @extraIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Your ride and purchases in one trip'**
  String get extraIntroTitle;

  /// No description provided for @extraIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Ask your captain to pick up small purchases on the way. Agree on the items and their cost before buying.'**
  String get extraIntroBody;

  /// No description provided for @extraIntroContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to purchases'**
  String get extraIntroContinue;

  /// No description provided for @extraFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick up purchases'**
  String get extraFeatureTitle;

  /// No description provided for @extraFeatureTip.
  ///
  /// In en, this message translates to:
  /// **'Add your purchase request before confirming the ride.'**
  String get extraFeatureTip;

  /// No description provided for @extraFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase request (optional)'**
  String get extraFeatureLabel;

  /// No description provided for @extraFeatureHint.
  ///
  /// In en, this message translates to:
  /// **'Example: pick up bread and milk on the way'**
  String get extraFeatureHint;

  /// No description provided for @extraFeatureHelper.
  ///
  /// In en, this message translates to:
  /// **'Agree on the purchases and their cost with the captain'**
  String get extraFeatureHelper;

  /// No description provided for @extraInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount in EGP with up to two decimal places'**
  String get extraInvalidAmount;

  /// No description provided for @captainGpsNeedsUpdate.
  ///
  /// In en, this message translates to:
  /// **'Online — update your location'**
  String get captainGpsNeedsUpdate;

  /// No description provided for @captainProfileVehicle.
  ///
  /// In en, this message translates to:
  /// **'Ride vehicle'**
  String get captainProfileVehicle;

  /// No description provided for @captainProfileIncompleteVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle information is incomplete'**
  String get captainProfileIncompleteVehicle;

  /// No description provided for @captainProfileReviews.
  ///
  /// In en, this message translates to:
  /// **'Passenger reviews'**
  String get captainProfileReviews;

  /// No description provided for @captainProfileNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No published captain reviews yet.'**
  String get captainProfileNoReviews;

  /// No description provided for @captainProfileVerifiedIdentity.
  ///
  /// In en, this message translates to:
  /// **'Verified identity'**
  String get captainProfileVerifiedIdentity;

  /// No description provided for @captainProfileVerifiedVehicle.
  ///
  /// In en, this message translates to:
  /// **'Verified vehicle'**
  String get captainProfileVerifiedVehicle;

  /// No description provided for @captainProfileCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed rides'**
  String get captainProfileCompleted;

  /// No description provided for @captainProfileAverage.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get captainProfileAverage;

  /// No description provided for @captainProfileRatingCount.
  ///
  /// In en, this message translates to:
  /// **'From {count} ratings'**
  String captainProfileRatingCount(int count);

  /// No description provided for @captainProfileDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get captainProfileDefaultName;

  /// No description provided for @cityChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get cityChoose;

  /// No description provided for @cityActualPrice.
  ///
  /// In en, this message translates to:
  /// **'The fare uses the actual ride location'**
  String get cityActualPrice;

  /// No description provided for @cityAutomaticLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get cityAutomaticLocation;

  /// No description provided for @cityPickupNext.
  ///
  /// In en, this message translates to:
  /// **'Choose your pickup point next'**
  String get cityPickupNext;

  /// No description provided for @cityComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get cityComingSoon;

  /// No description provided for @placesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh places'**
  String get placesRefresh;

  /// No description provided for @placesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for an area, building letter or number'**
  String get placesSearchHint;

  /// No description provided for @placesChooseAreaFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose an area first'**
  String get placesChooseAreaFirst;

  /// No description provided for @placesIndependent.
  ///
  /// In en, this message translates to:
  /// **'Buildings and individual places'**
  String get placesIndependent;

  /// No description provided for @placesBuildingLetter.
  ///
  /// In en, this message translates to:
  /// **'Building letter, if available'**
  String get placesBuildingLetter;

  /// No description provided for @placesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get placesAll;

  /// No description provided for @placesNoLetter.
  ///
  /// In en, this message translates to:
  /// **'No letter'**
  String get placesNoLetter;

  /// No description provided for @placesChooseBuilding.
  ///
  /// In en, this message translates to:
  /// **'Choose a building number or place'**
  String get placesChooseBuilding;

  /// No description provided for @placesNoApproved.
  ///
  /// In en, this message translates to:
  /// **'No approved addresses are available for this city yet. Choose a map location or suggest an address.'**
  String get placesNoApproved;

  /// No description provided for @placesSuggestionHelp.
  ///
  /// In en, this message translates to:
  /// **'Address missing? Use Suggest an address below the list.'**
  String get placesSuggestionHelp;

  /// No description provided for @comboCaptainTitle.
  ///
  /// In en, this message translates to:
  /// **'This ride includes purchases 🛍️'**
  String get comboCaptainTitle;

  /// No description provided for @comboCaptainDescription.
  ///
  /// In en, this message translates to:
  /// **'The customer has requested small purchases along the way.'**
  String get comboCaptainDescription;

  /// No description provided for @comboCaptainSteps.
  ///
  /// In en, this message translates to:
  /// **'What to do:'**
  String get comboCaptainSteps;

  /// No description provided for @comboCaptainBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy the agreed items and pay in cash.'**
  String get comboCaptainBuy;

  /// No description provided for @comboCaptainDeliver.
  ///
  /// In en, this message translates to:
  /// **'Deliver the items and collect their cost plus the ride fare.'**
  String get comboCaptainDeliver;

  /// No description provided for @comboCaptainAgree.
  ///
  /// In en, this message translates to:
  /// **'Confirm the items and prices with the customer in chat before buying.'**
  String get comboCaptainAgree;

  /// No description provided for @comboCaptainLimit.
  ///
  /// In en, this message translates to:
  /// **'Purchases are limited to EGP 500. Agree with the customer before buying.'**
  String get comboCaptainLimit;

  /// No description provided for @comboCaptainSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Confirmation could not be saved. Check connectivity and try again.'**
  String get comboCaptainSaveFailed;

  /// No description provided for @comboCaptainUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get comboCaptainUnderstood;

  /// No description provided for @captainProfileNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get captainProfileNew;

  /// No description provided for @cityNotActive.
  ///
  /// In en, this message translates to:
  /// **'{place} · Not active yet'**
  String cityNotActive(String place);

  /// No description provided for @placesCityTitle.
  ///
  /// In en, this message translates to:
  /// **'Areas and buildings in {place}'**
  String placesCityTitle(String place);

  /// No description provided for @placesCityAreas.
  ///
  /// In en, this message translates to:
  /// **'All areas in {place}'**
  String placesCityAreas(String place);

  /// No description provided for @placesUseArea.
  ///
  /// In en, this message translates to:
  /// **'Use the location of {place}'**
  String placesUseArea(String place);

  /// No description provided for @placesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Places could not be loaded. Tap refresh.'**
  String get placesLoadFailed;

  /// No description provided for @tripBadgeRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get tripBadgeRequested;

  /// No description provided for @tripBadgeOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers available'**
  String get tripBadgeOffers;

  /// No description provided for @tripBadgeAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get tripBadgeAccepted;

  /// No description provided for @tripBadgeArriving.
  ///
  /// In en, this message translates to:
  /// **'Captain on the way'**
  String get tripBadgeArriving;

  /// No description provided for @tripBadgeArrived.
  ///
  /// In en, this message translates to:
  /// **'Captain arrived'**
  String get tripBadgeArrived;

  /// No description provided for @tripBadgeStarted.
  ///
  /// In en, this message translates to:
  /// **'Ride started'**
  String get tripBadgeStarted;

  /// No description provided for @tripBadgeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tripBadgeCompleted;

  /// No description provided for @tripBadgeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tripBadgeCancelled;

  /// No description provided for @banDefaultAppeal.
  ///
  /// In en, this message translates to:
  /// **'Please review the temporary suspension and the circumstances of the ride.'**
  String get banDefaultAppeal;

  /// No description provided for @banAppealTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us your side'**
  String get banAppealTitle;

  /// No description provided for @banAppealHint.
  ///
  /// In en, this message translates to:
  /// **'Explain your appeal'**
  String get banAppealHint;

  /// No description provided for @banBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get banBack;

  /// No description provided for @banSendAppeal.
  ///
  /// In en, this message translates to:
  /// **'Send appeal'**
  String get banSendAppeal;

  /// No description provided for @banClearReason.
  ///
  /// In en, this message translates to:
  /// **'Please explain your appeal clearly.'**
  String get banClearReason;

  /// No description provided for @banSendFailed.
  ///
  /// In en, this message translates to:
  /// **'The appeal could not be sent. Try again.'**
  String get banSendFailed;

  /// No description provided for @banTitle.
  ///
  /// In en, this message translates to:
  /// **'Account temporarily suspended'**
  String get banTitle;

  /// No description provided for @banRemaining.
  ///
  /// In en, this message translates to:
  /// **'Time remaining'**
  String get banRemaining;

  /// No description provided for @banExpiryConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming the end of the suspension with the server'**
  String get banExpiryConfirming;

  /// No description provided for @banReturnOnline.
  ///
  /// In en, this message translates to:
  /// **'After the suspension ends, return to your dashboard and go online.'**
  String get banReturnOnline;

  /// No description provided for @banAppealSent.
  ///
  /// In en, this message translates to:
  /// **'Appeal sent for review'**
  String get banAppealSent;

  /// No description provided for @banSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get banSending;

  /// No description provided for @banAppeal.
  ///
  /// In en, this message translates to:
  /// **'Submit an appeal'**
  String get banAppeal;

  /// No description provided for @banRefreshAccount.
  ///
  /// In en, this message translates to:
  /// **'Refresh account status'**
  String get banRefreshAccount;

  /// No description provided for @debtInvoiceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The invoice could not be loaded. Check the required server update and refresh.'**
  String get debtInvoiceLoadFailed;

  /// No description provided for @debtInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Captain amount due'**
  String get debtInvoiceTitle;

  /// No description provided for @debtInvoiceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh invoice'**
  String get debtInvoiceRefresh;

  /// No description provided for @debtInvoiceReference.
  ///
  /// In en, this message translates to:
  /// **'Invoice reference'**
  String get debtInvoiceReference;

  /// No description provided for @debtInvoiceStatus.
  ///
  /// In en, this message translates to:
  /// **'Invoice status'**
  String get debtInvoiceStatus;

  /// No description provided for @debtInvoicePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get debtInvoicePaid;

  /// No description provided for @debtInvoicePending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment and confirmation'**
  String get debtInvoicePending;

  /// No description provided for @debtInvoiceHelp.
  ///
  /// In en, this message translates to:
  /// **'Contact support with the invoice reference. You can pay all or part of the amount due. The balance changes only after administration confirms receipt; opening this invoice or sending proof does not change it.'**
  String get debtInvoiceHelp;

  /// No description provided for @debtInvoiceSupportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The support number is unavailable. Contact administration to configure it.'**
  String get debtInvoiceSupportUnavailable;

  /// No description provided for @debtInvoiceAfterPayment.
  ///
  /// In en, this message translates to:
  /// **'Refresh after payment'**
  String get debtInvoiceAfterPayment;

  /// No description provided for @areaChooseLetter.
  ///
  /// In en, this message translates to:
  /// **'Choose your area letter'**
  String get areaChooseLetter;

  /// No description provided for @areaChooseBuildingLetter.
  ///
  /// In en, this message translates to:
  /// **'Tap the letter of the area containing your building'**
  String get areaChooseBuildingLetter;

  /// No description provided for @areaShowLetters.
  ///
  /// In en, this message translates to:
  /// **'Tap the card to view the 16 area letters'**
  String get areaShowLetters;

  /// No description provided for @banReason.
  ///
  /// In en, this message translates to:
  /// **'Your account was temporarily suspended: {reason}'**
  String banReason(String reason);

  /// No description provided for @debtInvoiceAmount.
  ///
  /// In en, this message translates to:
  /// **'Current amount due: {amount} EGP'**
  String debtInvoiceAmount(String amount);

  /// No description provided for @debtInvoiceCall.
  ///
  /// In en, this message translates to:
  /// **'Call support: {phone}'**
  String debtInvoiceCall(String phone);

  /// No description provided for @captainRoadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Route preview is unavailable. Refresh and try again.'**
  String get captainRoadUnavailable;

  /// No description provided for @captainRoadCoordinatesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Ride coordinates are unavailable.'**
  String get captainRoadCoordinatesUnavailable;

  /// No description provided for @captainRoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride route'**
  String get captainRoadTitle;

  /// No description provided for @captainRoadLegend.
  ///
  /// In en, this message translates to:
  /// **'Green: pickup • Red: destination • Blue: your location'**
  String get captainRoadLegend;

  /// No description provided for @captainRoadDirections.
  ///
  /// In en, this message translates to:
  /// **'Road directions'**
  String get captainRoadDirections;

  /// No description provided for @captainRoadExplanation.
  ///
  /// In en, this message translates to:
  /// **'Road geometry appears when available. Otherwise only location pins are shown. Distance comes from the ride record.'**
  String get captainRoadExplanation;

  /// No description provided for @captainRoadDistanceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get captainRoadDistanceUnknown;

  /// No description provided for @captainRoadPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview route'**
  String get captainRoadPreview;

  /// No description provided for @invalidTripIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Invalid ride identifier'**
  String get invalidTripIdentifier;

  /// No description provided for @topupBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'✦ Wallet top-up offer'**
  String get topupBannerTitle;

  /// No description provided for @topupBannerApproval.
  ///
  /// In en, this message translates to:
  /// **'Your bonus is added after the transfer is verified and approved.'**
  String get topupBannerApproval;

  /// No description provided for @topupBannerOpen.
  ///
  /// In en, this message translates to:
  /// **'View offer'**
  String get topupBannerOpen;

  /// No description provided for @savedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved places could not be loaded. Try again.'**
  String get savedLoadFailed;

  /// No description provided for @savedDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved places?'**
  String get savedDeleteTitle;

  /// No description provided for @savedBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get savedBack;

  /// No description provided for @savedDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get savedDelete;

  /// No description provided for @savedDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The saved place could not be removed.'**
  String get savedDeleteFailed;

  /// No description provided for @savedPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your saved places'**
  String get savedPlacesTitle;

  /// No description provided for @savedRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get savedRefresh;

  /// No description provided for @savedHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a saved place, or save one using the star beside a result.'**
  String get savedHelp;

  /// No description provided for @savedEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet. Open a building or place and tap its star.'**
  String get savedEmptyHelp;

  /// No description provided for @quickBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Your next ride starts here'**
  String get quickBookingTitle;

  /// No description provided for @quickBookingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you need for your ride'**
  String get quickBookingSubtitle;

  /// No description provided for @quickBookingCoverage.
  ///
  /// In en, this message translates to:
  /// **'Currently available in Hadayek Al Ahram'**
  String get quickBookingCoverage;

  /// No description provided for @quickBookingService.
  ///
  /// In en, this message translates to:
  /// **'Choose your service'**
  String get quickBookingService;

  /// No description provided for @quickCar.
  ///
  /// In en, this message translates to:
  /// **'VETO Car'**
  String get quickCar;

  /// No description provided for @quickCarCaption.
  ///
  /// In en, this message translates to:
  /// **'A comfortable ride'**
  String get quickCarCaption;

  /// No description provided for @quickMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'VETO Motorcycle'**
  String get quickMotorcycle;

  /// No description provided for @quickMotorcycleCaption.
  ///
  /// In en, this message translates to:
  /// **'A quick ride'**
  String get quickMotorcycleCaption;

  /// No description provided for @quickPackage.
  ///
  /// In en, this message translates to:
  /// **'VETO Delivery'**
  String get quickPackage;

  /// No description provided for @quickPackageCaption.
  ///
  /// In en, this message translates to:
  /// **'From pickup to destination'**
  String get quickPackageCaption;

  /// No description provided for @quickMarket.
  ///
  /// In en, this message translates to:
  /// **'VETO Market'**
  String get quickMarket;

  /// No description provided for @quickMarketCaption.
  ///
  /// In en, this message translates to:
  /// **'Household shopping'**
  String get quickMarketCaption;

  /// No description provided for @demandMapTitle.
  ///
  /// In en, this message translates to:
  /// **'High-demand areas'**
  String get demandMapTitle;

  /// No description provided for @demandDirectionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Directions could not be opened'**
  String get demandDirectionsFailed;

  /// No description provided for @demandHigh.
  ///
  /// In en, this message translates to:
  /// **'High demand'**
  String get demandHigh;

  /// No description provided for @demandNow.
  ///
  /// In en, this message translates to:
  /// **'High-demand areas now'**
  String get demandNow;

  /// No description provided for @demandExplanation.
  ///
  /// In en, this message translates to:
  /// **'Areas with high demand or an announced fare multiplier. This map does not change the fare.'**
  String get demandExplanation;

  /// No description provided for @demandLower.
  ///
  /// In en, this message translates to:
  /// **'Lower demand'**
  String get demandLower;

  /// No description provided for @demandUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get demandUpdating;

  /// No description provided for @demandEveryMinute.
  ///
  /// In en, this message translates to:
  /// **'Updates every minute'**
  String get demandEveryMinute;

  /// No description provided for @demandHigher.
  ///
  /// In en, this message translates to:
  /// **'Higher demand'**
  String get demandHigher;

  /// No description provided for @demandNone.
  ///
  /// In en, this message translates to:
  /// **'No high-demand area right now'**
  String get demandNone;

  /// No description provided for @demandStayAvailable.
  ///
  /// In en, this message translates to:
  /// **'Stay available. New offers will appear automatically.'**
  String get demandStayAvailable;

  /// No description provided for @demandDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions to area'**
  String get demandDirections;

  /// No description provided for @topupBannerAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {paid} EGP and receive {total} EGP'**
  String topupBannerAmount(String paid, String total);

  /// No description provided for @savedDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove “{place}” from saved places only.'**
  String savedDeleteDescription(String place);

  /// No description provided for @demandMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Fare ×{factor}'**
  String demandMultiplier(String factor);

  /// No description provided for @demandHighArea.
  ///
  /// In en, this message translates to:
  /// **'{place} • High demand'**
  String demandHighArea(String place);

  /// No description provided for @demandAreaMultiplier.
  ///
  /// In en, this message translates to:
  /// **'{place} • Fare ×{factor}'**
  String demandAreaMultiplier(String place, String factor);

  /// No description provided for @demandWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting requests at observation'**
  String demandWaiting(String count);

  /// No description provided for @demandSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot: {requests} requests • {captains} available captains'**
  String demandSnapshot(String requests, String captains);

  /// No description provided for @savedAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Save a place'**
  String get savedAddTitle;

  /// No description provided for @savedNameHint.
  ///
  /// In en, this message translates to:
  /// **'Place label, for example Home or Work'**
  String get savedNameHint;

  /// No description provided for @savedCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get savedCancel;

  /// No description provided for @savedSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savedSave;

  /// No description provided for @savedEnterLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter a label for this place.'**
  String get savedEnterLabel;

  /// No description provided for @changeTransferAlready.
  ///
  /// In en, this message translates to:
  /// **'Change for this ride was already transferred with another amount'**
  String get changeTransferAlready;

  /// No description provided for @changeTransferCashOnly.
  ///
  /// In en, this message translates to:
  /// **'Change transfer is available after a completed cash ride'**
  String get changeTransferCashOnly;

  /// No description provided for @changeTransferAssignedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the assigned captain can transfer change'**
  String get changeTransferAssignedOnly;

  /// No description provided for @changeTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed. Retry with the same amount'**
  String get changeTransferFailed;

  /// No description provided for @changeTransferUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The result is unconfirmed. Retry with the same amount'**
  String get changeTransferUnconfirmed;

  /// No description provided for @changeTransferAmount.
  ///
  /// In en, this message translates to:
  /// **'Change amount in EGP'**
  String get changeTransferAmount;

  /// No description provided for @changeTransferBusy.
  ///
  /// In en, this message translates to:
  /// **'Transferring'**
  String get changeTransferBusy;

  /// No description provided for @changeTransferAction.
  ///
  /// In en, this message translates to:
  /// **'Transfer change to wallet'**
  String get changeTransferAction;

  /// No description provided for @changeTransferDebt.
  ///
  /// In en, this message translates to:
  /// **'Settlement debt'**
  String get changeTransferDebt;

  /// No description provided for @changeTransferBalance.
  ///
  /// In en, this message translates to:
  /// **'Settlement balance'**
  String get changeTransferBalance;

  /// No description provided for @changeTransferInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount with up to two decimal places'**
  String get changeTransferInvalidAmount;

  /// No description provided for @changeTransferSuccess.
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP transferred to the customer wallet. {kind}: {balance} EGP'**
  String changeTransferSuccess(String amount, String kind, String balance);

  /// No description provided for @savedFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved place'**
  String get savedFallbackLabel;

  /// No description provided for @savedRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved places'**
  String get savedRemoveTooltip;

  /// No description provided for @savedChooseFailed.
  ///
  /// In en, this message translates to:
  /// **'This place could not be selected. Try again.'**
  String get savedChooseFailed;

  /// No description provided for @savedCoordinatesRequired.
  ///
  /// In en, this message translates to:
  /// **'Valid coordinates are required to save a place.'**
  String get savedCoordinatesRequired;

  /// No description provided for @savedAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This place is already saved.'**
  String get savedAlreadyExists;

  /// No description provided for @savedAdded.
  ///
  /// In en, this message translates to:
  /// **'Place saved ✓'**
  String get savedAdded;

  /// No description provided for @savedAddFailed.
  ///
  /// In en, this message translates to:
  /// **'The place could not be saved. Check connectivity and try again.'**
  String get savedAddFailed;

  /// No description provided for @quoteRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many fare requests in a short time. Wait briefly and retry; your destination is retained.'**
  String get quoteRateLimited;

  /// No description provided for @quoteCoordinatesRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup and destination coordinates to calculate the fare.'**
  String get quoteCoordinatesRequired;

  /// No description provided for @quoteUnavailableRetry.
  ///
  /// In en, this message translates to:
  /// **'Fare calculation is unavailable right now. Retry without selecting your addresses again.'**
  String get quoteUnavailableRetry;

  /// No description provided for @compareServicePrices.
  ///
  /// In en, this message translates to:
  /// **'Compare service fares'**
  String get compareServicePrices;

  /// No description provided for @viewServiceFare.
  ///
  /// In en, this message translates to:
  /// **'View fare'**
  String get viewServiceFare;

  /// No description provided for @bookingProgressRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get bookingProgressRoute;

  /// No description provided for @bookingProgressService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get bookingProgressService;

  /// No description provided for @bookingProgressConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get bookingProgressConfirm;

  /// No description provided for @bookingProgressSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get bookingProgressSearch;

  /// No description provided for @captainLocationServiceRequired.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to receive rides'**
  String get captainLocationServiceRequired;

  /// No description provided for @captainLocationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Location permission'**
  String get captainLocationPermissionTitle;

  /// No description provided for @captainLocationPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Allow location while using the app to receive rides.'**
  String get captainLocationPermissionBody;

  /// No description provided for @captainLocationLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get captainLocationLater;

  /// No description provided for @expandBooking.
  ///
  /// In en, this message translates to:
  /// **'Show booking options'**
  String get expandBooking;

  /// No description provided for @collapseBooking.
  ///
  /// In en, this message translates to:
  /// **'Collapse booking panel'**
  String get collapseBooking;

  /// No description provided for @earnedRideDiscount.
  ///
  /// In en, this message translates to:
  /// **'A discount is available for this ride'**
  String get earnedRideDiscount;

  /// No description provided for @earnedRideSaving.
  ///
  /// In en, this message translates to:
  /// **'Save {amount} with your eligible offer. The server confirms the final amount.'**
  String earnedRideSaving(String amount);

  /// No description provided for @earnedRideTerms.
  ///
  /// In en, this message translates to:
  /// **'Eligibility and expiry follow the offer terms.'**
  String get earnedRideTerms;

  /// No description provided for @earnedRideSkipped.
  ///
  /// In en, this message translates to:
  /// **'Discount not selected. Review the total before confirming.'**
  String get earnedRideSkipped;

  /// No description provided for @suggestedFareTitle.
  ///
  /// In en, this message translates to:
  /// **'We are still looking for a captain'**
  String get suggestedFareTitle;

  /// No description provided for @suggestedFareHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep your current price or choose the suggested price. You can cancel the search before a captain accepts.'**
  String get suggestedFareHelp;

  /// No description provided for @suggestedFareValue.
  ///
  /// In en, this message translates to:
  /// **'Suggested price: EGP {amount}'**
  String suggestedFareValue(String amount);

  /// No description provided for @keepCurrentFare.
  ///
  /// In en, this message translates to:
  /// **'Keep current price'**
  String get keepCurrentFare;

  /// No description provided for @useSuggestedFare.
  ///
  /// In en, this message translates to:
  /// **'Use suggested price'**
  String get useSuggestedFare;

  /// No description provided for @confirmingRequest.
  ///
  /// In en, this message translates to:
  /// **'Confirming your request…'**
  String get confirmingRequest;

  /// No description provided for @searchElapsed.
  ///
  /// In en, this message translates to:
  /// **'Search time: {time}'**
  String searchElapsed(String time);

  /// No description provided for @searchCancelFree.
  ///
  /// In en, this message translates to:
  /// **'Search cancellation is free before a captain accepts'**
  String get searchCancelFree;

  /// No description provided for @bookingTotal.
  ///
  /// In en, this message translates to:
  /// **'Ride total'**
  String get bookingTotal;

  /// No description provided for @changePayment.
  ///
  /// In en, this message translates to:
  /// **'Choose payment method'**
  String get changePayment;

  /// No description provided for @captainJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Drive with VETO'**
  String get captainJoinTitle;

  /// No description provided for @captainApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply as a captain'**
  String get captainApplyAction;

  /// No description provided for @captainBadgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your badge and referrals'**
  String get captainBadgeTitle;

  /// No description provided for @captainCodeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your code…'**
  String get captainCodeLoading;

  /// No description provided for @captainCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Code unavailable. Refresh to retry.'**
  String get captainCodeFailed;

  /// No description provided for @captainCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your code is unavailable or the campaign is paused'**
  String get captainCodeUnavailable;

  /// No description provided for @captainCodeRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh code and statistics'**
  String get captainCodeRefresh;

  /// No description provided for @referralRegistrations.
  ///
  /// In en, this message translates to:
  /// **'Signed up with your code'**
  String get referralRegistrations;

  /// No description provided for @referralQualified.
  ///
  /// In en, this message translates to:
  /// **'Completed a ride'**
  String get referralQualified;

  /// No description provided for @referralPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting qualification'**
  String get referralPending;

  /// No description provided for @referralDue.
  ///
  /// In en, this message translates to:
  /// **'Due (EGP)'**
  String get referralDue;

  /// No description provided for @referralPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid (EGP)'**
  String get referralPaid;

  /// No description provided for @badgeActive.
  ///
  /// In en, this message translates to:
  /// **'Badge activated'**
  String get badgeActive;

  /// No description provided for @badgePending.
  ///
  /// In en, this message translates to:
  /// **'Badge awaiting administration activation'**
  String get badgePending;

  /// No description provided for @badgeTeam.
  ///
  /// In en, this message translates to:
  /// **'Team: {value}'**
  String badgeTeam(String value);

  /// No description provided for @noLinkedTeam.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get noLinkedTeam;

  /// No description provided for @badgeMetricsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Statistics are unavailable. Refresh to retry; estimates are not displayed.'**
  String get badgeMetricsUnavailable;

  /// No description provided for @badgePrintAction.
  ///
  /// In en, this message translates to:
  /// **'Print your badge with your code and QR'**
  String get badgePrintAction;

  /// No description provided for @badgeDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Referral and offer details'**
  String get badgeDetailsAction;

  /// No description provided for @badgeMetricsSource.
  ///
  /// In en, this message translates to:
  /// **'Counts and rewards come from your account, not QR views.'**
  String get badgeMetricsSource;

  /// No description provided for @badgeMenuAction.
  ///
  /// In en, this message translates to:
  /// **'Invitation codes and badge earnings'**
  String get badgeMenuAction;

  /// No description provided for @currentPickup.
  ///
  /// In en, this message translates to:
  /// **'My current location'**
  String get currentPickup;

  /// No description provided for @welcomeNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name with 2 to 80 characters.'**
  String get welcomeNameInvalid;

  /// No description provided for @welcomeCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'You can enter a code, but activation is paused or unavailable for this account. No discount is granted before server confirmation. You can continue without a code.'**
  String get welcomeCodeUnavailable;

  /// No description provided for @welcomeConfirmFailed.
  ///
  /// In en, this message translates to:
  /// **'The server could not confirm this code. No gift has been granted. Check your connection and invitation before retrying.'**
  String get welcomeConfirmFailed;

  /// No description provided for @homeReferralSaving.
  ///
  /// In en, this message translates to:
  /// **'You have a {value}% discount 🎁'**
  String homeReferralSaving(String value);

  /// No description provided for @homeCreditSaving.
  ///
  /// In en, this message translates to:
  /// **'You have EGP {value} in rewards 🎁'**
  String homeCreditSaving(String value);

  /// No description provided for @homeReferralSavingHelp.
  ///
  /// In en, this message translates to:
  /// **'Use your offer on an eligible ride. Savings appear after choosing your route.'**
  String get homeReferralSavingHelp;

  /// No description provided for @homeCreditSavingHelp.
  ///
  /// In en, this message translates to:
  /// **'Use your invitation credit on an eligible ride after reviewing the quote.'**
  String get homeCreditSavingHelp;

  /// No description provided for @menuWelcome.
  ///
  /// In en, this message translates to:
  /// **'Your journey starts here'**
  String get menuWelcome;

  /// No description provided for @menuProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get menuProfile;

  /// No description provided for @menuTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips and orders'**
  String get menuTrips;

  /// No description provided for @menuWallet.
  ///
  /// In en, this message translates to:
  /// **'My wallet'**
  String get menuWallet;

  /// No description provided for @menuOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers and discounts'**
  String get menuOffers;

  /// No description provided for @menuInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get menuInvite;

  /// No description provided for @menuNews.
  ///
  /// In en, this message translates to:
  /// **'VETO news'**
  String get menuNews;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help and complaints'**
  String get menuHelp;

  /// No description provided for @menuSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get menuSafety;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuLegal.
  ///
  /// In en, this message translates to:
  /// **'Terms and privacy'**
  String get menuLegal;

  /// No description provided for @menuCaptainApply.
  ///
  /// In en, this message translates to:
  /// **'Drive with VETO SANYA'**
  String get menuCaptainApply;

  /// No description provided for @menuCaptainMode.
  ///
  /// In en, this message translates to:
  /// **'Open captain mode'**
  String get menuCaptainMode;

  /// No description provided for @menuAccountTools.
  ///
  /// In en, this message translates to:
  /// **'Account, partners and team'**
  String get menuAccountTools;

  /// No description provided for @menuLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get menuLogout;

  /// No description provided for @menuNoAddresses.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet. Save an address when choosing a location.'**
  String get menuNoAddresses;

  /// No description provided for @menuAddressSuggestions.
  ///
  /// In en, this message translates to:
  /// **'My address suggestions'**
  String get menuAddressSuggestions;

  /// No description provided for @homeActiveOrder.
  ///
  /// In en, this message translates to:
  /// **'Track your current order'**
  String get homeActiveOrder;

  /// No description provided for @homePickupHint.
  ///
  /// In en, this message translates to:
  /// **'Pickup point'**
  String get homePickupHint;

  /// No description provided for @authWelcomeV2.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VETO SANYA'**
  String get authWelcomeV2;

  /// No description provided for @authPhoneHintV2.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number to get started'**
  String get authPhoneHintV2;

  /// No description provided for @gameTitle.
  ///
  /// In en, this message translates to:
  /// **'Ring Road Driver'**
  String get gameTitle;

  /// No description provided for @gamePlay.
  ///
  /// In en, this message translates to:
  /// **'Play while you wait'**
  String get gamePlay;

  /// No description provided for @gameStart.
  ///
  /// In en, this message translates to:
  /// **'Let’s drive'**
  String get gameStart;

  /// No description provided for @gameResume.
  ///
  /// In en, this message translates to:
  /// **'Resume checkpoint'**
  String get gameResume;

  /// No description provided for @gameRestart.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get gameRestart;

  /// No description provided for @gamePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get gamePause;

  /// No description provided for @gameContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue driving'**
  String get gameContinue;

  /// No description provided for @gameGarage.
  ///
  /// In en, this message translates to:
  /// **'Choose your car'**
  String get gameGarage;

  /// No description provided for @gameName.
  ///
  /// In en, this message translates to:
  /// **'Car nickname (optional)'**
  String get gameName;

  /// No description provided for @gameNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Karim’s car'**
  String get gameNicknameHint;

  /// No description provided for @gameSedan.
  ///
  /// In en, this message translates to:
  /// **'Small sedan'**
  String get gameSedan;

  /// No description provided for @gameTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get gameTaxi;

  /// No description provided for @gameSuv.
  ///
  /// In en, this message translates to:
  /// **'SUV'**
  String get gameSuv;

  /// No description provided for @gameSport.
  ///
  /// In en, this message translates to:
  /// **'Sporty compact'**
  String get gameSport;

  /// No description provided for @gameGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get gameGold;

  /// No description provided for @gameWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get gameWhite;

  /// No description provided for @gameBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get gameBlack;

  /// No description provided for @gameBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get gameBlue;

  /// No description provided for @gameRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get gameRed;

  /// No description provided for @gameGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get gameGreen;

  /// No description provided for @gameLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get gameLeft;

  /// No description provided for @gameRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get gameRight;

  /// No description provided for @gameSound.
  ///
  /// In en, this message translates to:
  /// **'Game sound'**
  String get gameSound;

  /// No description provided for @gameMuted.
  ///
  /// In en, this message translates to:
  /// **'Sound off'**
  String get gameMuted;

  /// No description provided for @gameDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get gameDistance;

  /// No description provided for @gameBest.
  ///
  /// In en, this message translates to:
  /// **'Best score'**
  String get gameBest;

  /// No description provided for @gameScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get gameScore;

  /// No description provided for @gameExit.
  ///
  /// In en, this message translates to:
  /// **'Return to your request'**
  String get gameExit;

  /// No description provided for @gamePersonalExit.
  ///
  /// In en, this message translates to:
  /// **'Close game'**
  String get gamePersonalExit;

  /// No description provided for @gameSaved.
  ///
  /// In en, this message translates to:
  /// **'Progress is saved on this device for your account'**
  String get gameSaved;

  /// No description provided for @gameSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save progress on this device right now'**
  String get gameSaveFailed;

  /// No description provided for @gameWaiting.
  ///
  /// In en, this message translates to:
  /// **'Captain matching is still running. Your trip comes first.'**
  String get gameWaiting;

  /// No description provided for @gameCrash1.
  ///
  /// In en, this message translates to:
  /// **'Easy, driver! We might need a tow 😂'**
  String get gameCrash1;

  /// No description provided for @gameCrash2.
  ///
  /// In en, this message translates to:
  /// **'Steady! This car is still new!'**
  String get gameCrash2;

  /// No description provided for @gameCrash3.
  ///
  /// In en, this message translates to:
  /// **'Stay in your lane, driver!'**
  String get gameCrash3;

  /// No description provided for @gameDodge.
  ///
  /// In en, this message translates to:
  /// **'Nice driving!'**
  String get gameDodge;

  /// No description provided for @gamePaused.
  ///
  /// In en, this message translates to:
  /// **'Take a break. Continue when you are ready.'**
  String get gamePaused;

  /// No description provided for @gameEntertainment.
  ///
  /// In en, this message translates to:
  /// **'For fun only. Points are not money or wallet credit.'**
  String get gameEntertainment;

  /// No description provided for @gameNotReady.
  ///
  /// In en, this message translates to:
  /// **'Getting your car ready…'**
  String get gameNotReady;

  /// No description provided for @bannerPosition.
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get bannerPosition;

  /// No description provided for @bannerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous offer'**
  String get bannerPrevious;

  /// No description provided for @bannerNext.
  ///
  /// In en, this message translates to:
  /// **'Next offer'**
  String get bannerNext;

  /// No description provided for @authResendV2.
  ///
  /// In en, this message translates to:
  /// **'Check verification request again'**
  String get authResendV2;

  /// No description provided for @authRequestPendingV2.
  ///
  /// In en, this message translates to:
  /// **'Your request is pending. The verification team will provide the code.'**
  String get authRequestPendingV2;

  /// No description provided for @authPhoneLabelV2.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get authPhoneLabelV2;

  /// No description provided for @draftUnavailableV2.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the draft on this device right now.'**
  String get draftUnavailableV2;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
