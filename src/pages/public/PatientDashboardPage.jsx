import { Link } from "react-router-dom";
import { CalendarDays, Heart, Search, UserRound, LogOut, Droplets, Ambulance, Bell, CheckCircle2, XCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useAuth } from "@/hooks/useAuth";
import { ROUTES } from "@/constants/routes";
import { useBloodRequests, updateBloodRequestStatus } from "@/hooks/useBloodBank";

const BLOOD_STATUS_LABEL = { pending:"অপেক্ষমাণ", accepted:"গৃহীত", declined:"প্রত্যাখ্যাত", cancelled:"বাতিল", completed:"সম্পন্ন" };

function IncomingBloodRequests({ requests, loading, refresh }) {
  async function change(id, status) { const { error } = await updateBloodRequestStatus(id, status); if (error) window.alert(error.message); else refresh(); }
  return <div className="mt-6 rounded-2xl border border-red-100 bg-card p-5 shadow-sm">
    <div className="flex items-center gap-2"><Bell className="h-5 w-5 text-red-600"/><h2 className="font-semibold">আমার কাছে আসা রক্তের অনুরোধ</h2></div>
    <p className="mt-1 text-xs text-muted-foreground">আপনার কাছে পাঠানো রক্তের অনুরোধের অবস্থা এখান থেকে পরিচালনা করুন।</p>
    {loading ? <p className="mt-4 text-sm text-muted-foreground">লোড হচ্ছে...</p> : !requests.length ? <p className="mt-4 text-sm text-muted-foreground">এখনো কোনো রক্তের অনুরোধ আসেনি।</p> : <div className="mt-4 space-y-3">{requests.slice(0,10).map(r=><div key={r.id} className="rounded-xl border p-3">
      <div className="flex items-start justify-between gap-3"><div><p className="font-semibold">{r.patient_name} • {r.blood_group}</p><p className="mt-1 text-xs text-muted-foreground">{r.request_number ? `#${r.request_number} • ` : ""}{r.needed_date || "তারিখ নির্ধারিত নয়"}{r.needed_time?` • ${r.needed_time}`:""}</p><p className="mt-2 text-sm">{r.reason}</p>{r.patient_phone&&<p className="mt-1 text-xs text-muted-foreground">যোগাযোগ: <a className="font-medium text-primary underline-offset-2 hover:underline" href={`tel:${r.patient_phone}`}>{r.patient_phone}</a></p>}{r.hospital_name&&<p className="mt-1 text-xs text-muted-foreground">স্থান: {r.hospital_name}{r.location_text?` — ${r.location_text}`:""}</p>}</div><span className="rounded-full bg-secondary px-2 py-1 text-xs">{BLOOD_STATUS_LABEL[r.status]||r.status}</span></div>
      {r.status==='pending'&&<div className="mt-3 flex flex-wrap gap-2"><button onClick={()=>change(r.id,'accepted')} className="inline-flex items-center gap-1 rounded-lg bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground"><CheckCircle2 className="h-4 w-4"/> গ্রহণ</button><button onClick={()=>change(r.id,'declined')} className="inline-flex items-center gap-1 rounded-lg border px-3 py-2 text-xs font-semibold"><XCircle className="h-4 w-4"/> প্রত্যাখ্যান</button></div>}
      {r.status==='accepted'&&<button onClick={()=>change(r.id,'completed')} className="mt-3 inline-flex items-center gap-1 rounded-lg bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground"><CheckCircle2 className="h-4 w-4"/> রক্তদান সম্পন্ন</button>}
    </div>)}</div>}
  </div>;
}

