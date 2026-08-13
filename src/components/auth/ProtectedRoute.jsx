import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
import { ROUTES } from "@/constants/routes";
import { ROLES, isAdminOrAbove } from "@/constants/roles";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

/**
 * @param {"seller" | "admin" | "super_admin"} requiredRole
 *   - "seller": seller (বা admin/super_admin) হতে হবে
 *   - "admin": Admin Panel অ্যাক্সেসের জন্য — role admin অথবা super_admin হলেই চলবে
 *   - "super_admin": শুধুমাত্র আসল Super Admin — Admin-ও ঢুকতে পারবে না
 * @param {boolean} allowPendingDoctor - true হলে seller_status !== approved থাকা সত্ত্বেও render হবে
 *   (Dashboard-এর ভেতরে "Pending Approval" বার্তা দেখানোর জন্য দরকার হয়)
 */
export default function ProtectedRoute({ children, requiredRole, allowPendingDoctor = false, allowPendingSeller = false }) {
  const { isLoggedIn, role, doctorStatus, accountStatus, loading, signOut } = useAuth();
  const location = useLocation();

  if (loading) {
    return <LoadingSpinner fullScreen label="লোড হচ্ছে..." />;
  }

  if (!isLoggedIn) {
    return <Navigate to={ROUTES.LOGIN} state={{ from: location }} replace />;
  }

  // ব্যান করা অ্যাকাউন্ট কোনো protected এলাকায় ঢুকতে পারবে না
  if (accountStatus === "banned") {
    signOut();
    return <Navigate to={ROUTES.LOGIN} replace />;
  }

  // প্রতিটি role-এর জন্য আলাদা dashboard boundary:
  // Doctor/Hospital → provider dashboard, Admin/Super Admin → admin panel,
  // Patient → patient dashboard. কোনো role অন্য role-এর dashboard দেখবে না।
  if (requiredRole === ROLES.SUPER_ADMIN) {
    if (role === ROLES.SUPER_ADMIN) return children;
    if (role === ROLES.ADMIN) return <Navigate to={ROUTES.ADMIN} replace />;
    if (role === ROLES.DOCTOR || role === ROLES.HOSPITAL) return <Navigate to={ROUTES.DASHBOARD} replace />;
    return <Navigate to={ROUTES.PATIENT_DASHBOARD} replace />;
  }

  if (requiredRole === ROLES.ADMIN) {
    if (role === ROLES.ADMIN || role === ROLES.SUPER_ADMIN) return children;
    if (role === ROLES.DOCTOR || role === ROLES.HOSPITAL) return <Navigate to={ROUTES.DASHBOARD} replace />;
    return <Navigate to={ROUTES.PATIENT_DASHBOARD} replace />;
  }

  if (requiredRole === ROLES.DOCTOR) {
    if (role !== ROLES.DOCTOR && role !== ROLES.HOSPITAL) {
      if (role === ROLES.ADMIN || role === ROLES.SUPER_ADMIN) return <Navigate to={ROUTES.ADMIN} replace />;
      return <Navigate to={ROUTES.PATIENT_DASHBOARD} replace />;
    }
    if (doctorStatus !== "approved" && !(allowPendingDoctor || allowPendingSeller)) {
      return <Navigate to={ROUTES.DASHBOARD} replace />;
    }
  }

  if (requiredRole === ROLES.PATIENT) {
    if (role !== ROLES.PATIENT) {
      if (role === ROLES.ADMIN || role === ROLES.SUPER_ADMIN) return <Navigate to={ROUTES.ADMIN} replace />;
      if (role === ROLES.DOCTOR || role === ROLES.HOSPITAL) return <Navigate to={ROUTES.DASHBOARD} replace />;
    }
  }

  return children;
}
