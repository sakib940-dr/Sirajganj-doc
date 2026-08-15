import { Routes, Route, Navigate } from "react-router-dom";
import MainLayout from "@/layouts/MainLayout.jsx";
import DashboardLayout from "@/layouts/DashboardLayout.jsx";
import AdminLayout from "@/layouts/AdminLayout.jsx";
import ProtectedRoute from "@/components/auth/ProtectedRoute.jsx";
import { ROUTES } from "@/constants/routes";
import { ROLES } from "@/constants/roles";
import { useAuth } from "@/hooks/useAuth";

// Public
import HomePage from "@/pages/public/HomePage.jsx";
import CategoryPage from "@/pages/public/CategoryPage.jsx";
import CategoriesListPage from "@/pages/public/CategoriesListPage.jsx";
import ShopPage from "@/pages/public/ShopPage.jsx";
import ShopsListPage from "@/pages/public/ShopsListPage.jsx";
import ProductPage from "@/pages/public/ProductPage.jsx";
import SearchResultPage from "@/pages/public/SearchResultPage.jsx";
import DoctorsListPage from "@/pages/public/DoctorsListPage.jsx";
import LoginPage from "@/pages/public/LoginPage.jsx";
import RegisterPage from "@/pages/public/RegisterPage.jsx";
import ForgotPasswordPage from "@/pages/public/ForgotPasswordPage.jsx";
import ResetPasswordPage from "@/pages/public/ResetPasswordPage.jsx";
import SavedItemsPage from "@/pages/public/SavedItemsPage.jsx";
import AboutPage from "@/pages/public/AboutPage.jsx";
import TermsPage from "@/pages/public/TermsPage.jsx";
import PrivacyPage from "@/pages/public/PrivacyPage.jsx";
import FaqPage from "@/pages/public/FaqPage.jsx";
import HelpPage from "@/pages/public/HelpPage.jsx";
import FeedbackPage from "@/pages/public/FeedbackPage.jsx";
import BloodBankPage from "@/pages/public/BloodBankPage.jsx";
import AmbulancePage from "@/pages/public/AmbulancePage.jsx";
import BloodDonorPage from "@/pages/public/BloodDonorPage.jsx";
import PatientAppointmentsPage from "@/pages/public/PatientAppointments.jsx";
import PatientDashboardPage from "@/pages/public/PatientDashboardPage.jsx";
import SettingsPage from "@/pages/shared/SettingsPage.jsx";
import PersonalDetailsPage from "@/pages/shared/PersonalDetailsPage.jsx";
import AccountPage from "@/pages/public/AccountPage.jsx";
import NotFoundPage from "@/pages/public/NotFoundPage.jsx";

// Seller
import DashboardHome from "@/pages/seller/DashboardHome.jsx";
import ShopSettingsPage from "@/pages/seller/ShopSettingsPage.jsx";
import ProviderProfileCenterPage from "@/pages/seller/ProviderProfileCenterPage.jsx";
import WebsiteBuilderPage from "@/pages/seller/WebsiteBuilderPage.jsx";
import ProductListPage from "@/pages/seller/ProductListPage.jsx";
import ProductEditPage from "@/pages/seller/ProductEditPage.jsx";
import GalleryPage from "@/pages/seller/GalleryPage.jsx";
import SellerVerificationPage from "@/pages/seller/SellerVerificationPage.jsx";
import AnalyticsPage from "@/pages/seller/AnalyticsPage.jsx";
import DoctorAppointmentsPage from "@/pages/seller/AppointmentsPage.jsx";
import AffiliationsPage from "@/pages/seller/AffiliationsPage.jsx";
import SchedulePage from "@/pages/seller/SchedulePage.jsx";

// Admin
import AdminDashboard from "@/pages/admin/AdminDashboard.jsx";
import UserManagePage from "@/pages/admin/UserManagePage.jsx";
import CredentialsPage from "@/pages/admin/CredentialsPage.jsx";
import SellerManagePage from "@/pages/admin/SellerManagePage.jsx";
import SellerVerificationManagePage from "@/pages/admin/SellerVerificationManagePage.jsx";
import CategoryManagePage from "@/pages/admin/CategoryManagePage.jsx";
import ProductManagePage from "@/pages/admin/ProductManagePage.jsx";
import BannerManagePage from "@/pages/admin/BannerManagePage.jsx";
import CMSPage from "@/pages/admin/cms/CMSPage.jsx";
import AmbulanceManagePage from "@/pages/admin/AmbulanceManagePage.jsx";
import BloodDonorManagePage from "@/pages/admin/BloodDonorManagePage.jsx";

