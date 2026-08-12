import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

export function useAppointments({ role, userId, enabled = true } = {}) {
  const [appointments, setAppointments] = useState([]);
  const [loading, setLoading] = useState(Boolean(enabled && userId));
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!enabled || !userId) { setAppointments([]); setLoading(false); return; }
    let active = true;
    async function load() {
      setLoading(true);
      const column = role === "doctor" ? "doctor_id" : "patient_id";
      const { data, error } = await supabase
        .from("appointments")
        .select("*")
        .eq(column, userId)
        .order("appointment_date", { ascending: true })
        .order("created_at", { ascending: false });
      if (!active) return;
      setError(error?.message ?? null);
      setAppointments(data ?? []);
      setLoading(false);
    }
    load();
    return () => { active = false; };
  }, [enabled, role, userId]);

  const refresh = async () => {
    if (!userId) return;
    const column = role === "doctor" ? "doctor_id" : "patient_id";
    const { data, error } = await supabase.from("appointments").select("*")
      .eq(column, userId)
      .order("appointment_date", { ascending: true })
      .order("created_at", { ascending: false });
    setError(error?.message ?? null);
    setAppointments(data ?? []);
  };

  return { appointments, loading, error, refresh };
}

export async function createAppointment(payload) {
  return supabase.from("appointments").insert({
    doctor_id: payload.doctorId,
    patient_id: payload.patientId,
    product_id: payload.productId ?? null,
    shop_id: payload.shopId ?? null,
    appointment_date: payload.date,
    appointment_time: payload.time || null,
    note: payload.note || null,
    patient_name: payload.patientName || null,
    patient_phone: payload.patientPhone || null,
  }).select().single();
}

export async function updateAppointmentStatus(id, status, doctorNote = null) {
  return supabase.from("appointments").update({
    status,
    doctor_note: doctorNote,
  }).eq("id", id).select().single();
}
