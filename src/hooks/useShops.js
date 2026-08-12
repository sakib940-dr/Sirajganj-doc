import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

export function useShops({ limit } = {}) {
  const [shops, setShops] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      let query = supabase
        .from("shops")
        .select("*")
        .eq("is_active", true)
        .order("created_at", { ascending: false });
      if (limit) query = query.limit(limit);
      const { data, error } = await query;
      if (!active) return;
      if (error) setError(error.message);
      else setShops(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [limit]);

  return { shops, loading, error };
}

export function useShopBySlug(slug) {
  const [shop, setShop] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!slug) return;
    let active = true;
    async function load() {
      setLoading(true);
      const { data, error } = await supabase
        .from("shops")
        .select("*")
        .eq("slug", slug)
        .eq("is_active", true)
        .single();
      if (!active) return;
      if (error) setError(error.message);
      else setShop(data);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [slug]);

  return { shop, loading, error };
}
