import { useState, useEffect, useCallback } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";

// ডাক্তার প্রোফাইলের পেজ ভিউ ট্র্যাক করে (fire-and-forget, RPC atomic increment ব্যবহার করে)
export async function trackProductView(productId) {
  if (!productId) return;
  try {
    await supabase.rpc("increment_product_view", { p_product_id: productId });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error("ভিউ ট্র্যাক করা যায়নি:", err);
  }
}

// "অর্ডার করুন" বাটনে ক্লিক ট্র্যাক করে (WhatsApp/Facebook এ যাওয়ার আগে)
export async function trackProductOrderClick(productId) {
  if (!productId) return;
  try {
    await supabase.rpc("increment_product_order_click", { p_product_id: productId });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error("ক্লিক ট্র্যাক করা যায়নি:", err);
  }
}

// একজন লগইন ইউজার একটি ডাক্তার প্রোফাইল সেভ করেছেন কিনা এবং সেভ/আনসেভ (toggle) করার হুক
export function useProductSave(productId) {
  const { user, isLoggedIn } = useAuth();
  const [isSaved, setIsSaved] = useState(false);
  const [checking, setChecking] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!productId || !isLoggedIn || !user) {
      setIsSaved(false);
      setChecking(false);
      return;
    }
    let active = true;
    setChecking(true);
    supabase
      .from("product_saves")
      .select("id")
      .eq("product_id", productId)
      .eq("user_id", user.id)
      .maybeSingle()
      .then(({ data }) => {
        if (active) {
          setIsSaved(!!data);
          setChecking(false);
        }
      });
    return () => {
      active = false;
    };
  }, [productId, isLoggedIn, user]);

  const toggleSave = useCallback(async () => {
    if (!productId || saving) return { requiresLogin: !isLoggedIn };
    if (!isLoggedIn || !user) return { requiresLogin: true };

    setSaving(true);
    const wasSaved = isSaved;
    setIsSaved(!wasSaved); // optimistic UI

    try {
      if (wasSaved) {
        const { error } = await supabase
          .from("product_saves")
          .delete()
          .eq("product_id", productId)
          .eq("user_id", user.id);
        if (error) setIsSaved(true); // rollback
      } else {
        const { error } = await supabase
          .from("product_saves")
          .insert({ product_id: productId, user_id: user.id });
        if (error) setIsSaved(false); // rollback
      }
    } finally {
      setSaving(false);
    }
    return { requiresLogin: false };
  }, [productId, isLoggedIn, user, isSaved, saving]);

  return { isSaved, checking, saving, toggleSave };
}

// একজন লগইন ইউজার একটি চেম্বার সেভ (ফলো) করেছেন কিনা এবং সেভ/আনসেভ করার হুক
export function useShopSave(shopId) {
  const { user, isLoggedIn } = useAuth();
  const [isSaved, setIsSaved] = useState(false);
  const [checking, setChecking] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!shopId || !isLoggedIn || !user) {
      setIsSaved(false);
      setChecking(false);
      return;
    }
    let active = true;
    setChecking(true);
    supabase
      .from("shop_saves")
      .select("id")
      .eq("shop_id", shopId)
      .eq("user_id", user.id)
      .maybeSingle()
      .then(({ data }) => {
        if (active) {
          setIsSaved(!!data);
          setChecking(false);
        }
      });
    return () => {
      active = false;
    };
  }, [shopId, isLoggedIn, user]);

  const toggleSave = useCallback(async () => {
    if (!shopId || saving) return { requiresLogin: !isLoggedIn };
    if (!isLoggedIn || !user) return { requiresLogin: true };

    setSaving(true);
    const wasSaved = isSaved;
    setIsSaved(!wasSaved); // optimistic UI

    try {
      if (wasSaved) {
        const { error } = await supabase
          .from("shop_saves")
          .delete()
          .eq("shop_id", shopId)
          .eq("user_id", user.id);
        if (error) setIsSaved(true); // rollback
      } else {
        const { error } = await supabase
          .from("shop_saves")
          .insert({ shop_id: shopId, user_id: user.id });
        if (error) setIsSaved(false); // rollback
      }
    } finally {
      setSaving(false);
    }
    return { requiresLogin: false };
  }, [shopId, isLoggedIn, user, isSaved, saving]);

  return { isSaved, checking, saving, toggleSave };
}
