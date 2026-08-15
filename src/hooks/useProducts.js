import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { searchNearbyDoctors } from "@/services/discoveryService";
import { getSearchSynonyms, expandSearchTerms } from "@/lib/searchSynonyms";

const PRODUCT_SELECT =
  "*, shops:shop_id ( shop_name, chamber_name, slug, whatsapp_number, phone, address, district, upazila, google_map_link, facebook_link, messenger_link, visiting_days, visiting_time, consultation_fee, latitude, longitude, location_visibility ), categories:category_id ( name, slug )";

export function useLatestProducts({ limit = 8 } = {}) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      const { data, error } = await supabase
        .from("products")
        .select(PRODUCT_SELECT)
        .eq("is_active", true)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (!active) return;
      if (error) setError(error.message);
      else setProducts(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [limit]);

  return { products, loading, error };
}

// "জনপ্রিয়" সেকশনের জন্য — বিক্রি ও ভিউ-এর ভিত্তিতে সাজানো, কোনো নতুন
// টেবিল/কলাম ছাড়াই বিদ্যমান sold_count ও view_count ব্যবহার করে
export function usePopularProducts({ limit = 10 } = {}) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      const { data, error } = await supabase
        .from("products")
        .select(PRODUCT_SELECT)
        .eq("is_active", true)
        .order("sold_count", { ascending: false })
        .order("view_count", { ascending: false })
        .limit(limit);
      if (!active) return;
      if (error) setError(error.message);
      else setProducts(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [limit]);

  return { products, loading, error };
}

// "ছাড়" সেকশনের জন্য — যেসব ডাক্তার প্রোফাইলে discount সক্রিয় আছে (discount_type != 'none'
// এবং discount_value > 0), সাম্প্রতিক আগে
export function useDiscountedProducts({ limit = 10 } = {}) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      const { data, error } = await supabase
        .from("products")
        .select(PRODUCT_SELECT)
        .eq("is_active", true)
        .neq("discount_type", "none")
        .gt("discount_value", 0)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (!active) return;
      if (error) setError(error.message);
      else setProducts(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [limit]);

  return { products, loading, error };
}

export function useProductsByCategory(categorySlug) {
  const [products, setProducts] = useState([]);
  const [subCategories, setSubCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!categorySlug) return;
    let active = true;
    async function load() {
      setLoading(true);
      const { data: category } = await supabase
        .from("categories")
        .select("id")
        .eq("slug", categorySlug)
        .single();

      if (!category) {
        if (active) {
          setProducts([]);
          setSubCategories([]);
          setLoading(false);
        }
        return;
      }

      // এই ক্যাটাগরির সাব-ক্যাটাগরি (থাকলে) খুঁজে বের করা হচ্ছে — মূল ক্যাটাগরিতে
      // ঢুকলে এর সব সাব-ক্যাটাগরির ডাক্তার প্রোফাইলও একসাথে দেখানো হবে
      const { data: children } = await supabase
        .from("categories")
        .select("id, name, slug")
        .eq("parent_id", category.id)
        .order("sort_order", { ascending: true });

      const categoryIds = [category.id, ...(children ?? []).map((c) => c.id)];

      const { data, error } = await supabase
        .from("products")
        .select(PRODUCT_SELECT)
        .in("category_id", categoryIds)
        .eq("is_active", true)
        .order("created_at", { ascending: false });

      if (!active) return;
      if (error) setError(error.message);
      else setProducts(data ?? []);
      setSubCategories(children ?? []);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [categorySlug]);

  return { products, subCategories, loading, error };
}

export function useProductBySlug(slug) {
  const [product, setProduct] = useState(null);
  const [images, setImages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!slug) return;
    let active = true;
    async function load() {
      setLoading(true);
      const { data, error } = await supabase
        .from("products")
        .select(`${PRODUCT_SELECT}`)
        .eq("slug", slug)
        .eq("is_active", true)
        .single();

      if (!active) return;
      if (error) {
        setError(error.message);
        setLoading(false);
        return;
      }
      setProduct(data);

      const { data: imgs } = await supabase
        .from("product_images")
        .select("*")
        .eq("product_id", data.id)
        .order("sort_order", { ascending: true });

      if (active) {
        setImages(imgs ?? []);
        setLoading(false);
      }
    }
    load();
    return () => {
      active = false;
    };
  }, [slug]);

  return { product, images, loading, error };
}

// PostgREST .or() ফিল্টার স্ট্রিং-এ ভাঙার মতো ক্যারেক্টার সরানো হয়
function sanitizeForOrFilter(term) {
  return term.replace(/[,()%*]/g, "").trim();
}