export default function PatientDashboardPage() {
  const { profile, user, signOut } = useAuth();
  const { requests, loading: bloodLoading, refresh: refreshOutgoing } = useBloodRequests({ userId: user?.id, role: "patient" });
  const { requests: incomingBloodRequests, loading: incomingLoading, refresh: refreshIncoming } = useBloodRequests({ userId: user?.id, role: "patient", mode: "donor", enabled: !!profile?.blood_donor_volunteer });

  return (
    <div className="container mx-auto max-w-5xl px-4 py-6">
      <div className="mb-6 flex flex-col gap-4 rounded-2xl border bg-card p-5 shadow-sm sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm text-muted-foreground">রোগী ড্যাশবোর্ড</p>
          <h1 className="mt-1 text-2xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
            স্বাগতম, {profile?.full_name || "রোগী"}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">আপনার ডাক্তার ও অ্যাপয়েন্টমেন্ট এক জায়গায় দেখুন।</p>
        </div>
        <Button variant="outline" onClick={signOut} className="gap-2 self-start sm:self-auto">
          <LogOut className="h-4 w-4" /> লগআউট
        </Button>
      </div>

      <div className="mb-4 rounded-xl border bg-card p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div><p className="text-sm font-semibold">রক্তদাতা অবস্থা</p><p className="mt-1 text-xs text-muted-foreground">{profile?.blood_donor_volunteer ? `সক্রিয় • ${profile?.blood_group || "গ্রুপ সেট করুন"}` : "আপনি এখনো স্বেচ্ছাসেবী রক্তদাতা নন"}</p></div>
          <Link to={ROUTES.BLOOD_DONOR} className="rounded-lg border px-3 py-2 text-xs font-semibold">তথ্য সেট করুন</Link>
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Link to={ROUTES.BLOOD_BANK}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md"><CardHeader><Droplets className="h-6 w-6 text-red-600" /><CardTitle className="text-base">রক্ত খুঁজুন</CardTitle></CardHeader><CardContent><p className="text-sm text-muted-foreground">রক্তের গ্রুপ ও কাছাকাছি স্বেচ্ছাসেবী দাতা খুঁজুন।</p></CardContent></Card>
        </Link>
        <Link to={ROUTES.BLOOD_DONOR}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md"><CardHeader><Droplets className="h-6 w-6 text-red-600" /><CardTitle className="text-base">রক্তদাতা হোন</CardTitle></CardHeader><CardContent><p className="text-sm text-muted-foreground">আপনার রক্তের গ্রুপ, শেষ রক্তদান ও যোগাযোগের তথ্য সেট করুন।</p></CardContent></Card>
        </Link>
        <Link to={ROUTES.AMBULANCE}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md"><CardHeader><Ambulance className="h-6 w-6 text-primary" /><CardTitle className="text-base">অ্যাম্বুলেন্স</CardTitle></CardHeader><CardContent><p className="text-sm text-muted-foreground">কাছাকাছি অ্যাম্বুলেন্স সার্ভিস ও দিকনির্দেশনা দেখুন।</p></CardContent></Card>
        </Link>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Link to={ROUTES.DOCTORS}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><Search className="h-6 w-6 text-primary" /><CardTitle className="text-base">ডাক্তার খুঁজুন</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">বিশেষত্ব ও এলাকার ভিত্তিতে ডাক্তার দেখুন।</p></CardContent>
          </Card>
        </Link>
        <Link to={ROUTES.APPOINTMENTS}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><CalendarDays className="h-6 w-6 text-primary" /><CardTitle className="text-base">অ্যাপয়েন্টমেন্ট</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">আপনার অনুরোধ ও অ্যাপয়েন্টমেন্টের অবস্থা দেখুন।</p></CardContent>
          </Card>
        </Link>
        <Link to={ROUTES.SAVED}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><Heart className="h-6 w-6 text-primary" /><CardTitle className="text-base">সংরক্ষিত ডাক্তার</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">পছন্দের ডাক্তারগুলো দ্রুত খুঁজে নিন।</p></CardContent>
          </Card>
        </Link>
        <Link to={ROUTES.ACCOUNT}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><UserRound className="h-6 w-6 text-primary" /><CardTitle className="text-base">আমার প্রোফাইল</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">নাম, ফোন ও অ্যাকাউন্টের তথ্য আপডেট করুন।</p></CardContent>
          </Card>
        </Link>
      </div>

      {profile?.blood_donor_volunteer && <IncomingBloodRequests requests={incomingBloodRequests} loading={incomingLoading} refresh={refreshIncoming} />}

      <div className="mt-6 rounded-2xl border bg-card p-5 shadow-sm">
        <div className="flex items-center gap-2"><Bell className="h-5 w-5 text-primary"/><h2 className="font-semibold">আমার পাঠানো রক্তের অনুরোধ</h2></div>
        <p className="mt-1 text-xs text-muted-foreground">আপনি যেসব স্বেচ্ছাসেবী রক্তদাতাকে অনুরোধ পাঠিয়েছেন</p>
        {bloodLoading ? <p className="mt-4 text-sm text-muted-foreground">লোড হচ্ছে...</p> : !requests.length ? <p className="mt-4 text-sm text-muted-foreground">এখনো কোনো রক্তের অনুরোধ নেই।</p> : <div className="mt-4 space-y-2">{requests.slice(0,10).map(r=><div key={r.id} className="rounded-xl bg-secondary/60 p-3 text-sm"><div className="flex items-start justify-between gap-3"><span><b>{r.blood_group}</b>{r.request_number?` • #${r.request_number}`:""}<small className="block text-muted-foreground">{r.reason}</small>{r.donor_contact_phone&&['accepted','completed'].includes(r.status)&&<small className="mt-1 block text-muted-foreground">রক্তদাতার যোগাযোগ: <a className="font-semibold text-primary hover:underline" href={`tel:${r.donor_contact_phone}`}>{r.donor_contact_phone}</a></small>}</span><span className="rounded-full bg-background px-2 py-1 text-xs">{BLOOD_STATUS_LABEL[r.status]||r.status}</span></div>{['pending','accepted'].includes(r.status)&&<button onClick={async()=>{if(!window.confirm("রক্তের অনুরোধ বাতিল করবেন?"))return;const {error}=await updateBloodRequestStatus(r.id,'cancelled');if(error)window.alert(error.message);else refreshOutgoing();}} className="mt-2 rounded-lg border px-3 py-2 text-xs font-semibold text-destructive">অনুরোধ বাতিল করুন</button>}</div>)}</div>}
      </div>
    </div>
  );
}
