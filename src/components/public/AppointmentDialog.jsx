import { useState } from "react";
import { CalendarDays, X } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { createAppointment } from "@/hooks/useAppointments";

export default function AppointmentDialog({ doctor, chamber, onClose, onCreated }) {
  const { user, role, profile } = useAuth();
  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  if (!user || role !== "patient") {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
        <div className="w-full max-w-md rounded-2xl bg-card p-6 shadow-xl">
          <h2 className="text-lg font-bold">Appointment নিতে Patient account প্রয়োজন</h2>
          <p className="mt-2 text-sm text-muted-foreground">আগে Patient হিসেবে login/register করুন।</p>
          <button onClick={onClose} className="mt-5 w-full rounded-xl bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground">ঠিক আছে</button>
        </div>
      </div>
    );
  }

  async function submit(e) {
    e.preventDefault();
    if (!date) { setMessage("তারিখ নির্বাচন করুন।"); return; }
    setBusy(true); setMessage("");
    const { error } = await createAppointment({
      doctorId: doctor.doctor_id,
      patientId: user.id,
      productId: doctor.id,
      shopId: chamber?.id,
      date, time, note,
      patientName: profile?.full_name,
      patientPhone: profile?.phone,
    });
    setBusy(false);
    if (error) { setMessage(error.message); return; }
    onCreated?.();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-2xl bg-card p-5 shadow-xl">
        <div className="flex items-center justify-between">
          <div><h2 className="text-lg font-bold">Appointment Request</h2><p className="text-sm text-muted-foreground">{doctor.name}</p></div>
          <button onClick={onClose} className="rounded-full p-2 hover:bg-secondary"><X className="h-5 w-5"/></button>
        </div>
        <form onSubmit={submit} className="mt-5 space-y-4">
          <label className="block text-sm font-medium">তারিখ<input type="date" min={new Date().toISOString().slice(0,10)} value={date} onChange={e=>setDate(e.target.value)} className="mt-1 w-full rounded-xl border bg-background px-3 py-3"/></label>
          <label className="block text-sm font-medium">পছন্দের সময় (ঐচ্ছিক)<input type="time" value={time} onChange={e=>setTime(e.target.value)} className="mt-1 w-full rounded-xl border bg-background px-3 py-3"/></label>
          <label className="block text-sm font-medium">নোট (ঐচ্ছিক)<textarea value={note} onChange={e=>setNote(e.target.value)} placeholder="যেমন: প্রথমবার দেখাবো / পুরোনো রিপোর্ট আছে" className="mt-1 min-h-24 w-full rounded-xl border bg-background px-3 py-3"/></label>
          {message && <p className="rounded-xl bg-destructive/10 p-3 text-sm text-destructive">{message}</p>}
          <button disabled={busy} className="flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 font-semibold text-primary-foreground disabled:opacity-60"><CalendarDays className="h-4 w-4"/>{busy ? "পাঠানো হচ্ছে..." : "Appointment Request পাঠান"}</button>
        </form>
      </div>
    </div>
  );
}
