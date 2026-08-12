import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

/**
 * @param {{ rootOnly?: boolean }} options - rootOnly true হলে শুধু মূল (parent) ক্যাটাগরি ফেরত দেয়, সাব-ক্যাটাগরি বাদ যায়
 */
export function useCategories({ rootOnly = false } = {}) {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      let query = supabase.from("categories").select("*").order("sort_order", { ascending: true });
      if (rootOnly) query = query.is("parent_id", null);
      const { data, error } = await query;
      if (!active) return;
      if (error) setError(error.message);
      else setCategories(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [rootOnly]);

  return { categories, loading, error };
}
