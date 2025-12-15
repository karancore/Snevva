class Env {
  static const bool enableConsole = true;
  static const bool enableSnackbar = true;
}
// baseUrl
// const String baseUrl = "https://localhost:7238";
 const String baseUrl = "https://abdmstg.coretegra.com";


// send otp api
const String senOtpEmailEndpoint = '/api/registration/enduser/sendotp/gmail/signup';
const String senOtpPhoneEndpoint = '/api/registration/enduser/sendotp/phone/signup';


// create password api
const String createPswdEmailEndpoint = '/api/registration/enduser/verifyandcreatepassword/gmail/signup';
const String createPswdPhoneEndpoint = '/api/registration/enduser/verifyandcreatepassword/phone/signup';


// forget password otp sending api
const String forgotEmailOtpEndpoint = '/api/registration/sendotp/gmail/forgotpassword';
const String forgotPhoneOtpEndpoint = '/api/registration/sendotp/phone/forgotpassword';


// forget password updating api
const String forgotPasswordUpdateUsingEmailEndpoint = '/api/registration/verifyandcreatepassword/gmail/forgotpassword';
const String forgotPasswordUpdateUsingPhoneEndpoint = '/api/registration/verifyandcreatepassword/phone/forgotpassword';

//update email phone
const String updateEmailOtpEndpoint = '/api/registration/sendotp/gmail/update';
const String updatePhoneOtpEndpoint = '/api/registration/sendotp/phone/update';
const String updatePasswordUpdateUsingEmailEndpoint = '/api/registration/verify/gmail/update';
const String updatePasswordUpdateUsingPhoneEndpoint = '/api/registration/verify/phone/update';


// sign in api
const String signInEmailEndpoint = '/api/registration/gmail/signin';
const String signInPhoneEndpoint = '/api/registration/phone/signin';


// google auth api
const String googleApi = '/api/registration/enduser/auth/goosgle2';

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

const String addreminderApi = '/api/upsert/addreminder';
const String editreminderApi = '/api/upsert/editreminder';
const String getreminderApi = '/api/fetchinfo/reminders';

const String genhealthtipsAPI = '/api/tips/getbyTags';
const String genralmusicAPI = '/api/mentalwellness/getbyTags';

const String waterrecords = '/api/fetchinfo/waterintakeData';

const String ellychat = '/api/decisiontree/getContent';
const String uploadprofilepic = '/api/media/intent';
