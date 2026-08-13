import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

export const BLOOD_GROUPS = ["A+","A-","B+","B-","AB+","AB-","O+","O-"];

export function useBloodDonors({ bloodGroup = "", latitude = null, longitude = null, enabled = true } = {}) {
  const [donors, setDonors] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const load = useCallback(async () => {
    if (!enabled) return;
    setLoading(true); setError("");
    const { data, error: rpcError } = await supabase.rpc("search_blood_donors", {
      p_blood_group: bloodGroup || null,
      p_latitude: latitude,
      p_longitude: longitude,
      p_limit: 50,
    });
    if (rpcError) setError(rpcError.message);
    setDonors(data || []);
    setLoading(false);
  }, [bloodGroup, latitude, longitude, enabled]);
  useEffect(() => { load(); }, [load]);
  return { donors, loading, error, refresh: load };
}

export async function updateDonorSettings(userId, fields) {
  return supabase.from("profiles").update(fields).eq("id", userId);
}

export async function createBloodRequest(payload) {
  return supabase.rpc("create_blood_request", {
    p_donor_id: payload.donorId,
    p_blood_group: payload.bloodGroup,
    p_patient_name: payload.patientName,
    p_patient_phone: payload.patientPhone || null,
    p_needed_date: payload.neededDate || null,
    p_needed_time: payload.neededTime || null,
    p_reason: payload.reason,
    p_hospital_name: payload.hospitalName || null,
    p_location_text: payload.locationText || null,
  });
}

export function useBloodRequests({ userId, role, mode = null, enabled = true } = {}) {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const load = useCallback(async () => {
    if (!enabled || !userId) return;
    setLoading(true);
    let query = supabase.from("blood_requests").select("*").order("created_at", { ascending: false });
    const asDonor = mode === "donor" || role !== "patient";
    query = asDonor ? query.eq("donor_id", userId) : query.eq("requester_id", userId);
    const { data } = await query;
    setRequests(data || []); setLoading(false);
  }, [userId, role, mode, enabled]);
  useEffect(() => { load(); }, [load]);
  return { requests, loading, refresh: load };
}

export async function updateBloodRequestStatus(id, status) {
  return supabase.from("blood_requests").update({ status }).eq("id", id);
}
