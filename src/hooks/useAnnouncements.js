import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

/** সক্রিয় নোটিশ/অ্যানাউন্সমেন্ট বার পাবলিকভাবে পড়ার জন্য */
export function useAnnouncements() {
  const [announcements, setAnnouncements] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    supabase
      .from("announcements")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .then(({ data }) => {
        if (active) {
          setAnnouncements(data ?? []);
          setLoading(false);
        }
      });
    return () => {
      active = false;
    };
  }, []);

  return { announcements, loading };
}
