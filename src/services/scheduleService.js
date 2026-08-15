import { supabase } from "@/lib/supabaseClient";
import { getOwnedProviderShop, listApprovedDoctorsForProvider } from "@/services/providerService";

export async function loadScheduleContext(userId, role) {
  const { data: shop, error: shopError } = await getOwnedProviderShop(userId);
  if (shopError || !shop?.id) return { data: { shop: null, doctors: [], schedules: [], exceptions: [] }, error: shopError };
  let doctors = [];
  if (role === "doctor") doctors = [{ id: userId, full_name: "আমার সময়সূচি" }];
  else {
    const { data, error } = await listApprovedDoctorsForProvider();
    if (error) return { data: { shop, doctors: [], schedules: [], exceptions: [] }, error };
    doctors = data || [];
  }
  return { data: { shop, doctors }, error: null };
}

export async function fetchDoctorSchedule(doctorId, shopId) {
  const [schedulesRes, exceptionsRes] = await Promise.all([
    supabase.from("doctor_schedules").select("*").eq("doctor_id", doctorId).eq("shop_id", shopId).order("day_of_week"),
    supabase.from("doctor_schedule_exceptions").select("*").eq("doctor_id", doctorId).eq("shop_id", shopId).order("exception_date", { ascending: true }),
  ]);
  return { schedules: schedulesRes.data || [], exceptions: exceptionsRes.data || [], error: schedulesRes.error || exceptionsRes.error };
}

export function saveDaySchedule({ doctorId, shopId, dayOfWeek, enabled, startTime, endTime, slotDuration, breakStart, breakEnd }) {
  return supabase.rpc("save_doctor_schedule_day", {
    p_doctor_id: doctorId,
    p_shop_id: shopId,
    p_day_of_week: dayOfWeek,
    p_enabled: !!enabled,
    p_start_time: enabled ? startTime : null,
    p_end_time: enabled ? endTime : null,
    p_slot_duration_minutes: Number(slotDuration) || 30,
    p_break_start_time: enabled && breakStart ? breakStart : null,
    p_break_end_time: enabled && breakEnd ? breakEnd : null,
  });
}

export function addScheduleException({ doctorId, shopId, date, note }) {
  return supabase.from("doctor_schedule_exceptions").upsert({
    doctor_id: doctorId,
    shop_id: shopId,
    exception_date: date,
    is_available: false,
    note: note || null,
  }, { onConflict: "doctor_id,shop_id,exception_date" }).select().single();
}

export function deleteScheduleException(id) {
  return supabase.from("doctor_schedule_exceptions").delete().eq("id", id);
}
