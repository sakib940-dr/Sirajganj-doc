import { useEffect, useState } from "react";
import { Droplets, Phone, Save, BellRing, MapPin } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { BLOOD_GROUPS, updateDonorSettings } from "@/hooks/useBloodBank";
import { Button } from "@/components/ui/button";

export default function BloodDonorPage() {
  const { user, profile, refreshProfile } = useAuth();
  const [form,setForm]=useState({blood_group:"",blood_donor_volunteer:false,blood_public_phone:false,blood_accept_requests:true,blood_is_available:true,last_blood_donation_date:"",blood_address:""});
  const [saving,setSaving]=useState(false); const [message,setMessage]=useState("");
  useEffect(()=>{if(profile)setForm({blood_group:profile.blood_group||"",blood_donor_volunteer:!!profile.blood_donor_volunteer,blood_public_phone:!!profile.blood_public_phone,blood_accept_requests:profile.blood_accept_requests!==false,blood_is_available:profile.blood_is_available!==false,last_blood_donation_date:profile.last_blood_donation_date||"",blood_address:profile.blood_address||profile.address||""});},[profile]);
  async function save(){
    if(form.blood_donor_volunteer&&!form.blood_group){setMessage("রক্তের গ্রুপ নির্বাচন করুন।");return;}
    setSaving(true);setMessage("");
    const payload={...form,blood_donor_updated_at:new Date().toISOString()};
    if(!form.blood_donor_volunteer){payload.blood_public_phone=false;payload.blood_accept_requests=false;payload.blood_is_available=false;}
    const {error}=await updateDonorSettings(user.id,payload);setSaving(false);
    if(error)setMessage(error.message);else{await refreshProfile();setMessage(form.blood_donor_volunteer?"রক্তদাতা তথ্য সংরক্ষণ হয়েছে।":"আপনার রক্তদাতা অবস্থা বন্ধ করা হয়েছে।");}
  }
  const active=form.blood_donor_volunteer;
  return <div className="container max-w-xl py-6 md:py-10"><div className="rounded-2xl border bg-card p-5 shadow-sm">
    <div className="flex items-start gap-3"><span className="flex h-11 w-11 items-center justify-center rounded-full bg-red-50 text-red-600"><Droplets/></span><div><h1 className="text-xl font-bold">স্বেচ্ছাসেবী রক্তদাতা</h1><p className="mt-1 text-sm text-muted-foreground">আপনি কখন রক্তের অনুরোধ গ্রহণ করবেন এবং ফোন প্রকাশ করবেন—দুটো আলাদাভাবে নিয়ন্ত্রণ করুন।</p></div></div>
    <div className="mt-5 space-y-4">
      <label className="block text-sm font-medium">রক্তের গ্রুপ<select className="mt-1 h-10 w-full rounded-lg border bg-background px-3" value={form.blood_group} onChange={e=>setForm({...form,blood_group:e.target.value})}><option value="">নির্বাচন করুন</option>{BLOOD_GROUPS.map(g=><option key={g}>{g}</option>)}</select></label>
      <label className="block text-sm font-medium"><span className="flex items-center gap-1"><MapPin className="h-4 w-4"/>ঠিকানা</span><textarea rows={3} className="mt-1 w-full rounded-lg border bg-background p-3" value={form.blood_address} onChange={e=>setForm({...form,blood_address:e.target.value})} placeholder="রক্তদানের জন্য যোগাযোগযোগ্য এলাকা/ঠিকানা"/></label>
      <label className="block text-sm font-medium">শেষ কবে রক্ত দিয়েছেন<input type="date" className="mt-1 h-10 w-full rounded-lg border bg-background px-3" value={form.last_blood_donation_date} onChange={e=>setForm({...form,last_blood_donation_date:e.target.value})}/></label>
      <label className="flex items-center gap-3 rounded-xl border p-3"><input type="checkbox" checked={active} onChange={e=>setForm({...form,blood_donor_volunteer:e.target.checked,blood_is_available:e.target.checked?true:false,blood_accept_requests:e.target.checked?true:false,blood_public_phone:e.target.checked?form.blood_public_phone:false})}/><span><b>আমি স্বেচ্ছাসেবী রক্তদাতা হিসেবে তালিকাভুক্ত থাকব</b><small className="block text-muted-foreground">বন্ধ করলে আপনার donor listing ও নতুন request গ্রহণ বন্ধ হবে।</small></span></label>
      <label className="flex items-center gap-3 rounded-xl border p-3"><input type="checkbox" checked={form.blood_is_available} disabled={!active} onChange={e=>setForm({...form,blood_is_available:e.target.checked})}/><span><b>এই মুহূর্তে রক্ত দিতে উপলভ্য</b><small className="block text-muted-foreground">সাময়িকভাবে unavailable হলে এটি বন্ধ রাখুন।</small></span></label>
      <label className="flex items-center gap-3 rounded-xl border p-3"><input type="checkbox" checked={form.blood_accept_requests} disabled={!active} onChange={e=>setForm({...form,blood_accept_requests:e.target.checked})}/><span><b className="flex items-center gap-1"><BellRing className="h-4 w-4"/> রক্তের অনুরোধ গ্রহণ করব</b><small className="block text-muted-foreground">ফোন গোপন রেখেও অ্যাপের মাধ্যমে request গ্রহণ করতে পারবেন।</small></span></label>
      <label className="flex items-center gap-3 rounded-xl border p-3"><input type="checkbox" checked={form.blood_public_phone} disabled={!active} onChange={e=>setForm({...form,blood_public_phone:e.target.checked})}/><span><b className="flex items-center gap-1"><Phone className="h-4 w-4"/> ফোন নম্বর প্রকাশ করুন</b><small className="block text-muted-foreground">বন্ধ রাখলে ফোন নম্বর public list-এ দেখা যাবে না; request preference আলাদা।</small></span></label>
      {message&&<p className="text-sm text-primary">{message}</p>}
      <Button className="w-full" onClick={save} disabled={saving||(active&&!form.blood_group)}><Save className="h-4 w-4"/>{saving?"সংরক্ষণ হচ্ছে...":"তথ্য সংরক্ষণ করুন"}</Button>
    </div>
  </div></div>;
}
