import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

// শুধু অ্যানালিটিক্সের জন্য দরকারি কলামগুলোই সিলেক্ট করা হয় (দ্রুত query-র জন্য) —
// shop_id-তে ফিল্টার + view_count অনুযায়ী সর্ট, দুটোই ইনডেক্স করা কলামে
const ANALYTICS_SELECT =
  "id, name, thumbnail_url, is_active, stock_quantity, view_count, save_count, click_count";

/**
 * লগইন করা ডাক্তারের চেম্বার খুঁজে বের করে সেই চেম্বারের সব ডাক্তার প্রোফাইলের অ্যানালিটিক্স
 * (view/save/click/stock/status) লোড করে এবং near-real-time আপডেট রাখে।
 *
 * এই হুকটি ড্যাশবোর্ড ওভারভিউ (সামারি কার্ড + চার্ট) এবং সম্পূর্ণ অ্যানালিটিক্স
 * পেজ — দুই জায়গাতেই ব্যবহৃত হয়, যাতে একই লজিক দুইবার লিখতে না হয় এবং
 * ডুপ্লিকেট রিয়েলটাইম সাবস্ক্রিপশন তৈরি না হয়।
 *
 * @param {boolean} enabled - false হলে কোনো query/subscription চলবে না
 * (উদাহরণ: ডাক্তার এখনো অনুমোদিত না হলে)
 */
export function useSellerProductStats({ user, enabled = true } = {}) {
  const [shopId, setShopId] = useState(null);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  const loadProducts = useCallback(async (shop_id) => {
    const { data } = await supabase
      .from("products")
      .select(ANALYTICS_SELECT)
      .eq("shop_id", shop_id)
      .order("view_count", { ascending: false });
    setProducts(data ?? []);
  }, []);

  useEffect(() => {
    if (!enabled || !user) {
      setLoading(false);
      return;
    }
    let active = true;
    setLoading(true);
    supabase
      .from("shops")
      .select("id")
      .eq("owner_id", user.id)
      .maybeSingle()
      .then(async ({ data: shop }) => {
        if (!active) return;
        setShopId(shop?.id ?? null);
        if (shop) {
          await loadProducts(shop.id);
        } else {
          setProducts([]);
        }
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [enabled, user, loadProducts]);

  // near-real-time আপডেট: এই চেম্বারের কোনো ডাক্তার প্রোফাইলের view/save/click/stock/status
  // বাড়লে বা কমলেই (Supabase Realtime দিয়ে) সামারি কার্ড, চার্ট ও টপ-লিস্ট
  // স্বয়ংক্রিয়ভাবে আপডেট হবে — পেজ রিফ্রেশ বা পোলিং করার দরকার নেই
  useEffect(() => {
    if (!shopId) return;

    const channel = supabase
      .channel(`product-analytics-${shopId}`)
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "products", filter: `shop_id=eq.${shopId}` },
        (payload) => {
          setProducts((prev) =>
            prev.map((p) =>
              p.id === payload.new.id
                ? {
                    ...p,
                    view_count: payload.new.view_count,
                    save_count: payload.new.save_count,
                    click_count: payload.new.click_count,
                    is_active: payload.new.is_active,
                    stock_quantity: payload.new.stock_quantity,
                    name: payload.new.name,
                    thumbnail_url: payload.new.thumbnail_url,
                  }
                : p
            )
          );
        }
      )
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "products", filter: `shop_id=eq.${shopId}` },
        (payload) => {
          setProducts((prev) => [
            {
              id: payload.new.id,
              name: payload.new.name,
              thumbnail_url: payload.new.thumbnail_url,
              is_active: payload.new.is_active,
              stock_quantity: payload.new.stock_quantity,
              view_count: payload.new.view_count,
              save_count: payload.new.save_count,
              click_count: payload.new.click_count,
            },
            ...prev,
          ]);
        }
      )
      .on(
        "postgres_changes",
        { event: "DELETE", schema: "public", table: "products", filter: `shop_id=eq.${shopId}` },
        (payload) => {
          setProducts((prev) => prev.filter((p) => p.id !== payload.old.id));
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [shopId]);

  // সব সামারি সংখ্যা একবারেই হিসাব করা হয় — products state বদলালেই (initial লোড
  // বা realtime আপডেট) মেমোতে রিক্যালকুলেট হবে, আলাদা কোনো query লাগে না
  const stats = useMemo(() => {
    let activeProducts = 0;
    let outOfStockProducts = 0;
    let views = 0;
    let saves = 0;
    let clicks = 0;
    for (const p of products) {
      if (p.is_active) activeProducts += 1;
      if (Number(p.stock_quantity ?? 0) <= 0) outOfStockProducts += 1;
      views += p.view_count ?? 0;
      saves += p.save_count ?? 0;
      clicks += p.click_count ?? 0;
    }
    return {
      totalProducts: products.length,
      activeProducts,
      inactiveProducts: products.length - activeProducts,
      outOfStockProducts,
      inStockProducts: products.length - outOfStockProducts,
      views,
      saves,
      clicks,
    };
  }, [products]);

  const mostViewed = useMemo(
    () =>
      [...products]
        .filter((p) => (p.view_count ?? 0) > 0)
        .sort((a, b) => (b.view_count ?? 0) - (a.view_count ?? 0))
        .slice(0, 5),
    [products]
  );

  const mostSaved = useMemo(
    () =>
      [...products]
        .filter((p) => (p.save_count ?? 0) > 0)
        .sort((a, b) => (b.save_count ?? 0) - (a.save_count ?? 0))
        .slice(0, 5),
    [products]
  );

  return { shopId, products, stats, mostViewed, mostSaved, loading };
}
