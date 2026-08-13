import { useAuth } from "@/hooks/useAuth";
import { useAppointments } from "@/hooks/useAppointments";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

const labels={pending:"অপেক্ষমাণ",confirmed:"নিশ্চিত",cancelled:"বাতিল",completed:"সম্পন্ন",rescheduled:"পুনঃনির্ধারিত"};

export default function PatientAppointmentsPage(){
 const {user,role}=useAuth();
 const {appointments,loading,error}=useAppointments({role,userId:user?.id,enabled:role==="patient"});
 if(loading)return <LoadingSpinner fullScreen label="Appointment লোড হচ্ছে..."/>;
 return <div className="container py-8"><h1 className="text-xl font-bold">আমার Appointment</h1><p className="mt-1 text-sm text-muted-foreground">আপনার appointment request ও status</p>
 {error&&<p className="mt-4 text-sm text-destructive">{error}</p>}
 {!appointments.length?<div className="mt-6 rounded-2xl border p-8 text-center text-sm text-muted-foreground">এখনো কোনো appointment নেই।</div>:
 <div className="mt-6 space-y-3">{appointments.map(a=><div key={a.id} className="rounded-2xl border bg-card p-4"><div className="flex justify-between gap-3"><div><p className="font-semibold">{a.doctor_name}</p><p className="mt-1 text-sm text-muted-foreground">{a.chamber_name||"চেম্বার"}</p><p className="mt-2 text-sm">{a.appointment_date}{a.appointment_time?` • ${a.appointment_time}`:""}</p></div><span className="h-fit rounded-full bg-secondary px-3 py-1 text-xs">{labels[a.status]||a.status}</span></div>{a.appointment_number&&<p className="mt-3 text-xs text-muted-foreground">#{a.appointment_number}</p>}</div>)}</div>}
 </div>
}
