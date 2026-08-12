import { createContext, useContext, useMemo, useState } from "react";

// Header-এর হ্যামবার্গার মেনু এবং নতুন Patient Bottom Navigation-এর "☰ মেনু"
// ট্যাব — দুটোই একই মোবাইল মেনু প্যানেল খোলে/বন্ধ করে। এই context ছাড়া
// দুই জায়গায় আলাদা মেনু state/লজিক ডুপ্লিকেট করতে হতো।
const MobileMenuContext = createContext(null);

export function MobileMenuProvider({ children }) {
  const [isOpen, setIsOpen] = useState(false);

  const value = useMemo(
    () => ({
      isOpen,
      open: () => setIsOpen(true),
      close: () => setIsOpen(false),
      toggle: () => setIsOpen((v) => !v),
    }),
    [isOpen]
  );

  return <MobileMenuContext.Provider value={value}>{children}</MobileMenuContext.Provider>;
}

export function useMobileMenu() {
  const ctx = useContext(MobileMenuContext);
  if (!ctx) {
    throw new Error("useMobileMenu অবশ্যই MobileMenuProvider-এর ভেতরে ব্যবহার করতে হবে");
  }
  return ctx;
}
