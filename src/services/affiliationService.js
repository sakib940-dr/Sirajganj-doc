import { supabase } from "@/lib/supabaseClient";

export function searchInvitableDoctors(query = "") {
  return supabase.rpc("search_invitable_doctors_for_provider", { p_query: query || null, p_limit: 50 });
}

export function inviteDoctor(doctorId, message = "") {
  return supabase.rpc("invite_doctor_to_provider", { p_doctor_id: doctorId, p_message: message || null });
}

export function listProviderDoctorLinks() {
  return supabase.rpc("list_provider_doctor_links");
}

export function listMyProviderInvitations() {
  return supabase.rpc("list_my_provider_invitations");
}

export function respondToProviderInvitation(linkId, accept) {
  return supabase.rpc("respond_doctor_provider_invitation", { p_link_id: linkId, p_accept: !!accept });
}

export function leaveProviderAffiliation(linkId) {
  return supabase.rpc("leave_doctor_provider_affiliation", { p_link_id: linkId });
}
