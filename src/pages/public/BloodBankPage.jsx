import { useEffect, useState } from "react";
import { Droplets, MapPin, Phone, Send, ShieldCheck, Clock3, UserRound } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { useVisitorLocation } from "@/hooks/useVisitorLocation";
import { useBloodDonors, BLOOD_GROUPS, createBloodRequest } from "@/hooks/useBloodBank";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";

export default function BloodBankPage() {
  const { isLoggedIn, profile } = useAuth();
  const { location } = useVisitorLocation();
  const [group, setGroup] = useState("");
  const { donors, loading, error } = useBloodDonors({ bloodGroup: group, latitude: location.latitude, longitude: location.longitude });
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState({ neededDate:"", neededTime:"", reason:"", hospitalName:"", locationText:"" });
  const [sending, setSending] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => { document.title = "রক্ত ব্যাংক — সিরাজগঞ্জ ডাক্তার"; }, []);

  async function sendRequest() {
    if (!selected || !isLoggedIn || !profile?.full_name || !selected.phone) return;
    setSending(true); setMessage("");
    const { error: requestError } = await createBloodRequest({
      donorId:selected.id, bloodGroup:selected.blood_group, patientName:profile.full_name,
      patientPhone:profile.phone, ...form,
    });
    setSending(false);
    if (requestError) setMessage(requestError.message);
    else { setMessage("রক্তের অনুরোধ পাঠানো হয়েছে।"); setSelected(null); setForm({neededDate:"",neededTime:"",reason:"",hospitalName:"",locationText:""}); }
  }

  return <div className="container max-w-5xl py-6 md:py-10">
    <div className="rounded-2xl border bg-card p-5 shadow-sm">
      <div className="flex items-start gap-3">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-red-50 text-red-600"><Droplets /></span>
        <div><h1 className="text-xl font-bold">রক্তদাতা খুঁজুন</h1><p className="mt-1 text-sm text-muted-foreground">শুধু স্বেচ্ছাসেবী ও সক্রিয় রক্তদাতাদের তালিকা দেখানো হবে।</p></div>
      </div>
      <div className="mt-4 flex gap-2 overflow-x-auto pb-1 no-scrollbar">
        <Button size="sm" variant={!group ? "default" : "outline"} onClick={()=>setGroup("")}>সব গ্রুপ</Button>
        {BLOOD_GROUPS.map(g=><Button key={g} size="sm" variant={group===g?"default":"outline"} onClick={()=>setGroup(g)}>{g}</Button>)}
      </div>
    </div>

    {!isLoggedIn && <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">দাতাকে রক্তের অনুরোধ পাঠাতে আগে রোগী হিসেবে লগইন করুন।</div>}
    {error && <div className="mt-4 rounded-xl bg-destructive/10 p-3 text-sm text-destructive">রক্তদাতার তালিকা লোড করা যায়নি।</div>}

    <div className="mt-5 space-y-3">
      {loading && <div className="rounded-xl border p-6 text-center text-sm text-muted-foreground">রক্তদাতা খোঁজা হচ্ছে...</div>}
      {!loading && !donors.length && <div className="rounded-xl border p-8 text-center text-sm text-muted-foreground">এই মুহূর্তে এই গ্রুপের কোনো সক্রিয় স্বেচ্ছাসেবী রক্তদাতা পাওয়া যায়নি।</div>}
      {donors.map(d=><div key={d.id} className="rounded-2xl border bg-card p-4 shadow-sm">
        <div className="flex items-start gap-3">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-red-50 text-red-600"><UserRound /></span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2"><h2 className="font-semibold">{d.full_name || "স্বেচ্ছাসেবী রক্তদাতা"}</h2><span className="rounded-full bg-red-50 px-2 py-0.5 text-xs font-bold text-red-600">{d.blood_group}</span><ShieldCheck className="h-4 w-4 text-primary" /></div>
            <div className="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted-foreground">
              {(d.location_upazila || d.location_district) && <span className="flex items-center gap-1"><MapPin className="h-3.5 w-3.5" />{[d.location_upazila,d.location_district].filter(Boolean).join(", ")}</span>}
              {d.distance_km != null && <span>{d.distance_km < 1 ? `${Math.round(d.distance_km*1000)} মিটার দূরে` : `${d.distance_km.toFixed(1)} কিমি দূরে`}</span>}
              {d.last_blood_donation_date && <span className="flex items-center gap-1"><Clock3 className="h-3.5 w-3.5" />শেষ রক্তদান: {d.last_blood_donation_date}</span>}
            </div>
          </div>
        </div>
        <div className="mt-3 flex gap-2">
          {d.phone ? <a href={`tel:${d.phone}`} className="inline-flex h-9 items-center gap-1 rounded-lg border px-3 text-sm font-medium"><Phone className="h-4 w-4" /> {d.phone}</a> : <Button size="sm" variant="outline" disabled>ফোন নম্বর গোপন</Button>}
          <Button size="sm" onClick={()=>setSelected(d)}><Send className="h-4 w-4" /> রক্তের অনুরোধ</Button>
        </div>
      </div>)}
    </div>

    <Dialog open={!!selected} onOpenChange={(open)=>!open&&setSelected(null)}>
      <DialogContent className="max-h-[90vh] w-[calc(100%-24px)] max-w-lg overflow-y-auto rounded-2xl bg-card p-5">
        <DialogTitle>রক্তের অনুরোধ পাঠান</DialogTitle>
        <DialogDescription>{selected?.full_name} — {selected?.blood_group}</DialogDescription>
        <div className="mt-4 space-y-3">
          <div className="grid grid-cols-2 gap-2"><Input type="date" value={form.neededDate} onChange={e=>setForm({...form,neededDate:e.target.value})} /><Input placeholder="কখন (যেমন: সন্ধ্যা ৭টা)" value={form.neededTime} onChange={e=>setForm({...form,neededTime:e.target.value})}/></div>
          <Input placeholder="কোথায় / হাসপাতালের নাম" value={form.hospitalName} onChange={e=>setForm({...form,hospitalName:e.target.value})}/>
          <Input placeholder="রোগীর/রক্তের প্রয়োজনের স্থান" value={form.locationText} onChange={e=>setForm({...form,locationText:e.target.value})}/>
          <textarea className="min-h-24 w-full rounded-lg border bg-background p-3 text-sm" placeholder="কার জন্য ও কেন রক্ত লাগবে লিখুন" value={form.reason} onChange={e=>setForm({...form,reason:e.target.value})}/>
          {message && <p className="text-sm text-destructive">{message}</p>}
          {!isLoggedIn ? <p className="text-sm text-muted-foreground">অনুরোধ পাঠাতে রোগী হিসেবে লগইন করুন।</p> : <Button className="w-full" onClick={sendRequest} disabled={sending || !form.reason}>{sending ? "পাঠানো হচ্ছে..." : "অনুরোধ পাঠান"}</Button>}
        </div>
      </DialogContent>
    </Dialog>
  </div>;
}