function RoleAwareHome() {
  const { role } = useAuth();
  if (role === ROLES.ADMIN || role === ROLES.SUPER_ADMIN) return <Navigate to={ROUTES.ADMIN} replace />;
  if (role === ROLES.DOCTOR || role === ROLES.HOSPITAL) return <Navigate to={ROUTES.DASHBOARD} replace />;
  return <HomePage />;
}

function RoleAwareAccountRedirect() {
  const { role } = useAuth();
  if (role === ROLES.ADMIN || role === ROLES.SUPER_ADMIN) return <Navigate to={ROUTES.ADMIN_PERSONAL} replace />;
  if (role === ROLES.DOCTOR || role === ROLES.HOSPITAL) return <Navigate to={ROUTES.DASHBOARD_PERSONAL} replace />;
  return <AccountPage />;
}

export default function AppRoutes() {
  return (
    <Routes>
      {/* Public */}
      <Route element={<MainLayout />}>
        <Route path={ROUTES.HOME} element={<RoleAwareHome />} />
        <Route path={ROUTES.CATEGORIES} element={<CategoriesListPage />} />
        <Route path={ROUTES.CATEGORY} element={<CategoryPage />} />
        <Route path={ROUTES.SHOPS} element={<ShopsListPage />} />
        <Route path={ROUTES.SHOP} element={<ShopPage />} />
        <Route path={ROUTES.PRODUCT} element={<ProductPage />} />
        <Route path={ROUTES.SEARCH} element={<SearchResultPage />} />
        <Route path={ROUTES.DOCTORS} element={<DoctorsListPage />} />
        <Route path={ROUTES.LOGIN} element={<LoginPage />} />
        <Route path={ROUTES.REGISTER} element={<RegisterPage />} />
        <Route path={ROUTES.FORGOT_PASSWORD} element={<ForgotPasswordPage />} />
        <Route path={ROUTES.RESET_PASSWORD} element={<ResetPasswordPage />} />
        <Route path={ROUTES.ABOUT} element={<AboutPage />} />
        <Route path={ROUTES.TERMS} element={<TermsPage />} />
        <Route path={ROUTES.PRIVACY} element={<PrivacyPage />} />
        <Route path={ROUTES.FAQ} element={<FaqPage />} />
        <Route path={ROUTES.HELP} element={<HelpPage />} />
        <Route path={ROUTES.FEEDBACK} element={<FeedbackPage />} />
        <Route path={ROUTES.BLOOD_BANK} element={<BloodBankPage />} />
        <Route path={ROUTES.AMBULANCE} element={<AmbulancePage />} />
        <Route path={ROUTES.BLOOD_DONOR} element={<ProtectedRoute requiredRole={ROLES.PATIENT}><BloodDonorPage /></ProtectedRoute>} />
        <Route
          path={ROUTES.SAVED}
          element={
            <ProtectedRoute>
              <SavedItemsPage />
            </ProtectedRoute>
          }
        />
        {/* যেকোনো লগইন করা ইউজার (রোগী/ডাক্তার/অ্যাডমিন) — নিজের পাসওয়ার্ড পরিবর্তন */}
        <Route
          path={ROUTES.ACCOUNT}
          element={
            <ProtectedRoute>
              <RoleAwareAccountRedirect />
            </ProtectedRoute>
          }
        />
        <Route
          path={ROUTES.APPOINTMENTS}
          element={
            <ProtectedRoute requiredRole={ROLES.PATIENT}>
              <PatientAppointmentsPage />
            </ProtectedRoute>
          }
        />
      </Route>

      {/* Patient Dashboard — শুধুমাত্র patient role */}
      <Route
        path={ROUTES.PATIENT_DASHBOARD}
        element={
          <ProtectedRoute requiredRole={ROLES.PATIENT}>
            <MainLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<PatientDashboardPage />} />
      </Route>

      {/* Provider Dashboard — শুধুমাত্র Doctor/Chamber-Hospital; Admin/Patient এখানে ঢুকলে নিজের dashboard-এ redirect হবে */}
      {/* Seller (protected, role: seller — pending seller-রাও ঢুকতে পারবে যাতে Pending নোটিশ দেখতে পায়) */}
      <Route
        element={
          <ProtectedRoute requiredRole={ROLES.DOCTOR} allowPendingSeller>
            <DashboardLayout />
          </ProtectedRoute>
        }
      >
        <Route path={ROUTES.DASHBOARD} element={<DashboardHome />} />
        <Route path={ROUTES.DASHBOARD_PERSONAL} element={<Navigate to={ROUTES.DASHBOARD_PROFILE_CENTER} replace />} />
        <Route path={ROUTES.DASHBOARD_PROFILE_CENTER} element={<ProviderProfileCenterPage />} />
        <Route path={ROUTES.DASHBOARD_SETTINGS} element={<SettingsPage />} />
        <Route path={ROUTES.DASHBOARD_SHOP} element={<Navigate to={ROUTES.DASHBOARD_PROFILE_CENTER} replace />} />
        <Route path={ROUTES.DASHBOARD_WEBSITE} element={<WebsiteBuilderPage />} />
        <Route path={ROUTES.DASHBOARD_PRODUCTS} element={<ProductListPage />} />
        <Route path={ROUTES.DASHBOARD_PRODUCT_NEW} element={<ProductEditPage />} />
        <Route path={ROUTES.DASHBOARD_PRODUCT_EDIT} element={<ProductEditPage />} />
        <Route path={ROUTES.DASHBOARD_GALLERY} element={<GalleryPage />} />
        <Route path={ROUTES.DASHBOARD_VERIFICATION} element={<Navigate to={ROUTES.DASHBOARD_PROFILE_CENTER} replace />} />
        <Route path={ROUTES.DASHBOARD_ANALYTICS} element={<AnalyticsPage />} />
        <Route path={ROUTES.DASHBOARD_APPOINTMENTS} element={<DoctorAppointmentsPage />} />
        <Route path={ROUTES.DASHBOARD_SCHEDULE} element={<SchedulePage />} />
        <Route path={ROUTES.DASHBOARD_AFFILIATIONS} element={<AffiliationsPage />} />
      </Route>

      {/* Admin Panel (protected, role: admin অথবা super_admin) */}
      <Route
        element={
          <ProtectedRoute requiredRole={ROLES.ADMIN}>
            <AdminLayout />
          </ProtectedRoute>
        }
      >
        <Route path={ROUTES.ADMIN} element={<AdminDashboard />} />
        <Route path={ROUTES.ADMIN_PERSONAL} element={<PersonalDetailsPage />} />
        <Route path={ROUTES.ADMIN_SETTINGS} element={<SettingsPage />} />
        <Route
          path={ROUTES.ADMIN_USERS}
          element={
            <ProtectedRoute requiredRole={ROLES.SUPER_ADMIN}>
              <UserManagePage />
            </ProtectedRoute>
          }
        />
        <Route
          path={ROUTES.ADMIN_CREDENTIALS}
          element={
            <ProtectedRoute requiredRole={ROLES.SUPER_ADMIN}>
              <CredentialsPage />
            </ProtectedRoute>
          }
        />
        <Route path={ROUTES.ADMIN_SELLERS} element={<SellerManagePage />} />
        <Route path={ROUTES.ADMIN_VERIFICATIONS} element={<SellerVerificationManagePage />} />
        <Route path={ROUTES.ADMIN_CATEGORIES} element={<CategoryManagePage />} />
        <Route path={ROUTES.ADMIN_PRODUCTS} element={<ProductManagePage />} />
        <Route
          path={ROUTES.ADMIN_BANNERS}
          element={
            <ProtectedRoute requiredRole={ROLES.SUPER_ADMIN}>
              <BannerManagePage />
            </ProtectedRoute>
          }
        />
        <Route path={ROUTES.ADMIN_AMBULANCE} element={<AmbulanceManagePage />} />
        <Route path={ROUTES.ADMIN_BLOOD_DONORS} element={<BloodDonorManagePage />} />
        <Route
          path={ROUTES.ADMIN_CMS}
          element={
            <ProtectedRoute requiredRole={ROLES.SUPER_ADMIN}>
              <CMSPage />
            </ProtectedRoute>
          }
        />
        {/* পুরনো /admin/settings লিংক (বুকমার্ক/ইতিহাস) নতুন CMS প্যানেলে পাঠিয়ে দেওয়া হয় */}

      </Route>

      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
