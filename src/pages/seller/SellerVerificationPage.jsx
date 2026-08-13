import { useEffect, useState } from "react";
import { Save, Check, Clock, XCircle, BadgeCheck, RefreshCcw, Lock } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import { VERIFICATION_STATUS, VERIFICATION_STATUS_LABEL_BN } from "@/constants/roles";

const EMPTY={full_name:"",profile_photo_url:"",phone:"",address:"",google_map_link:"",facebook_link:"",
nid_number:"",nid_front_url:"",nid_back_url:"",degree:"",specialty:"",designation:"",
bmdc_registration_no:"",bmdc_document_url:"",chamber_name:"",chamber_address:"",
visiting_days:"",visiting_time:"",consultation_fee:""};
const PROFILE_MAX=1024, DOC_MAX=1024;

export default function SellerVerificationPage(){
  const {user,profile}=useAuth();
  const [form,setForm]=useState(EMPTY),[status,setStatus]=useState(null),[note,setNote]=useState("");
  const [loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[saved,setSaved]=useState(false),[error,setError]=useState("");
  const update=(k,v)=>setForm(f=>({...f,[k]:v}));

  const load=async()=>{
    if(!user)return;
    setLoading(true);
    const {data}=await supabase.from("seller_verifications").select("*").eq("user_id",user.id).maybeSingle();
    if(data){setForm({...EMPTY,...data});setStatus(data.status);setNote(data.admin_note||"");}
    else setForm(f=>({...f,full_name:profile?.full_name||"",phone:profile?.phone||""}));
    setLoading(false);
  };
  useEffect(()=>{load()},[user]);

  const submit=async(e)=>{
    e.preventDefault();setError("");setSaved(false);
    if(!form.full_name.trim()||!form.phone.trim()||!form.degree.trim()||!form.specialty.trim()||!form.bmdc_registration_no.trim()||!form.nid_number.trim()||!form.nid_front_url||!form.nid_back_url){
      setError("নাম, ফোন, Degree, বিশেষত্ব, BMDC registration এবং NID-এর তথ্য সম্পূর্ণ দিন।");return;
    }
    setSaving(true);
    const payload={...form,user_id:user.id,consultation_fee:form.consultation_fee===""?null:Number(form.consultation_fee)};
    const {data,error:err}=await supabase.from("seller_verifications").upsert(payload,{onConflict:"user_id"}).select().single();
    if(err)setError("সংরক্ষণ ব্যর্থ হয়েছে: "+err.message);
    else{setForm({...EMPTY,...data});setStatus(data.status);setNote(data.admin_note||"");setSaved(true);setTimeout(()=>setSaved(false),2500);}
    setSaving(false);
  };

  if(loading)return <LoadingSpinner label="Doctor verification তথ্য লোড হচ্ছে..."/>;
  const approved=status===VERIFICATION_STATUS.APPROVED,rejected=status===VERIFICATION_STATUS.REJECTED;
  return <div className="max-w-2xl space-y-6">
    <div><h1 className="text-xl font-bold" style={{fontFamily:"'Tiro Bangla', serif"}}>ডাক্তার ভেরিফিকেশন</h1>
      <p className="text-sm text-muted-foreground">আপনার পেশাগত পরিচয় ও BMDC তথ্য যাচাই করে অনুমোদিত ডাক্তার প্রোফাইল প্রকাশ করা হবে।</p></div>

    {status&&<div className={`flex items-center gap-3 rounded-xl border p-4 text-sm ${approved?"border-primary/30 bg-primary/10":rejected?"border-destructive/30 bg-destructive/10":"border-accent/40 bg-accent/10"}`}>
      {approved?<BadgeCheck className="h-5 w-5 text-primary"/>:rejected?<XCircle className="h-5 w-5 text-destructive"/>:<Clock className="h-5 w-5 text-accent"/>}
      <span>ভেরিফিকেশন অবস্থা: <b>{VERIFICATION_STATUS_LABEL_BN[status]}</b>{rejected&&note?` — ${note}`:""}</span>
    </div>}

    {rejected&&<Button variant="outline" onClick={()=>setStatus(null)}><RefreshCcw className="h-4 w-4"/> তথ্য সংশোধন করুন</Button>}

    <form onSubmit={submit} className="space-y-5">
      <Card><CardHeader><CardTitle className="text-base">ব্যক্তিগত তথ্য</CardTitle></CardHeader><CardContent className="space-y-4">
        <div><Label>প্রোফাইল ছবি *</Label><ImageUploader bucket="seller-verification" folder={user.id} value={form.profile_photo_url} onUploaded={u=>update("profile_photo_url",u)} maxSizeKB={PROFILE_MAX}/></div>
        <div className="grid gap-4 sm:grid-cols-2"><div><Label>পূর্ণ নাম *</Label><Input required value={form.full_name} onChange={e=>update("full_name",e.target.value)}/></div><div><Label>মোবাইল নম্বর *</Label><Input required value={form.phone} onChange={e=>update("phone",e.target.value)}/></div></div>
        <div><Label>ঠিকানা</Label><Input value={form.address||""} onChange={e=>update("address",e.target.value)}/></div>
        <div><Label>গুগল ম্যাপ লিংক</Label><Input value={form.google_map_link||""} onChange={e=>update("google_map_link",e.target.value)}/></div>
        <div><Label>ফেসবুক প্রোফাইল</Label><Input value={form.facebook_link||""} onChange={e=>update("facebook_link",e.target.value)}/></div>
      </CardContent></Card>

      <Card><CardHeader><CardTitle className="text-base">পেশাগত তথ্য</CardTitle></CardHeader><CardContent className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2"><div><Label>ডিগ্রি *</Label><Input required placeholder="MBBS, BDS, FCPS" value={form.degree} onChange={e=>update("degree",e.target.value)}/></div><div><Label>পদবি</Label><Input placeholder="Consultant / Professor" value={form.designation||""} onChange={e=>update("designation",e.target.value)}/></div></div>
        <div className="grid gap-4 sm:grid-cols-2"><div><Label>বিশেষত্ব *</Label><Input required placeholder="হৃদরোগ / দন্ত চিকিৎসা" value={form.specialty} onChange={e=>update("specialty",e.target.value)}/></div><div><Label>বিএমডিসি রেজিস্ট্রেশন নম্বর *</Label><Input required value={form.bmdc_registration_no} onChange={e=>update("bmdc_registration_no",e.target.value)}/></div></div>
        <div><Label>বিএমডিসি ডকুমেন্ট</Label><ImageUploader bucket="seller-verification" folder={user.id} value={form.bmdc_document_url} onUploaded={u=>update("bmdc_document_url",u)} maxSizeKB={DOC_MAX}/></div>
      </CardContent></Card>

      <Card><CardHeader><CardTitle className="text-base">চেম্বারের তথ্য</CardTitle><CardDescription>বর্তমান/প্রধান Chamber-এর তথ্য দিন।</CardDescription></CardHeader><CardContent className="space-y-4">
        <div><Label>চেম্বারের নাম</Label><Input value={form.chamber_name||""} onChange={e=>update("chamber_name",e.target.value)}/></div>
        <div><Label>চেম্বারের ঠিকানা</Label><Input value={form.chamber_address||""} onChange={e=>update("chamber_address",e.target.value)}/></div>
        <div className="grid gap-4 sm:grid-cols-2"><div><Label>রোগী দেখার দিন</Label><Input value={form.visiting_days||""} onChange={e=>update("visiting_days",e.target.value)}/></div><div><Label>রোগী দেখার সময়</Label><Input value={form.visiting_time||""} onChange={e=>update("visiting_time",e.target.value)}/></div></div>
        <div><Label>পরামর্শ ফি (৳)</Label><Input type="number" min="0" value={form.consultation_fee||""} onChange={e=>update("consultation_fee",e.target.value)}/></div>
      </CardContent></Card>

      <Card><CardHeader><CardTitle className="text-base">এনআইডি যাচাই</CardTitle><CardDescription>এনআইডি তথ্য শুধু verification-এর জন্য ব্যবহৃত হবে।</CardDescription></CardHeader><CardContent className="space-y-4">
        <div><Label>এনআইডি নম্বর *</Label><Input required value={form.nid_number} onChange={e=>update("nid_number",e.target.value)}/></div>
        <div className="flex flex-wrap gap-6"><div><Label>এনআইডি সামনে *</Label><ImageUploader bucket="seller-verification" folder={user.id} value={form.nid_front_url} onUploaded={u=>update("nid_front_url",u)} maxSizeKB={DOC_MAX} aspect="wide"/></div><div><Label>এনআইডি পেছনে *</Label><ImageUploader bucket="seller-verification" folder={user.id} value={form.nid_back_url} onUploaded={u=>update("nid_back_url",u)} maxSizeKB={DOC_MAX} aspect="wide"/></div></div>
      </CardContent></Card>

      {error&&<p className="text-sm text-destructive">{error}</p>}
      {approved?<p className="flex items-center gap-2 text-xs text-muted-foreground"><Lock className="h-3.5 w-3.5"/> Approved verification সরাসরি পরিবর্তন করা যাবে না। Admin-এর সাথে যোগাযোগ করুন।</p>:
      <Button type="submit" disabled={saving} size="lg">{saved?<Check className="h-4 w-4"/>:<Save className="h-4 w-4"/>}{saving?"সংরক্ষণ হচ্ছে...":saved?"সংরক্ষিত হয়েছে":"Verification জমা দিন"}</Button>}
    </form>
  </div>;
}
