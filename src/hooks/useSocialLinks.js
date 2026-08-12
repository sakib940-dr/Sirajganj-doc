import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

/** সক্রিয় সোশ্যাল মিডিয়া লিংক পাবলিকভাবে পড়ার জন্য (Header/Footer এ ব্যবহারযোগ্য) */
export function useSocialLinks() {
  const [links, setLinks] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    supabase
      .from("social_links")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .then(({ data }) => {
        if (active) {
          setLinks(data ?? []);
          setLoading(false);
        }
      });
    return () => {
      active = false;
    };
  }, []);

  return { links, loading };
}
