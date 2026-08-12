import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

/**
 * Super Admin CMS — site_settings (key/value) টেবিলের সম্পূর্ণ ম্যানেজমেন্ট হুক।
 * সব সাধারণ CMS সেকশন (General, Hero, About, Contact, Legal, Footer, SEO)
 * এই একটি হুক শেয়ার করে, যাতে ট্যাব বদলানোর সময় বারবার লোড না হয়।
 *
 * - saveFields(patch)  → একাধিক key upsert করে (Add নতুন key হলে, Edit থাকলে)
 * - clearFields(keys)  → key(গুলো) সম্পূর্ণভাবে ডিলিট করে (row বাদ, ডিফল্টে ফিরে যাবে)
 */
export function useSiteSettingsAdmin() {
  const [values, setValues] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    const { data, error: loadError } = await supabase.from("site_settings").select("*");
    if (loadError) {
      setError("সেটিংস লোড করা যায়নি: " + loadError.message);
      setLoading(false);
      return;
    }
    const map = {};
    (data ?? []).forEach((row) => {
      map[row.key] = row.value ?? "";
    });
    setValues(map);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  /** @param {Record<string,string>} patch */
  const saveFields = useCallback(async (patch) => {
    const rows = Object.entries(patch).map(([key, value]) => ({ key, value: value ?? "" }));
    if (rows.length === 0) return { error: null };
    const { error: saveError } = await supabase.from("site_settings").upsert(rows, { onConflict: "key" });
    if (saveError) return { error: saveError };
    setValues((prev) => ({ ...prev, ...patch }));
    return { error: null };
  }, []);

  /** @param {string[]} keys */
  const clearFields = useCallback(async (keys) => {
    if (!keys || keys.length === 0) return { error: null };
    const { error: delError } = await supabase.from("site_settings").delete().in("key", keys);
    if (delError) return { error: delError };
    setValues((prev) => {
      const next = { ...prev };
      keys.forEach((k) => delete next[k]);
      return next;
    });
    return { error: null };
  }, []);

  return { values, loading, error, reload: load, saveFields, clearFields };
}
