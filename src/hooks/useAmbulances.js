import { useCallback, useEffect, useState } from "react";
import { searchNearbyAmbulances } from "@/services/discoveryService";

export function useAmbulances({ latitude = null, longitude = null } = {}) {
  const [ambulances, setAmbulances] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const hasCoords = Number.isFinite(Number(latitude)) && Number.isFinite(Number(longitude));
    const { data, error: rpcError } = await searchNearbyAmbulances({
      p_latitude: hasCoords ? Number(latitude) : null,
      p_longitude: hasCoords ? Number(longitude) : null,
      p_radius_km: hasCoords ? 100 : null,
      p_limit: 50,
      p_offset: 0,
    });
    setAmbulances(rpcError ? [] : (data || []));
    setError(rpcError?.message || null);
    setLoading(false);
  }, [latitude, longitude]);
  useEffect(() => { load(); }, [load]);
  return { ambulances, loading, error, refresh: load };
}
