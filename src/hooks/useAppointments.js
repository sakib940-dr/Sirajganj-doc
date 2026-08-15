import { useEffect, useState } from "react";
import { fetchAppointmentsForRole,createAppointmentRow,updateAppointmentStatusRow,updateAppointmentRow,fetchAvailableSlots,fetchScheduleConfigured,fetchAppointmentHistory } from "@/services/appointmentService";
export function useAppointments({role,userId,enabled=true}={}){const[appointments,setAppointments]=useState([]);const[loading,setLoading]=useState(Boolean(enabled&&userId));const[error,setError]=useState(null);async function load(){if(!enabled||!userId){setAppointments([]);setLoading(false);return;}setLoading(true);const{data,error}=await fetchAppointmentsForRole(role,userId);setError(error?.message??null);setAppointments(data??[]);setLoading(false);}useEffect(()=>{load();},[enabled,role,userId]);return{appointments,loading,error,refresh:load};}
export const createAppointment=createAppointmentRow;
export const updateAppointmentStatus=updateAppointmentStatusRow;
export const updateAppointment=updateAppointmentRow;
export const getDoctorAvailableSlots=fetchAvailableSlots;
export const hasDoctorSchedule=fetchScheduleConfigured;
export const getAppointmentHistory=fetchAppointmentHistory;
