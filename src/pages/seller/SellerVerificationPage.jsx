import { useEffect, useMemo, useState } from "react";
import { Save, Check, Clock, XCircle, BadgeCheck, RefreshCcw, Lock, ShieldCheck } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import { VERIFICATION_STATUS, VERIFICATION_STATUS_LABEL_BN, ROLES } from "@/constants/roles";

const EMPTY={
  full_name:"",profile_photo_url:"",phone:"",address:"",google_map_link:"",facebook_link:"",
  nid_number:"",nid_front_url:"",nid_back_url:"",degree:"",specialty:"",designation:"",
  bmdc_registration_no:"",bmdc_document_url:"",trade_license_no:"",trade_license_url:"",
  verification_type:"bmdc",chamber_name:"",chamber_address:"",visiting_days:"",visiting_time:"",consultation_fee:""
};
const PROFILE_MAX=1024, DOC_MAX=1024;

export default function SellerVerificationPage(){
  const {user,profile,role}=useAuth();
  const isHospital=role===ROLES.HOSPITAL;
  const [form,setForm]=useState(EMPTY),[status,setStatus]=useState(null),[note,setNote]=useState("");
  const [loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[saved,setSaved]=useState(false),[error,setError]=useState("");
  const [sectionSaving,setSectionSaving]=useState("");
  const [sectionSaved,setSectionSaved]=useState("");
  const draftKey=`doctor-verification-draft-${user?.id||"guest"}`;
  const update=(k,v)=>setForm(f=>({...f,[k]:v}));
  const draftSave=(next)=>{ try{localStorage.setItem(draftKey,JSON.stringify(next));}catch{} };
  const updateAndDraft=(k,v)=>setForm(f=>{const next={...f,[k]:v}; draftSave(next); return next;});

  const load=async()=>{
    if(!user)return;
    setLoading(true);
    const {data}=await supabase.from("seller_verifications").select("*").eq("user_id",user.id).order("created_at",{ascending:false}).limit(1).maybeSingle();
    let next=data?{...EMPTY,...data}:{...EMPTY,full_name:profile?.full_name||"",phone:profile?.phone||""};
    try{
      const raw=localStorage.getItem(draftKey);
      if(raw){ const draft=JSON.parse(raw); next={...next,...draft}; }
    }catch{}
    if(data){setStatus(data.status);setNote(data.admin_note||"");}
    setForm(next);
    setLoading(false);
  };
  useEffect(()=>{load()},[user]);

  const proofLabel=useMemo(()=>({bmdc:"বিএমডিসি রেজিস্ট্রেশন",trade_license:"ট্রেড লাইসেন্স",nid:"এনআইডি"}[form.verification_type]||"প্রমাণপত্র"),[form.verification_type]);

  const saveSection=async(name,fields)=>{
    if(!user || approved) return;
    setSectionSaving(name); setError(""); setSectionSaved("");
    const patch={user_id:user.id}; fields.forEach(k=>{ patch[k]=form[k]??null; });
    try{
      const {data:existing,error:findErr}=await supabase.from("seller_verifications").select("id,status").eq("user_id",user.id).order("created_at",{ascending:false}).limit(1).maybeSingle();
      if(findErr) throw findErr;
      let err;
      if(existing?.id){
        if(existing.status!=="pending") throw new Error("ভেরিফিকেশন আবেদন এখন পরিবর্তন করা যাচ্ছে না।");
        ({error:err}=await supabase.from("seller_verifications").update(patch).eq("id",existing.id));
      }else{
        ({error:err}=await supabase.from("seller_verifications").insert(patch));
      }
      if(err) throw err;
      try{localStorage.removeItem(draftKey);}catch{}
      setSectionSaved(name); setTimeout(()=>setSectionSaved(""),1800);
    }catch(e){setError("এই অংশ সংরক্ষণ করা যায়নি: "+e.message);}
    finally{setSectionSaving("");}
  };

  const submit=async(e)=>{
    e.preventDefault();setError("");setSaved(false);
    if(!form.full_name.trim()||!form.phone.trim()) { setError("নাম ও মোবাইল নম্বর অবশ্যই দিন।"); return; }
    if(isHospital){
      const hasProof = form.verification_type==="bmdc" ? form.bmdc_registration_no.trim() : form.verification_type==="trade_license" ? form.trade_license_no.trim() : form.nid_front_url;
      if(!form.chamber_name.trim()||!form.address.trim()||!hasProof){
        setError("হাসপাতালের নাম, ঠিকানা এবং নির্বাচিত ভেরিফিকেশন প্রমাণপত্র অবশ্যই দিতে হবে।");return;
      }
    }else if(!form.degree.trim()||!form.specialty.trim()||!form.bmdc_registration_no.trim()){
      setError("ডিগ্রি, বিশেষত্ব ও BMDC রেজিস্ট্রেশন নম্বর অবশ্যই দিতে হবে।");return;
    }
    setSaving(true);
    const payload={...form,user_id:user.id,consultation_fee:form.consultation_fee===""?null:Number(form.consultation_fee)};
    let data,err;
    const {data:existing,error:findErr}=await supabase.from("seller_verifications").select("id,status").eq("user_id",user.id).order("created_at",{ascending:false}).limit(1).maybeSingle();
    if(findErr) err=findErr;
    else if(existing?.id && existing.status==="pending") ({data,error:err}=await supabase.from("seller_verifications").update(payload).eq("id",existing.id).select().single());
    else if(existing?.id && existing.status==="under_review") err=new Error("ভেরিফিকেশন এখন অ্যাডমিন পর্যালোচনায় আছে; সিদ্ধান্তের আগে নতুন আবেদন করা যাবে না।");
    else if(existing?.id && existing.status==="approved") err=new Error("ভেরিফিকেশন ইতিমধ্যে অনুমোদিত।");
    else ({data,error:err}=await supabase.from("seller_verifications").insert(payload).select().single());
    if(err)setError("সংরক্ষণ ব্যর্থ হয়েছে: "+err.message);
    else{try{localStorage.removeItem(draftKey);}catch{} setForm({...EMPTY,...data});setStatus(data.status);setNote(data.admin_note||"");setSaved(true);setTimeout(()=>setSaved(false),2500);}
    setSaving(false);
  };

  if(loading)return <LoadingSpinner label="ভেরিফিকেশন তথ্য লোড হচ্ছে..."/>;
  const approved=status===VERIFICATION_STATUS.APPROVED,rejected=status===VERIFICATION_STATUS.REJECTED;
  return <div className="max-w-2xl space-y-4">
    <div><h1 className="text-xl font-bold" style={{fontFamily:"'Tiro Bangla', serif"}}>{isHospital?"চেম্বার / হাসপাতাল ভেরিফিকেশন":"ডাক্তার ভেরিফিকেশন"}</h1>
      <p className="text-sm text-muted-foreground">{isHospital?"হাসপাতালের পরিচয় ও বৈধ প্রমাণপত্র যাচাই করে প্রোফাইল প্রকাশ করা হবে।":"আপনার পেশাগত পরিচয় ও BMDC তথ্য যাচাই করে ডাক্তার প্রোফাইল প্রকাশ করা হবে।"}</p></div>

    {status&&<div className={`flex items-center gap-3 rounded-xl border p-3 text-sm ${approved?"border-primary/30 bg-primary/10":rejected?"border-destructive/30 bg-destructive/10":"border-accent/40 bg-accent/10"}`}>
      {approved?<BadgeCheck className="h-5 w-5 text-primary"/>:rejected?<XCircle className="h-5 w-5 text-destructive"/>:<Clock className="h-5 w-5 text-accent"/>}
      <span>ভেরিফিকেশন অবস্থা: <b>{VERIFICATION_STATUS_LABEL_BN[status]}</b>{rejected&&note?` — ${note}`:""}</span>
    </div>}

    {rejected&&<Button variant="outline" size="sm" onClick={()=>setStatus(null)}><RefreshCcw className="h-4 w-4"/> তথ্য সংশোধন করুন</Button>}

    <div className="rounded-xl border border-primary/15 bg-primary/5 px-3 py-2 text-xs text-muted-foreground">💾 প্রতিটি অংশ আলাদাভাবে সংরক্ষণ করতে পারবেন। টাইপ করার সময় অস্থায়ী ড্রাফটও ফোনে রাখা হয়, তাই ভুল করে রিফ্রেশ হলেও লেখা হারিয়ে যাবে না।</div>
    <form onSubmit={submit} className="space-y-3">
      <Card><CardHeader className="pb-3"><CardTitle className="text-base">১. {isHospital?"প্রতিষ্ঠানের তথ্য":"ব্যক্তিগত তথ্য"}</CardTitle></CardHeader><CardContent className="space-y-3">
        <div className="grid gap-3 sm:grid-cols-2"><div><Label>{isHospital?"প্রতিষ্ঠানের নাম":"পূর্ণ নাম"} *</Label><Input required value={form.full_name} onChange={e=>updateAndDraft("full_name",e.target.value)}/></div><div><Label>মোবাইল নম্বর *</Label><Input required value={form.phone} onChange={e=>updateAndDraft("phone",e.target.value)}/></div></div>
        <div><Label>{isHospital?"প্রতিষ্ঠানের প্রোফাইল ছবি":"প্রোফাইল ছবি"} *</Label><ImageUploader bucket="seller-verification" privateBucket folder={user.id} value={form.profile_photo_url} onUploaded={u=>updateAndDraft("profile_photo_url",u)} maxSizeKB={PROFILE_MAX}/></div>
        <div><Label>ঠিকানা *</Label><Input required={!isHospital?false:true} value={form.address||""} onChange={e=>updateAndDraft("address",e.target.value)}/></div>
        <div className="flex justify-end pt-1"><Button type="button" variant="outline" size="sm" onClick={()=>saveSection("১",["full_name","phone","profile_photo_url","address"])} disabled={!!sectionSaving}>{sectionSaving==="১"?"সংরক্ষণ হচ্ছে...":sectionSaved==="১"?"সংরক্ষিত ✓":"এই অংশ সংরক্ষণ করুন"}</Button></div>
      </CardContent></Card>

      <Card><CardHeader className="pb-3"><CardTitle className="text-base">২. {isHospital?"ভেরিফিকেশন প্রমাণপত্র":"পেশাগত তথ্য"}</CardTitle><CardDescription>
        {isHospital?"নিচের যেকোনো একটি বৈধ প্রমাণপত্র দিন। কেন নেওয়া হচ্ছে: প্রতিষ্ঠানের পরিচয় ও বৈধতা যাচাই করে রোগীদের জন্য নির্ভরযোগ্য তথ্য প্রকাশ করতে।":"ডাক্তার ভেরিফিকেশনের মূল প্রমাণ হিসেবে BMDC নেওয়া হবে। NID বাধ্যতামূলক নয়।"}
      </CardDescription></CardHeader><CardContent className="space-y-3">
        {isHospital ? <>
          <div className="grid gap-2 sm:grid-cols-3">{[["bmdc","বিএমডিসি"],["trade_license","ট্রেড লাইসেন্স"],["nid","এনআইডি"]].map(([v,l])=><button type="button" key={v} onClick={()=>updateAndDraft("verification_type",v)} className={`rounded-xl border px-3 py-2 text-sm font-semibold ${form.verification_type===v?"border-primary bg-primary/10 text-primary":"border-border"}`}>{l}</button>)}</div>
          {form.verification_type==="bmdc"&&<div className="grid gap-3 sm:grid-cols-2"><div><Label>BMDC নম্বর *</Label><Input required value={form.bmdc_registration_no} onChange={e=>updateAndDraft("bmdc_registration_no",e.target.value)}/></div><div><Label>BMDC প্রমাণপত্র</Label><ImageUploader bucket="seller-verification" privateBucket folder={user.id} value={form.bmdc_document_url} onUploaded={u=>updateAndDraft("bmdc_document_url",u)} maxSizeKB={DOC_MAX}/></div></div>}
          {form.verification_type==="trade_license"&&<div className="grid gap-3 sm:grid-cols-2"><div><Label>ট্রেড লাইসেন্স নম্বর *</Label><Input required value={form.trade_license_no} onChange={e=>updateAndDraft("trade_license_no",e.target.value)}/></div><div><Label>ট্রেড লাইসেন্স কপি</Label><ImageUploader bucket="seller-verification" privateBucket folder={user.id} value={form.trade_license_url} onUploaded={u=>updateAndDraft("trade_license_url",u)} maxSizeKB={DOC_MAX}/></div></div>}
          {form.verification_type==="nid"&&<div><Label>এনআইডি সামনের অংশ *</Label><ImageUploader bucket="seller-verification" privateBucket folder={user.id} value={form.nid_front_url} onUploaded={u=>updateAndDraft("nid_front_url",u)} maxSizeKB={DOC_MAX} aspect="wide"/></div>}
        </> : <>
          <div className="grid gap-3 sm:grid-cols-2"><div><Label>ডিগ্রি *</Label><Input required placeholder="MBBS, BDS, FCPS" value={form.degree} onChange={e=>updateAndDraft("degree",e.target.value)}/></div><div><Label>পদবি</Label><Input placeholder="কনসালট্যান্ট / অধ্যাপক" value={form.designation||""} onChange={e=>updateAndDraft("designation",e.target.value)}/></div></div>
          <div className="grid gap-3 sm:grid-cols-2"><div><Label>বিশেষত্ব *</Label><Input required placeholder="হৃদরোগ / দন্ত চিকিৎসা" value={form.specialty} onChange={e=>updateAndDraft("specialty",e.target.value)}/></div><div><Label>BMDC রেজিস্ট্রেশন নম্বর *</Label><Input required value={form.bmdc_registration_no} onChange={e=>updateAndDraft("bmdc_registration_no",e.target.value)}/></div></div>
          <div className="rounded-xl border border-primary/15 bg-primary/5 p-3 text-xs leading-5 text-muted-foreground"><ShieldCheck className="mr-1 inline h-4 w-4 text-primary"/>BMDC নম্বর দিয়ে BMDC-এর তথ্য যাচাই করা সম্ভব হলে NID লাগবে না। শুধু যদি BMDC থেকে অনলাইনে যাচাই করা সম্ভব না হয়, পরিচয় নিশ্চিত করার অতিরিক্ত প্রমাণ হিসেবে <b>শুধু NID-এর সামনের অংশ</b> দিতে বলা হবে।</div>
          <div><Label>BMDC প্রমাণপত্র (ঐচ্ছিক)</Label><ImageUploader bucket="seller-verification" privateBucket folder={user.id} value={form.bmdc_document_url} onUploaded={u=>updateAndDraft("bmdc_document_url",u)} maxSizeKB={DOC_MAX}/></div>
          <div><Label>NID সামনের অংশ (শুধু প্রয়োজন হলে)</Label><ImageUploader bucket="seller-verification" privateBucket folder={user.id} value={form.nid_front_url} onUploaded={u=>updateAndDraft("nid_front_url",u)} maxSizeKB={DOC_MAX} aspect="wide"/></div>
        </>}
        <div className="flex justify-end pt-1"><Button type="button" variant="outline" size="sm" onClick={()=>saveSection("২",isHospital?["verification_type","bmdc_registration_no","bmdc_document_url","trade_license_no","trade_license_url","nid_front_url"]:["degree","designation","specialty","bmdc_registration_no","bmdc_document_url","nid_front_url"])} disabled={!!sectionSaving}>{sectionSaving==="২"?"সংরক্ষণ হচ্ছে...":sectionSaved==="২"?"সংরক্ষিত ✓":"এই অংশ সংরক্ষণ করুন"}</Button></div>
      </CardContent></Card>

      <Card><CardHeader className="pb-3"><CardTitle className="text-base">৩. {isHospital?"হাসপাতাল / চেম্বারের তথ্য":"চেম্বারের তথ্য"}</CardTitle></CardHeader><CardContent className="space-y-3">
        <div className="grid gap-3 sm:grid-cols-2"><div><Label>{isHospital?"হাসপাতালের নাম":"চেম্বারের নাম"} *</Label><Input required value={form.chamber_name||""} onChange={e=>updateAndDraft("chamber_name",e.target.value)}/></div><div><Label>{isHospital?"ঠিকানা":"চেম্বারের ঠিকানা"}</Label><Input value={form.chamber_address||""} onChange={e=>updateAndDraft("chamber_address",e.target.value)}/></div></div>
        {!isHospital&&<div className="grid gap-3 sm:grid-cols-3"><div><Label>রোগী দেখার দিন</Label><Input value={form.visiting_days||""} onChange={e=>updateAndDraft("visiting_days",e.target.value)}/></div><div><Label>রোগী দেখার সময়</Label><Input value={form.visiting_time||""} onChange={e=>updateAndDraft("visiting_time",e.target.value)}/></div><div><Label>পরামর্শ ফি (৳)</Label><Input type="number" min="0" value={form.consultation_fee||""} onChange={e=>updateAndDraft("consultation_fee",e.target.value)}/></div></div>}
        <div className="flex justify-end pt-1"><Button type="button" variant="outline" size="sm" onClick={()=>saveSection("৩",isHospital?["chamber_name","chamber_address"]:["chamber_name","chamber_address","visiting_days","visiting_time","consultation_fee"])} disabled={!!sectionSaving}>{sectionSaving==="৩"?"সংরক্ষণ হচ্ছে...":sectionSaved==="৩"?"সংরক্ষিত ✓":"এই অংশ সংরক্ষণ করুন"}</Button></div>
      </CardContent></Card>

      {error&&<p className="text-sm text-destructive">{error}</p>}
      {approved?<p className="flex items-center gap-2 text-xs text-muted-foreground"><Lock className="h-3.5 w-3.5"/> অনুমোদিত ভেরিফিকেশন সরাসরি পরিবর্তন করা যাবে না।</p>:
      <Button type="submit" disabled={saving} size="lg">{saved?<Check className="h-4 w-4"/>:<Save className="h-4 w-4"/>}{saving?"সংরক্ষণ হচ্ছে...":saved?"সংরক্ষিত হয়েছে":"ভেরিফিকেশন জমা দিন"}</Button>}
    </form>
  </div>;
}
