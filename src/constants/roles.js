export const ROLES = {
  PATIENT: "patient",
  DOCTOR: "doctor",
  ADMIN: "admin",
  SUPER_ADMIN: "super_admin",
};

// UI-তে প্রকৃত DB role অনুযায়ী লেবেল দেখানো হয় — SUPER_ADMIN হলে "সুপার অ্যাডমিন"
// এবং সাধারণ ADMIN হলে "অ্যাডমিন" দেখানো হয় (আগে ভুলবশত দুটোই "অ্যাডমিন"
// দেখাত, যদিও permission system/role hierarchy-তে কোনো সমস্যা ছিল না)।
export const ROLE_LABEL_BN = {
  [ROLES.PATIENT]: "রোগী",
  [ROLES.DOCTOR]: "ডাক্তার",
  [ROLES.ADMIN]: "অ্যাডমিন",
  [ROLES.SUPER_ADMIN]: "সুপার অ্যাডমিন",
};

export const ACCOUNT_STATUS = {
  ACTIVE: "active",
  BANNED: "banned",
};

export const ACCOUNT_STATUS_LABEL_BN = {
  [ACCOUNT_STATUS.ACTIVE]: "সক্রিয়",
  [ACCOUNT_STATUS.BANNED]: "ব্যান করা হয়েছে",
};

// role hierarchy — Admin Panel অ্যাক্সেসের জন্য ব্যবহৃত হয়
export function isAdminOrAbove(role) {
  return role === ROLES.ADMIN || role === ROLES.SUPER_ADMIN;
}

export const DOCTOR_STATUS = {
  NONE: "none",
  PENDING: "pending",
  APPROVED: "approved",
  REJECTED: "rejected",
};

export const DOCTOR_STATUS_LABEL_BN = {
  [DOCTOR_STATUS.NONE]: "ডাক্তার নন",
  [DOCTOR_STATUS.PENDING]: "অনুমোদনের অপেক্ষায়",
  [DOCTOR_STATUS.APPROVED]: "অনুমোদিত",
  [DOCTOR_STATUS.REJECTED]: "প্রত্যাখ্যাত",
};

export const VERIFICATION_STATUS = {
  PENDING: "pending",
  APPROVED: "approved",
  REJECTED: "rejected",
};

export const VERIFICATION_STATUS_LABEL_BN = {
  [VERIFICATION_STATUS.PENDING]: "পর্যালোচনাধীন",
  [VERIFICATION_STATUS.APPROVED]: "ভেরিফাইড",
  [VERIFICATION_STATUS.REJECTED]: "প্রত্যাখ্যাত",
};

// Backward-compatible internal aliases during V1 migration.
export const SELLER_STATUS = DOCTOR_STATUS;
export const SELLER_STATUS_LABEL_BN = DOCTOR_STATUS_LABEL_BN;
