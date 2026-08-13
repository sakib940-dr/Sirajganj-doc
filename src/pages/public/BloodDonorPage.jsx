import { useEffect, useState } from "react";
import { Droplets, Phone, Save } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { BLOOD_GROUPS, updateDonorSettings } from "@/hooks/useBloodBank";
import { Button } from "@/components/ui/button";

export default function BloodDonorPage() {
  const { user, profile, refreshProfile } = useAuth();
  const [form, setForm] = useState({ blood_group:"", blood_donor_volunteer:false, blood_public_phone:false, last_blood_donation_date:"" });
  const [saving, setSaving] = useState(false); const [message,setMessage]=useState("");
  useEffect(()=>{ if(profile) setForm({blood_group:profile.blood_group||"",blood_donor_volunteer:!!profile.blood_donor_volunteer,blood_public_phone:!!profile.blood_public_phone,last_blood_donation_date:profile.last_blood_donation_date||""}); },[profile]);
  async function save(){ setSaving(true); setMessage(""); const {error}=await updateDonorSettings(user.id,{...form,blood_donor_updated_at:new Date().toISOString()}); setSaving(false); if(error) setMessage(error.message); else { await refreshProfile(); setMessage("রক্তদাতা তথ্য সংরক্ষণ হয়েছে।"); } }
  return <div className="container max-w-xl py-6 md:py-10"><div className="rounded-2xl border bg-card p-5 shadow-sm"><div className="flex items-start gap-3"><span className="flex h-11 w-11 items-center justify-center rounded-full bg-red-50 text-red-600"><Droplets/></span><div><h1 className="text-xl font-bold">স্বেচ্ছাসেবী রক্তদাতা</h1><p className="mt-1 text-sm text-muted-foreground">রক্তের প্রয়োজনে অন্য রোগীরা যেন আপনার সাথে যোগাযোগ করতে পারেন।</p></div></div>
  <div className="mt-5 space-y-4"><label className="block text-sm font-medium">রক্তের গ্রুপ<select className="mt-1 h-10 w-full rounded-lg border bg-background px-3" value={form.blood_group} onChange={e=>setForm({...form,blood_group:e.target.value})}><option value="">নির্বাচন করুন</option>{BLOOD_GROUPS.map(g=><option key={g}>{g}</option>)}</select></label>
  <label className="block text-sm font-medium">শেষ কবে রক্ত দিয়েছেন<input type="date" className="mt-1 h-10 w-full rounded-lg border bg-background px-3" value={form.last_blood_donation_date} onChange={e=>setForm({...form,last_blood_donation_date:e.target.value})}/></label>
  <label className="flex items-center gap-3 rounded-xl border p-3"><input type="checkbox" checked={form.blood_donor_volunteer} onChange={e=>setForm({...form,blood_donor_volunteer:e.target.checked})}/><span><b>আমি স্বেচ্ছাসেবী রক্তদাতা হতে চাই</b><small className="block text-muted-foreground">সক্রিয় করলে আপনার নাম ও রক্তের গ্রুপ ডিরেক্টরিতে দেখা যাবে।</small></span></label>
  <label className="flex items-center gap-3 rounded-xl border p-3"><input type="checkbox" checked={form.blood_public_phone} disabled={!form.blood_donor_volunteer} onChange={e=>setForm({...form,blood_public_phone:e.target.checked})}/><span><b className="flex items-center gap-1"><Phone className="h-4 w-4"/> ফোন নম্বর প্রকাশ করুন</b><small className="block text-muted-foreground">বন্ধ রাখলে ফোন ও সরাসরি রক্তের অনুরোধ বন্ধ থাকবে।</small></span></label>
  {message&&<p className="text-sm text-primary">{message}</p>}<Button className="w-full" onClick={save} disabled={saving||!form.blood_group||!form.blood_donor_volunteer}><Save className="h-4 w-4"/>{saving?"সংরক্ষণ হচ্ছে...":"তথ্য সংরক্ষণ করুন"}</Button></div>
 </div></div>;
}
