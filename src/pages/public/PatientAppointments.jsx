import { useState } from "react";
import { CalendarDays, Clock3, XCircle } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { useAppointments, updateAppointmentStatus } from "@/hooks/useAppointments";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

const labels={pending:"অপেক্ষমাণ",confirmed:"নিশ্চিত",cancelled:"বাতিল",completed:"সম্পন্ন",rescheduled:"পুনঃনির্ধারিত",no_show:"অনুপস্থিত"};
export default function PatientAppointmentsPage(){
 const{user,role}=useAuth();const{appointments,loading,error,refresh}=useAppointments({role,userId:user?.id,enabled:role==="patient"});const[busy,setBusy]=useState(null);
 async function cancel(a){const reason=window.prompt("অ্যাপয়েন্টমেন্ট বাতিলের কারণ লিখুন:","");if(reason===null)return;if(!reason.trim()){window.alert("বাতিলের কারণ লিখতে হবে।");return;}setBusy(a.id);const{error}=await updateAppointmentStatus(a.id,"cancelled",null,{cancellation_reason:reason.trim()});setBusy(null);if(error)window.alert(error.message);else refresh();}
 if(loading)return <LoadingSpinner fullScreen label="অ্যাপয়েন্টমেন্ট লোড হচ্ছে..."/>;
 return <div className="container py-8"><h1 className="text-xl font-bold">আমার অ্যাপয়েন্টমেন্ট</h1><p className="mt-1 text-sm text-muted-foreground">আপনার appointment request, সময় ও status দেখুন।</p>{error&&<p className="mt-4 text-sm text-destructive">{error}</p>}
 {!appointments.length?<div className="mt-6 rounded-2xl border p-8 text-center text-sm text-muted-foreground">এখনো কোনো অ্যাপয়েন্টমেন্ট নেই।</div>:<div className="mt-6 space-y-3">{appointments.map(a=><div key={a.id} className="rounded-2xl border bg-card p-4"><div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"><div><p className="font-semibold">{a.doctor_name}</p><p className="mt-1 text-sm text-muted-foreground">{a.chamber_name||"চেম্বার"}</p><div className="mt-2 flex flex-wrap gap-3 text-sm"><span className="flex items-center gap-1"><CalendarDays className="h-4 w-4 text-primary"/>{a.appointment_date}</span>{a.appointment_time&&<span className="flex items-center gap-1"><Clock3 className="h-4 w-4 text-primary"/>{a.appointment_time}</span>}</div>{a.reschedule_reason&&<p className="mt-2 text-xs text-amber-700">সময় পরিবর্তনের কারণ: {a.reschedule_reason}</p>}{a.cancellation_reason&&<p className="mt-2 text-xs text-destructive">বাতিলের কারণ: {a.cancellation_reason}</p>}</div><span className="h-fit rounded-full bg-secondary px-3 py-1 text-xs">{labels[a.status]||a.status}</span></div>{a.appointment_number&&<p className="mt-3 text-xs text-muted-foreground">#{a.appointment_number}</p>}{['pending','confirmed','rescheduled'].includes(a.status)&&<button disabled={busy===a.id} onClick={()=>cancel(a)} className="mt-3 inline-flex min-h-10 items-center gap-1 rounded-lg border px-3 text-xs font-semibold text-destructive"><XCircle className="h-4 w-4"/> অ্যাপয়েন্টমেন্ট বাতিল করুন</button>}</div>)}</div>}
 </div>;
}
