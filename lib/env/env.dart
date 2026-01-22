class Env {
  static const bool enableConsole = true;
  static const bool enableSnackbar = false;
}

// baseUrl
const String baseUrl = "https://localhost:7238";
//  const String baseUrl = "https://abdmstg.coretegra.com";

// send otp api
const String senOtpEmailEndpoint =
    '/api/registration/enduser/sendotp/gmail/signup';
const String senOtpPhoneEndpoint =
    '/api/registration/enduser/sendotp/phone/signup';

// create password api
const String createPswdEmailEndpoint =
    '/api/registration/enduser/verifyandcreatepassword/gmail/signup';
const String createPswdPhoneEndpoint =
    '/api/registration/enduser/verifyandcreatepassword/phone/signup';

// forget password otp sending api
const String forgotEmailOtpEndpoint =
    '/api/registration/sendotp/gmail/forgotpassword';
const String forgotPhoneOtpEndpoint =
    '/api/registration/sendotp/phone/forgotpassword';

// forget password updating api
const String forgotPasswordUpdateUsingEmailEndpoint =
    '/api/registration/verifyandcreatepassword/gmail/forgotpassword';
const String forgotPasswordUpdateUsingPhoneEndpoint =
    '/api/registration/verifyandcreatepassword/phone/forgotpassword';

//update email phone
const String updateEmailOtpEndpoint = '/api/registration/sendotp/gmail/update';
const String updatePhoneOtpEndpoint = '/api/registration/sendotp/phone/update';
const String updatePasswordUpdateUsingEmailEndpoint =
    '/api/registration/verify/gmail/update';
const String updatePasswordUpdateUsingPhoneEndpoint =
    '/api/registration/verify/phone/update';

// sign in api
const String signInEmailEndpoint = '/api/registration/gmail/signin';
const String signInPhoneEndpoint = '/api/registration/phone/signin';

// google auth api
const String googleApi = '/api/registration/enduser/auth/google';

//Save User Details api

const String userprofileInfo = '/api/fetchinfo/userprofile';
const String useractivedata = '/api/fetchinfo/activeBasicData';

const String userNameApi = '/api/upsert/name';
const String userGenderApi = '/api/upsert/gender';
const String userDobApi = '/api/upsert/dateofbirth';
const String userOccupationApi = '/api/upsert/occupation';
const String userHeightApi = '/api/upsert/height';
const String userWeightApi = '/api/upsert/weight';
const String userAddressApi = '/api/upsert/address';

const String appactivityGoal = '/api/upsert/activitylevel';
const String apphealthGoal = '/api/upsert/healthgoal';
const String appOccupation = '/api/upsert/usingAppData';

const String savestepGoal = "/api/upsert/stepgoal";
const String stepRecord = "/api/upsert/addsteprecord";
const String waterGoalfinal = "/api/upsert/watergoal";
const String waterRecord = "/api/upsert/addwaterintakerecord";
const String sleepGoal = "/api/upsert/sleepgoal";
const String sleepRecord = "/api/upsert/addsleeprecord";

const String bloodpressure = '/api/upsert/addbloodpressurerecord';
const String logmood = '/api/upsert/logmood';
const String womenhealth = '/api/upsert/womenhealthquestionnaire';
const String editperioddata = '/api/upsert/editperioddata';

const String addreminderApi = '/api/upsert/addreminder';
const String editreminderApi = '/api/upsert/editreminder';
const String getreminderApi = '/api/fetchinfo/reminders';

const String genhealthtipsAPI = '/api/tips/getbyTags';
const String genralmusicAPI = '/api/mentalwellness/getbyTags';

// const String waterrecords = '/api/fetchinfo/waterintakeData';

const String ellychat = '/api/decisiontree/getContent';
const String uploadprofilepic = '/api/media/intent';
const String getDietByTags = '/api/dietplans/getbyTags';

const String fetchStepsHistory = '/api/fetchinfo/stepsData';
const String fetchSleepHistory = '/api/fetchinfo/sleepData';
const String waterrecords = '/api/fetchinfo/waterintakeData';
const String fetchBloodPressureHistory = '/api/fetchinfo/bloodpressureData';
const String fetchWomenhealthHistory = '/api/fetchinfo/womenhealthdata';
const String lastPeriodData = '/api/fetchinfo/lastperioddata';
const String addperioddata = '/api/upsert/addperioddata';
const String addsymptomdata = '/api/upsert/addsymptomdata';
const String moodTrackData = '/api/fetchinfo/moodTrackData';
const String periodsymptomps = '/api/upsert/addsymptomdata';

const String fcmTokenApi = '/api/registration/userdevicetoken';

List<String> backgroundImageUrls = [
  // Random placeholder images
  "https://picsum.photos/1080/1920",                         // random 1080x1920 image
  "https://picsum.photos/800/1400",                          // random 800x1400
  "https://picsum.photos/1200/2000",                         // random vertical photo

  "https://gdevelop.io/_next/static/media/audio-placeholder.22bf16ce.jpg",
  "https://i.pinimg.com/1200x/e9/93/ec/e993ec4d2956fbae938515d91d0b0434.jpg",


  // Landscape and nature photos
  "https://images.pexels.com/photos/34950/pexels-photo.jpg",  // nature scenery
  "https://images.pexels.com/photos/417173/pexels-photo-417173.jpeg",
  "https://images.pexels.com/photos/36717/amazing-animal-beautiful-beautifull.jpg",

  // Aesthetic & abstract
  "https://images.pexels.com/photos/355465/pexels-photo-355465.jpeg",
  "https://images.pexels.com/photos/110854/pexels-photo-110854.jpeg",

  // Clean gradients/textured backgrounds
  "https://images.pexels.com/photos/323705/pexels-photo-323705.jpeg",
  "https://images.pexels.com/photos/207962/pexels-photo-207962.jpeg",

  // Urban & skyline
  "https://images.pexels.com/photos/374870/pexels-photo-374870.jpeg",
  "https://images.pexels.com/photos/1237119/pexels-photo-1237119.jpeg",
  "https://i.sstatic.net/bkC9s.jpg"

  // Night / mood
  "https://images.pexels.com/photos/1274260/pexels-photo-1274260.jpeg",
  "https://images.pexels.com/photos/736230/pexels-photo-736230.jpeg"
];

const String dietPlaceholder =
    "https://community.softr.io/uploads/db9110/original/2X/7/74e6e7e382d0ff5d7773ca9a87e6f6f8817a68a6.jpeg";

const String logexception = '/api/exceptionslog/logexception';

const String changeDeviceApi = '/api/registration/changedevicetoken';
const String logout = '/api/registration/logout';
const String deleteDeviceApi = '/api/registration/logoutviaId';