/**
 * বাংলা-ইংরেজি উভয় ভাষাতেই সার্চ কাজ করে — ইংরেজি লিখলেও বাংলা নামের ডাক্তার প্রোফাইল
 * পাওয়া যাবে (এবং উল্টোটাও), search_synonyms ডিকশনারির মাধ্যমে। ডাক্তার প্রোফাইলের নাম,
 * বিবরণ এবং ক্যাটাগরির নাম — তিনটাতেই মিলিয়ে দেখা হয়।
 */
export function useProductSearch(query) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!query || !query.trim()) {
      setProducts([]);
      return;
    }
    let active = true;
    async function load() {
      setLoading(true);
      setError(null);

      const synonyms = await getSearchSynonyms();
      const terms = expandSearchTerms(query, synonyms)
        .map(sanitizeForOrFilter)
        .filter(Boolean);

      if (terms.length === 0) {
        if (active) {
          setProducts([]);
          setLoading(false);
        }
        return;
      }

      const textFilter = terms
        .map(
          (t) =>
            `name.ilike.%${t}%,description.ilike.%${t}%,name_en.ilike.%${t}%,name_bn.ilike.%${t}%,search_keywords.ilike.%${t}%`
        )
        .join(",");
      const categoryFilter = terms.map((t) => `name.ilike.%${t}%`).join(",");

      const [textResult, categoryResult] = await Promise.all([
        supabase.from("products").select(PRODUCT_SELECT).eq("is_active", true).or(textFilter),
        supabase.from("categories").select("id").or(categoryFilter),
      ]);

      if (!active) return;

      if (textResult.error) {
        setError(textResult.error.message);
        setLoading(false);
        return;
      }

      let categoryMatches = [];
      const categoryIds = (categoryResult.data ?? []).map((c) => c.id);
      if (categoryIds.length > 0) {
        const { data } = await supabase
          .from("products")
          .select(PRODUCT_SELECT)
          .eq("is_active", true)
          .in("category_id", categoryIds);
        categoryMatches = data ?? [];
      }

      if (!active) return;

      const merged = new Map();
      [...(textResult.data ?? []), ...categoryMatches].forEach((p) => merged.set(p.id, p));
      const results = Array.from(merged.values()).sort(
        (a, b) => new Date(b.created_at) - new Date(a.created_at)
      );

      setProducts(results);
      setLoading(false);
    }
    load();
    return () => {
      active = false;
    };
  }, [query]);

  return { products, loading, error };
}

// একই ক্যাটাগরির অন্যান্য ডাক্তার প্রোফাইল (বর্তমান ডাক্তার প্রোফাইলটি বাদে) — "সম্পর্কিত ডাক্তার প্রোফাইল" সেকশনের জন্য
export function useRelatedProducts(categoryId, excludeProductId, { limit = 8 } = {}) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!categoryId) {
      setProducts([]);
      setLoading(false);
      return;
    }
    let active = true;
    setLoading(true);
    supabase
      .from("products")
      .select(PRODUCT_SELECT)
      .eq("category_id", categoryId)
      .eq("is_active", true)
      .neq("id", excludeProductId ?? "00000000-0000-0000-0000-000000000000")
      .order("created_at", { ascending: false })
      .limit(limit)
      .then(({ data, error }) => {
        if (!active) return;
        setProducts(error ? [] : data ?? []);
        setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [categoryId, excludeProductId, limit]);

  return { products, loading };
}


/**
 * নির্দিষ্ট জেলা/উপজেলার ডাক্তার প্রোফাইল।
 * Doctor-এর location তার Chamber/Hospital-এর location থেকে নেওয়া হয়।
 */
export function useProductsByLocation({ district, upazila, limit = 50, visitorLatitude = null, visitorLongitude = null, visitorLocationSource = "" } = {}) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    const hasCoords = Number.isFinite(Number(visitorLatitude)) && Number.isFinite(Number(visitorLongitude));
    if (!district && !hasCoords) {
      setProducts([]);
      setError(null);
      return;
    }
    let active = true;
    async function load() {
      setLoading(true);
      setError(null);
      const { data, error: rpcError } = await searchNearbyDoctors({
        p_district: district || null,
        p_upazila: upazila || null,
        p_latitude: hasCoords ? Number(visitorLatitude) : null,
        p_longitude: hasCoords ? Number(visitorLongitude) : null,
        p_radius_km: hasCoords ? 100 : null,
        p_limit: limit,
        p_offset: 0,
      });
      if (!active) return;
      if (rpcError) {
        setProducts([]);
        setError(rpcError.message);
      } else {
        setProducts((data ?? []).map((row) => ({
          ...row,
          distance_approximate: row?.distance_km != null && visitorLocationSource !== "device",
        })));
      }
      setLoading(false);
    }
    load();
    return () => { active = false; };
  }, [district, upazila, limit, visitorLatitude, visitorLongitude, visitorLocationSource]);

  return { products, loading, error };
}
