import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { getSearchSynonyms, expandSearchTerms } from "@/lib/searchSynonyms";

const SELECT = "*, shops:shop_id ( shop_name, chamber_name, slug, whatsapp_number, phone, address, district, upazila, google_map_link, facebook_link, messenger_link, visiting_days, visiting_time, consultation_fee, latitude, longitude, location_visibility ), categories:category_id ( name, slug )";

export function useDoctorsDirectory({ district = "", upazila = "", section = "popular", query = "", page = 1, pageSize = 20 }) {
  const [products, setProducts] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      let q = supabase.from("products").select(SELECT, { count: "exact" }).eq("is_active", true);
      if (district) {
        const { data: shops } = await supabase.from("shops").select("id").eq("is_active", true).eq("district", district).match(upazila ? { upazila } : {});
        const ids = (shops || []).map((s) => s.id);
        if (!ids.length) { if (active) { setProducts([]); setTotal(0); setLoading(false); } return; }
        q = q.in("shop_id", ids);
      }
      if (query.trim()) {
        const synonyms = await getSearchSynonyms();
        const terms = expandSearchTerms(query, synonyms).map((t) => t.replace(/[,()%*]/g, "").trim()).filter(Boolean);
        if (terms.length) q = q.or(terms.map((t) => `name.ilike.%${t}%,description.ilike.%${t}%,name_bn.ilike.%${t}%,name_en.ilike.%${t}%,search_keywords.ilike.%${t}%`).join(","));
      }
      if (section === "latest") q = q.order("created_at", { ascending: false });
      else q = q.order("view_count", { ascending: false }).order("created_at", { ascending: false });
      const from = (page - 1) * pageSize;
      const { data, count, error } = await q.range(from, from + pageSize - 1);
      if (!active) return;
      setProducts(error ? [] : data || []);
      setTotal(error ? 0 : count || 0);
      setLoading(false);
    }
    load();
    return () => { active = false; };
  }, [district, upazila, section, query, page, pageSize]);

  return { products, total, loading };
}
