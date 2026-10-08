import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/appointments/presentation/book_appointment_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/doctors/domain/doctor.dart';
import '../../features/doctors/presentation/doctor_detail_screen.dart';
import '../../features/doctors/presentation/doctors_search_screen.dart';
import '../../features/doctors/presentation/saved_doctors_screen.dart';
import '../../features/family/presentation/family_member_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/labs/presentation/labs_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/queue/presentation/queue_screen.dart';
import '../../features/records/presentation/record_detail_screen.dart';
import '../../features/records/presentation/record_form_screen.dart';
import '../../features/records/presentation/records_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/shop/domain/store_models.dart';
import '../../features/shop/presentation/address_screens.dart';
import '../../features/shop/presentation/cart_screen.dart';
import '../../features/shop/presentation/checkout_screen.dart';
import '../../features/shop/presentation/invoice_screen.dart';
import '../../features/shop/presentation/listing_screen.dart';
import '../../features/shop/presentation/order_detail_screen.dart';
import '../../features/shop/presentation/orders_screen.dart';
import '../../features/shop/presentation/points_screen.dart';
import '../../features/shop/presentation/product_screen.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/shop/presentation/wishlist_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map) {
            return const LoginScreen();
          }
          return OtpScreen(
            phone: (extra['phone'] ?? '').toString(),
            exists: extra['exists'] == true,
            nameHint: extra['nameHint']?.toString(),
            devCode: extra['devCode']?.toString(),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab order must match ShellTab.visible in main_shell.dart.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctors',
                builder: (context, state) => const DoctorsSearchScreen(),
              ),
            ],
          ),
          // Hidden until labs launch; see kLabsEnabled.
          if (kLabsEnabled)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/labs',
                  builder: (context, state) => const LabsScreen(),
                ),
              ],
            ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                builder: (context, state) => const ShopScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/records',
                builder: (context, state) => const RecordsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      // Appointments is no longer a tab, but remains a full-screen route:
      // Home and the booking confirmation still navigate to it.
      GoRoute(
        path: '/appointments',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AppointmentsScreen(),
      ),
      GoRoute(
        path: '/doctors/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return DoctorDetailScreen(doctorId: id);
        },
      ),
      GoRoute(
        path: '/saved-doctors',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SavedDoctorsScreen(),
      ),
      GoRoute(
        path: '/queue',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => QueueScreen(
          appointmentId:
              int.tryParse(state.uri.queryParameters['appointment_id'] ?? ''),
        ),
      ),

      // Records. `new` is matched before `:id`.
      GoRoute(
        path: '/records/:kind/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RecordFormScreen(
          kind: RecordKindRoute.fromSlug(state.pathParameters['kind']),
        ),
      ),
      GoRoute(
        path: '/records/:kind/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RecordDetailScreen(
          kind: RecordKindRoute.fromSlug(state.pathParameters['kind']),
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),

      // Profile & family.
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/family/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FamilyMemberScreen(),
      ),
      GoRoute(
        path: '/family/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => FamilyMemberScreen(
          memberId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),

      // Shop, above the tabs.
      GoRoute(
        path: '/shop/list',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ListingScreen(
          query: ListingQuery.fromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/shop/categories',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/shop/p/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ProductScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/shop/cart',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/shop/checkout',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/shop/orders',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/shop/orders/:orderNo',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => OrderDetailScreen(
          orderNo: state.pathParameters['orderNo'] ?? '',
          payResult: state.uri.queryParameters['pay'],
        ),
      ),
      GoRoute(
        path: '/shop/points',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PointsScreen(),
      ),
      GoRoute(
        path: '/shop/wishlist',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: '/shop/addresses',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: '/shop/addresses/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddressFormScreen(),
      ),
      GoRoute(
        path: '/shop/addresses/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AddressFormScreen(
          existing: state.extra is Address ? state.extra as Address : null,
        ),
      ),
      GoRoute(
        path: '/shop/invoice',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => InvoiceScreen(
          url: state.uri.queryParameters['url'] ?? '',
          title: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/book/:doctorId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['doctorId'] ?? '') ?? 0;
          final doctor = state.extra is Doctor ? state.extra as Doctor : null;
          return BookAppointmentScreen(doctorId: id, doctor: doctor);
        },
      ),
    ],
  );
}
