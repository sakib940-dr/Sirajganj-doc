import { supabase } from "@/lib/supabaseClient";

export async function getOwnedProviderShop(userId) {
  if (!userId) return { data: null, error: null };
  return supabase.from("shops").select("id,shop_name,chamber_name").eq("owner_id", userId).maybeSingle();
}

export async function listApprovedDoctorsForProvider() {
  return supabase.rpc("list_approved_doctors_for_provider");
}

export async function getProviderDashboardSummary(role, userId) {
  const result = { doctors: 0, appointments: 0, pending: 0, views: 0, saves: 0 };
  if (!userId) return { data: result, error: null };

  const { data: shop, error: shopError } = await getOwnedProviderShop(userId);
  if (shopError) return { data: result, error: shopError };

  let productsQuery = supabase.from("products").select("id,view_count,save_count", { count: "exact" });
  if (role === "hospital") {
    if (!shop?.id) return { data: result, error: null };
    productsQuery = productsQuery.eq("shop_id", shop.id);
  } else {
    productsQuery = productsQuery.eq("doctor_id", userId);
  }

  let appointmentsQuery = supabase.from("appointments").select("id", { count: "exact", head: true }).eq("status", "pending");
  if (role === "hospital") {
    if (shop?.id) appointmentsQuery = appointmentsQuery.eq("shop_id", shop.id);
  } else {
    appointmentsQuery = appointmentsQuery.eq("doctor_id", userId);
  }

  const [productsRes, appointmentsRes, verificationRes] = await Promise.all([
    productsQuery,
    appointmentsQuery,
    supabase.from("seller_verifications").select("id", { count: "exact", head: true }).eq("user_id", userId).in("status", ["pending", "under_review"]),
  ]);
  const error = productsRes.error || appointmentsRes.error || verificationRes.error;
  const rows = productsRes.data || [];
  return {
    data: {
      doctors: productsRes.count ?? rows.length,
      appointments: appointmentsRes.count ?? 0,
      pending: verificationRes.count ?? 0,
      views: rows.reduce((sum, row) => sum + Number(row.view_count || 0), 0),
      saves: rows.reduce((sum, row) => sum + Number(row.save_count || 0), 0),
    },
    error,
  };
}
