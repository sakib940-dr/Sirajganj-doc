import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { calculateDistanceKm } from "@/lib/geo";

export function useAmbulances({ latitude = null, longitude = null } = {}) {
  const [ambulances, setAmbulances] = useState([]);
  const [loading, setLoading] = useState(true);
  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase.from("ambulance_services").select("*").order("is_available", { ascending: false }).order("name");
    const rows = (data || []).map((a) => ({
      ...a,
      distance_km: calculateDistanceKm(latitude, longitude, a.latitude, a.longitude),
    })).sort((a,b) => (a.distance_km ?? 1e9) - (b.distance_km ?? 1e9));
    setAmbulances(rows); setLoading(false);
  }, [latitude, longitude]);
  useEffect(() => { load(); }, [load]);
  return { ambulances, loading, refresh: load };
}
