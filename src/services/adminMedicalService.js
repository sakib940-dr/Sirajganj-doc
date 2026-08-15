import { supabase } from "@/lib/supabaseClient";

export function fetchAdminMedicalAnalytics(days = 30) {
  return supabase.rpc("admin_medical_analytics", { p_days: days });
}

export async function fetchAdminBloodDonors(filters = {}) {
  const result = await supabase.rpc("admin_list_blood_donors", {
    p_search: filters.search || null, p_blood_group: filters.bloodGroup || null, p_district: filters.district || null,
    p_upazila: filters.upazila || null, p_available_only: !!filters.availableOnly, p_limit: filters.limit || 200, p_offset: filters.offset || 0,
  });
  return { ...result, data: (result.data || []).map((row) => ({
    ...row, user_id: row.id, blood_address: row.address, location_district: row.district, location_upazila: row.upazila,
    latitude: row.location_latitude, longitude: row.location_longitude, location_source: row.location_source, updated_at: row.location_updated_at,
  })) };
}

export function setAdminBloodDonorAvailability(userId, isAvailable, acceptRequests) {
  return supabase.rpc("admin_set_blood_donor_availability", {
    p_user_id: userId,
    p_is_available: !!isAvailable,
    p_accept_requests: acceptRequests == null ? null : !!acceptRequests,
  });
}

export function fetchAdminBloodRequests() {
  return supabase.rpc("admin_list_blood_requests", { p_limit: 300 });
}

export function fetchSuperAdminUserLocations() {
  return supabase.rpc("get_super_admin_user_locations");
}
