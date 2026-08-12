// Super Admin CMS ফর্মগুলোর জন্য সাধারণ ভ্যালিডেটর ফাংশন

export function validateEmail(val) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(val) ? null : "সঠিক ইমেইল ঠিকানা দিন (যেমন: name@example.com)";
}

export function validateUrl(val) {
  try {
    // আপেক্ষিক পাথ (যেমন /about) অথবা পূর্ণ URL — দুটোই গ্রহণযোগ্য
    if (val.startsWith("/")) return null;
    new URL(val);
    return null;
  } catch {
    return "সঠিক লিংক দিন (যেমন: https://example.com অথবা /page)";
  }
}

export function validatePhone(val) {
  const re = /^[+]?[\d\s-]{7,15}$/;
  return re.test(val) ? null : "সঠিক ফোন নম্বর দিন";
}
