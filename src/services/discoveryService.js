import { supabase } from "@/lib/supabaseClient";

export function searchNearbyDoctors(params) {
  return supabase.rpc("search_nearby_doctors", params);
}

export function searchNearbyAmbulances(params) {
  return supabase.rpc("search_nearby_ambulances", params);
}

export function searchDoctorCatalog(params) {
  return supabase.rpc("search_doctors_catalog", params);
}

export function recordAmbulanceCallClick(ambulanceId) {
  return supabase.rpc("increment_ambulance_call_click", { p_ambulance_id: ambulanceId });
}

export function recordAmbulanceDirectionClick(ambulanceId) {
  return supabase.rpc("increment_ambulance_direction_click", { p_ambulance_id: ambulanceId });
}
