/// Single production API base for mobile v1.
/// See document/11-mobile-api-reference.md — do not hardcode this elsewhere.
const String kApiBaseUrl = 'https://eclinicpro.com/api/mobile/v1';

/// Secure-storage key for the 64-char session token from verify_otp.
const String kSessionTokenKey = 'ecp_session_token';

/// Secure-storage key for the guest store cart (64 hex, from
/// `store_cart.php`). Sent as `X-Cart-Token` until the cart is merged into
/// the patient's own cart after sign-in — see doc 12 "Guest cart".
const String kCartTokenKey = 'ecp_cart_token';

/// SharedPreferences key: has the user finished onboarding?
const String kOnboardingDoneKey = 'ecp_onboarding_done';

/// TEST ONLY — set to `false` before real WhatsApp OTP / store release.
/// When true: Login accepts phone number only (no send_otp / no WhatsApp).
const bool kSkipWhatsAppOtp = false;

/// Labs (catalog + booking) is not offered yet. While false, the Labs tab and
/// the Home "Book lab test" tile are hidden. Flip to true to bring both back;
/// the screen itself (features/labs) is kept.
const bool kLabsEnabled = false;

/// SharedPreferences key: 'system' | 'light' | 'dark'.
const String kThemeModeKey = 'ecp_theme_mode';

const String kTestPhoneKey = 'ecp_test_phone';
const String kTestSessionKey = 'ecp_test_session';
