import { useCallback, useEffect, useRef, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

// এই টেবিলগুলোর যেকোনো পরিবর্তনে (কোনো row-filter ছাড়াই, যেহেতু স্কোপ পুরো
// মার্কেটপ্লেস) সামারি রিফ্রেশ করা হয়
const REALTIME_TABLES = ["products", "profiles", "seller_verifications"];

// একসাথে অনেক ইভেন্ট এলে (যেমন বাল্ক ইম্পোর্ট) বারবার RPC কল না করে একটু
// অপেক্ষা করে একবারে রিফ্রেশ করা হয় — এটাই "near real-time"-এর জন্য যথেষ্ট
// এবং ডাটাবেসের উপর অহেতুক চাপ কমায়
const REFRESH_DEBOUNCE_MS = 1000;

/**
 * Super Admin Analytics — পুরো মার্কেটপ্লেসের অ্যাগ্রিগেট পরিসংখ্যান
 * (Top Sellers, Top Products, Top Categories, Totals, Growth Summary)।
 *
 * ডেটা-অ্যাগ্রিগেশনের সম্পূর্ণ লজিক ডাটাবেস সাইডে থাকে
 * (`super_admin_analytics_summary` RPC — দেখুন
 * supabase/migrations/0014_super_admin_analytics.sql)। ভারী গণনা
 * (SUM/COUNT/GROUP BY/TOP-N) ইনডেক্স ব্যবহার করে সার্ভারে হয়, নেটওয়ার্কে
 * শুধু চূড়ান্ত ফলাফল (ছোট একটি JSON অবজেক্ট) আসে — একাধিক আলাদা কোয়েরির
 * বদলে মাত্র ১টা round-trip।
 *
 * Realtime: প্রতিটা আলাদা ইভেন্টে ম্যানুয়ালি state patch করার বদলে (যা
 * top-10/sum/count-এর মতো ডেরাইভড ডেটার জন্য জটিল ও ভুল-প্রবণ), পরিবর্তন
 * এলে পুরো সামারি আবার fetch করা হয় — ফলে ডেটা সবসময় ডাটাবেসের সাথে
 * সামঞ্জস্যপূর্ণ থাকে।
 */
export function useSuperAdminAnalytics({ enabled = true } = {}) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const activeRef = useRef(true);
  const debounceRef = useRef(null);

  const load = useCallback(async () => {
    const { data: result, error: rpcError } = await supabase.rpc(
      "super_admin_analytics_summary"
    );
    if (!activeRef.current) return;
    if (rpcError) setError(rpcError.message);
    else {
      setError("");
      setData(result);
    }
    setLoading(false);
  }, []);

  // initial লোড
  useEffect(() => {
    activeRef.current = true;
    if (!enabled) {
      setLoading(false);
      return;
    }
    setLoading(true);
    load();
    return () => {
      activeRef.current = false;
    };
  }, [enabled, load]);

  // near-real-time রিফ্রেশ
  useEffect(() => {
    if (!enabled) return;

    const scheduleRefresh = () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(load, REFRESH_DEBOUNCE_MS);
    };

    const channel = supabase.channel("super-admin-analytics");
    REALTIME_TABLES.forEach((table) => {
      channel.on("postgres_changes", { event: "*", schema: "public", table }, scheduleRefresh);
    });
    channel.subscribe();

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      supabase.removeChannel(channel);
    };
  }, [enabled, load]);

  return { data, loading, error, refresh: load };
}
