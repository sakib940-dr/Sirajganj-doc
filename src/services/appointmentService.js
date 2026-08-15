import { supabase } from "@/lib/supabaseClient";
import { getOwnedProviderShop } from "@/services/providerService";

async function appointmentQueryForRole(role, userId) {
  let q = supabase.from("appointments").select("*");
  if (role === "doctor") return { query:q.eq("doctor_id",userId), error:null };
  if (role === "hospital") {
    const {data:shop,error}=await getOwnedProviderShop(userId);
    if(error)return{query:null,error}; if(!shop?.id)return{query:null,empty:true,error:null};
    return{query:q.eq("shop_id",shop.id),error:null};
  }
  return{query:q.eq("patient_id",userId),error:null};
}
export async function fetchAppointmentsForRole(role,userId){const scoped=await appointmentQueryForRole(role,userId);if(scoped.error)return{data:[],error:scoped.error};if(scoped.empty)return{data:[],error:null};return scoped.query.order("appointment_date",{ascending:true}).order("created_at",{ascending:false});}
export function createAppointmentRow(payload){return supabase.from("appointments").insert({doctor_id:payload.doctorId,patient_id:payload.patientId,product_id:payload.productId??null,shop_id:payload.shopId??null,appointment_date:payload.date,appointment_time:payload.time||null,note:payload.note||null,patient_name:payload.patientName||null,patient_phone:payload.patientPhone||null}).select().single();}
export function updateAppointmentRow(id,patch){return supabase.from("appointments").update(patch).eq("id",id).select().single();}
export function updateAppointmentStatusRow(id,status,doctorNote=null,extra={}){const patch={status,...extra};if(doctorNote!=null)patch.doctor_note=doctorNote;return updateAppointmentRow(id,patch);}
export function fetchAvailableSlots(doctorId,shopId,date){if(!doctorId||!shopId||!date)return Promise.resolve({data:[],error:null});return supabase.rpc("get_doctor_available_slots",{p_doctor_id:doctorId,p_shop_id:shopId,p_date:date});}
export function fetchScheduleConfigured(doctorId,shopId){if(!doctorId||!shopId)return Promise.resolve({data:false,error:null});return supabase.rpc("has_doctor_schedule",{p_doctor_id:doctorId,p_shop_id:shopId});}
export function fetchAppointmentHistory(id){return supabase.from("appointment_status_history").select("*").eq("appointment_id",id).order("created_at",{ascending:true});}
