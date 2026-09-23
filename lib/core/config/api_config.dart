/// Single production API base for mobile v1.
/// See document/11-mobile-api-reference.md — do not hardcode this elsewhere.
const String kApiBaseUrl = 'https://eclinicpro.com/api/mobile/v1';

/// Secure-storage key for the 64-char session token from verify_otp.
const String kSessionTokenKey = 'ecp_session_token';

/// SharedPreferences key: has the user finished onboarding?
const String kOnboardingDoneKey = 'ecp_onboarding_done';

/// TEST ONLY — set to `false` before real WhatsApp OTP / store release.
/// When true: Login accepts phone number only (no send_otp / no WhatsApp).
const bool kSkipWhatsAppOtp = true;

const String kTestPhoneKey = 'ecp_test_phone';
const String kTestSessionKey = 'ecp_test_session';
