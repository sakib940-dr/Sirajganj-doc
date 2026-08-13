import { useEffect, useMemo, useState } from "react";
import { User, Building2, ShieldCheck, Save, CheckCircle2, Image as ImageIcon, Eye, EyeOff, LockKeyhole } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import ChangePasswordForm from "@/components/shared/ChangePasswordForm.jsx";
import { ROLES } from "@/constants/roles";

const EMPTY_SHOP = {
  shop_name:"", slug:"", logo_url:"", banner_url:"", about:"", phone:"", whatsapp_number:"",
  address:"", google_map_link:"", chamber_name:"", chamber_type:"", district:"সিরাজগঞ্জ", upazila:"",
  latitude:"", longitude:"", hospital_photo_urls:[], visiting_days:"", visiting_time:"",
  consultation_fee:"", assistant_phone:"", phone_public:true, whatsapp_public:false, assistant_phone_public:false
};

const DRAFT_KEY = (id) => `doctor-profile-center-draft-${id || "guest"}`;

function ExampleInput({ value, onChange, placeholder, ...props }) {
  return <Input value={value ?? ""} onChange={onChange} placeholder={placeholder} {...props}
    className="placeholder:text-muted-foreground/55" />;
}

function SaveState({ saved, error }) {
  if (error) return <p className="text-sm text-destructive">{error}</p>;
  if (saved) return <p className="flex items-center gap-1.5 text-sm text-primary"><CheckCircle2 className="h-4 w-4"/>এই অংশটি সংরক্ষিত হয়েছে।</p>;
  return null;
}

export default function ProviderProfileCenterPage() {
  const { user, profile, role, updateProfile } = useAuth();
  const isHospital = role === ROLES.HOSPITAL;
  const [personal, setPersonal] = useState({full_name:"", phone:"", address:"", avatar_url:"", phone_public:false});
  const [shop, setShop] = useState(EMPTY_SHOP);
  const [shopId, setShopId] = useState(null);
  const [proof, setProof] = useState({verification_type:isHospital ? "trade_license":"bmdc", bmdc_registration_no:"", bmdc_document_url:"", trade_license_no:"", trade_license_url:"", nid_front_url:""});
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState("");
  const [saved, setSaved] = useState("");
  const [errors, setErrors] = useState({});

  const setSection = (section, data) => {
    const key = DRAFT_KEY(user?.id);
    try {
      const current = JSON.parse(localStorage.getItem(key) || "{}");
      localStorage.setItem(key, JSON.stringify({...current, [section]: data}));
    } catch {}
  };

  useEffect(() => {
    if (!user) return;
    (async () => {
      setLoading(true);
      const [p, s, v] = await Promise.all([
        supabase.from("profiles").select("*").eq("id", user.id).maybeSingle(),
        supabase.from("shops").select("*").eq("owner_id", user.id).maybeSingle(),
        supabase.from("seller_verifications").select("*").eq("user_id", user.id).order("created_at",{ascending:false}).limit(1).maybeSingle()
      ]);
      let nextPersonal = {
        full_name:p.data?.full_name || profile?.full_name || "",
        phone:p.data?.phone || profile?.phone || "",
        address:p.data?.address || profile?.address || "",
        avatar_url:p.data?.avatar_url || profile?.avatar_url || "",
        phone_public:p.data?.phone_public ?? false
      };
      let nextShop = {...EMPTY_SHOP, ...(s.data || {})};
      let nextProof = {
        verification_type: v.data?.verification_type || (isHospital ? "trade_license":"bmdc"),
        bmdc_registration_no:v.data?.bmdc_registration_no || "",
        bmdc_document_url:v.data?.bmdc_document_url || "",
        trade_license_no:v.data?.trade_license_no || "",
        trade_license_url:v.data?.trade_license_url || "",
        nid_front_url:v.data?.nid_front_url || ""
      };
      setStatus(v.data?.status || null);
      try {
        const draft = JSON.parse(localStorage.getItem(DRAFT_KEY(user.id)) || "{}");
        if (draft.personal) nextPersonal = {...nextPersonal,...draft.personal};
        if (draft.shop) nextShop = {...nextShop,...draft.shop};
        if (draft.proof) nextProof = {...nextProof,...draft.proof};
      } catch {}
      setPersonal(nextPersonal); setShop(nextShop); setProof(nextProof); setShopId(s.data?.id || null); setLoading(false);
    })();
  }, [user?.id]);

  const changePersonal = (k,v) => setPersonal(x => { const n={...x,[k]:v}; setSection("personal",n); return n; });
  const changeShop = (k,v) => setShop(x => { const n={...x,[k]:v}; setSection("shop",n); return n; });
  const changeProof = (k,v) => setProof(x => { const n={...x,[k]:v}; setSection("proof",n); return n; });

  const save = async (section) => {
    setSaving(section); setSaved(""); setErrors(e=>({...e,[section]:""}));
    try {
      if (section === "personal") {
        const {error} = await updateProfile({
          full_name: personal.full_name.trim(),
          phone: personal.phone.trim(),
          address: personal.address.trim() || null,
          avatar_url: personal.avatar_url || null,
          phone_public: !!personal.phone_public
        });
        if (error) throw error;
      }
      if (section === "shop") {
        if (!shop.shop_name.trim()) throw new Error("চেম্বার/হাসপাতালের নাম দিন।");
        const payload = {
          ...shop, owner_id:user.id, slug:shop.slug || shop.shop_name,
          chamber_name:shop.chamber_name || shop.shop_name,
          latitude:shop.latitude===""?null:Number(shop.latitude),
          longitude:shop.longitude===""?null:Number(shop.longitude),
          consultation_fee:shop.consultation_fee===""?null:Number(shop.consultation_fee)
        };
        let res = shopId
          ? await supabase.from("shops").update(payload).eq("id",shopId).select().single()
          : await supabase.from("shops").insert(payload).select().single();
        if (res.error) throw res.error;
        setShop({...EMPTY_SHOP,...res.data}); setShopId(res.data.id);
      }
      if (section === "proof") {
        const {data:existing,error:findErr} = await supabase.from("seller_verifications").select("id,status").eq("user_id",user.id).order("created_at",{ascending:false}).limit(1).maybeSingle();
        if (findErr) throw findErr;
        const payload = {user_id:user.id,...proof};
        if (existing?.id) {
          if (existing.status === "approved") throw new Error("অনুমোদিত ভেরিফিকেশন পরিবর্তন করা যাবে না।");
          const {error} = await supabase.from("seller_verifications").update(payload).eq("id",existing.id);
          if (error) throw error;
        } else {
          const {error} = await supabase.from("seller_verifications").insert(payload);
          if (error) throw error;
        }
      }
      try {
        const draft = JSON.parse(localStorage.getItem(DRAFT_KEY(user.id)) || "{}");
        delete draft[section];
        localStorage.setItem(DRAFT_KEY(user.id), JSON.stringify(draft));
      } catch {}
      setSaved(section); setTimeout(()=>setSaved(""),1800);
    } catch (e) {
      setErrors(x=>({...x,[section]: e?.message || "সংরক্ষণ করা যায়নি।"}));
    } finally { setSaving(""); }
  };

  const setImage = (field, url, section="personal") => {
    if (section === "personal") changePersonal(field,url);
    else changeShop(field,url);
  };

  if (loading) return <LoadingSpinner label="আপনার তথ্য লোড হচ্ছে..." />;

  return (
    <div className="mx-auto max-w-3xl space-y-5">
      <div>
        <h1 className="text-xl font-bold" style={{fontFamily:"'Tiro Bangla', serif"}}>{isHospital ? "হাসপাতাল/চেম্বার প্রোফাইল" : "ডাক্তার প্রোফাইল"}</h1>
        <p className="mt-1 text-sm text-muted-foreground">একই তথ্য একবারই দিন। প্রতিটি অংশ আলাদাভাবে সংরক্ষণ করা যাবে। রিফ্রেশ হলেও অসম্পূর্ণ তথ্যের খসড়া থাকবে।</p>
      </div>

      <Card>
        <CardHeader><CardTitle className="flex items-center gap-2 text-base"><User className="h-5 w-5 text-primary"/>১. ব্যক্তিগত তথ্য</CardTitle><CardDescription>নাম, ফোন ও প্রোফাইল ছবি এখানেই একবার দিন। অন্য কোনো ফর্মে আবার দিতে হবে না।</CardDescription></CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div><Label>নাম</Label><ExampleInput value={personal.full_name} onChange={e=>changePersonal("full_name",e.target.value)} placeholder="উদাহরণ: ডা. মো. নাজমুস সাকিব"/></div>
            <div><Label>মোবাইল নম্বর</Label><ExampleInput value={personal.phone} onChange={e=>changePersonal("phone",e.target.value)} placeholder="উদাহরণ: ০১৭১২৩৪৫৬৭৮"/></div>
          </div>
          <div><Label>ঠিকানা</Label><Textarea value={personal.address} onChange={e=>changePersonal("address",e.target.value)} placeholder="উদাহরণ: সিরাজগঞ্জ সদর, সিরাজগঞ্জ" className="placeholder:text-muted-foreground/55"/></div>
          <div className="flex flex-wrap items-center gap-4 rounded-xl bg-secondary/40 p-3 text-sm">
            <span className="font-medium">এই নম্বর কোথায় প্রকাশ হবে?</span>
            <label className="flex items-center gap-2"><input type="checkbox" checked={!!personal.phone_public} onChange={e=>changePersonal("phone_public",e.target.checked)}/> পাবলিক ডাক্তার প্রোফাইলে</label>
            <span className="text-xs text-muted-foreground">বন্ধ রাখলে রোগীরা নম্বর দেখতে পাবে না।</span>
          </div>
          <div>
            <Label>প্রোফাইল ছবি</Label>
            <p className="mb-2 text-xs text-muted-foreground">সর্বোচ্চ ১ MB। আপলোডের পর সিস্টেম স্বয়ংক্রিয়ভাবে ছোট করবে।</p>
            <ImageUploader bucket="user-avatars" folder={user.id} value={personal.avatar_url || ""} onUploaded={url=>setImage("avatar_url",url)} aspect="square" maxSizeKB={1024} autoCompress compressTargetMinKB={100} compressTargetMaxKB={200}/>
          </div>
          <div className="flex items-center justify-between gap-3"><SaveState saved={saved==="personal"} error={errors.personal}/><Button onClick={()=>save("personal")} disabled={saving==="personal"}>{saving==="personal"?"সংরক্ষণ হচ্ছে...":"এই অংশ সংরক্ষণ করুন"}</Button></div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader><CardTitle className="flex items-center gap-2 text-base"><Building2 className="h-5 w-5 text-primary"/>২. চেম্বার / হাসপাতালের তথ্য</CardTitle><CardDescription>চেম্বার/হাসপাতালের একই তথ্য এখানেই একবার রাখুন।</CardDescription></CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div><Label>চেম্বার / হাসপাতালের নাম</Label><ExampleInput value={shop.shop_name} onChange={e=>changeShop("shop_name",e.target.value)} placeholder="উদাহরণ: সিরাজগঞ্জ ডেন্টাল কেয়ার"/></div>
            <div><Label>ধরন</Label><ExampleInput value={shop.chamber_type} onChange={e=>changeShop("chamber_type",e.target.value)} placeholder="উদাহরণ: চেম্বার / হাসপাতাল"/></div>
            <div><Label>ঠিকানা</Label><ExampleInput value={shop.address} onChange={e=>changeShop("address",e.target.value)} placeholder="উদাহরণ: এসএস রোড, সিরাজগঞ্জ সদর"/></div>
            <div><Label>উপজেলা</Label><ExampleInput value={shop.upazila} onChange={e=>changeShop("upazila",e.target.value)} placeholder="উদাহরণ: সিরাজগঞ্জ সদর"/></div>
            <div><Label>Google Maps লিংক</Label><ExampleInput value={shop.google_map_link} onChange={e=>changeShop("google_map_link",e.target.value)} placeholder="উদাহরণ: Google Maps-এর শেয়ার লিংক"/></div>
            <div><Label>ভিজিটিং সময়</Label><ExampleInput value={shop.visiting_time} onChange={e=>changeShop("visiting_time",e.target.value)} placeholder="উদাহরণ: বিকাল ৫টা–রাত ৯টা"/></div>
            <div><Label>ভিজিটিং দিন</Label><ExampleInput value={shop.visiting_days} onChange={e=>changeShop("visiting_days",e.target.value)} placeholder="উদাহরণ: শনি–বৃহস্পতি"/></div>
            <div><Label>ভিজিট ফি</Label><ExampleInput value={shop.consultation_fee} onChange={e=>changeShop("consultation_fee",e.target.value)} placeholder="উদাহরণ: ৫০০ টাকা"/></div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div><Label>WhatsApp নম্বর</Label><ExampleInput value={shop.whatsapp_number} onChange={e=>changeShop("whatsapp_number",e.target.value)} placeholder="উদাহরণ: ০১৭১২৩৪৫৬৭৮"/></div>
            <div><Label>সহকারী নম্বর</Label><ExampleInput value={shop.assistant_phone} onChange={e=>changeShop("assistant_phone",e.target.value)} placeholder="উদাহরণ: ০১৮১২৩৪৫৬৭৮"/></div>
          </div>
          <div className="space-y-2 rounded-xl bg-secondary/40 p-3 text-sm">
            <p className="font-medium">কোন নম্বর কোথায় প্রকাশ হবে?</p>
            <label className="flex items-center gap-2"><input type="checkbox" checked={!!shop.phone_public} onChange={e=>changeShop("phone_public",e.target.checked)}/> চেম্বার/হাসপাতাল পেজে কল নম্বর</label>
            <label className="flex items-center gap-2"><input type="checkbox" checked={!!shop.whatsapp_public} onChange={e=>changeShop("whatsapp_public",e.target.checked)}/> WhatsApp বাটনে</label>
            <label className="flex items-center gap-2"><input type="checkbox" checked={!!shop.assistant_phone_public} onChange={e=>changeShop("assistant_phone_public",e.target.checked)}/> সহকারী নম্বর (পাবলিক)</label>
            <p className="text-xs text-muted-foreground">বন্ধ রাখা নম্বর কোনো পাবলিক পেজে দেখানো হবে না।</p>
          </div>
          <div>
            <Label>হাসপাতাল/চেম্বারের ছবি (সর্বোচ্চ ৪টি)</Label>
            <p className="mb-2 text-xs text-muted-foreground">রোগীরা চেম্বার/হাসপাতালের পেজ খুললে এগুলো উপরে দেখতে পাবে। প্রতিটি ছবি সর্বোচ্চ ১ MB; আপলোডের পর স্বয়ংক্রিয়ভাবে কমপ্রেস হবে।</p>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {[0,1,2,3].map(i=><ImageUploader key={i} bucket="shop-images" folder={user.id} value={shop.hospital_photo_urls?.[i] || ""} onUploaded={url=>changeShop("hospital_photo_urls", [...(shop.hospital_photo_urls||[]).filter((_,j)=>j!==i).slice(0,i), url, ...(shop.hospital_photo_urls||[]).slice(i+1)])} aspect="landscape" maxSizeKB={1024} autoCompress compressTargetMinKB={100} compressTargetMaxKB={200}/>)}
            </div>
          </div>
          <div className="flex items-center justify-between gap-3"><SaveState saved={saved==="shop"} error={errors.shop}/><Button onClick={()=>save("shop")} disabled={saving==="shop"}>{saving==="shop"?"সংরক্ষণ হচ্ছে...":"এই অংশ সংরক্ষণ করুন"}</Button></div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader><CardTitle className="flex items-center gap-2 text-base"><ShieldCheck className="h-5 w-5 text-primary"/>৩. ভেরিফিকেশন</CardTitle><CardDescription>ব্যক্তিগত নাম/ফোন/ঠিকানা এখানে আবার দিতে হবে না। শুধু যাচাইয়ের প্রমাণ দিন।</CardDescription></CardHeader>
        <CardContent className="space-y-4">
          {isHospital ? (
            <>
              <div><Label>যাচাইয়ের প্রমাণ</Label><div className="mt-2 grid gap-2 sm:grid-cols-3">
                {[["trade_license","ট্রেড লাইসেন্স"],["bmdc","BMDC"],["nid","NID"]].map(([v,l])=><button key={v} type="button" onClick={()=>changeProof("verification_type",v)} className={`rounded-xl border p-3 text-sm ${proof.verification_type===v?"border-primary bg-primary/5":"border-border"}`}>{l}</button>)}
              </div></div>
              {proof.verification_type==="bmdc" && <div><Label>BMDC নম্বর</Label><ExampleInput value={proof.bmdc_registration_no} onChange={e=>changeProof("bmdc_registration_no",e.target.value)} placeholder="উদাহরণ: BMDC-12345"/></div>}
              {proof.verification_type==="trade_license" && <div><Label>ট্রেড লাইসেন্স নম্বর</Label><ExampleInput value={proof.trade_license_no} onChange={e=>changeProof("trade_license_no",e.target.value)} placeholder="উদাহরণ: TL-123456"/></div>}
              {proof.verification_type==="nid" && <ImageUploader bucket="verification-docs" folder={user.id} value={proof.nid_front_url||""} onUploaded={url=>changeProof("nid_front_url",url)} aspect="landscape" maxSizeKB={1024} autoCompress compressTargetMinKB={100} compressTargetMaxKB={200}/>}
              <p className="rounded-xl bg-secondary/40 p-3 text-xs text-muted-foreground">হাসপাতাল/চেম্বারের পরিচয় ও বৈধতা যাচাই করে রোগীদের কাছে নির্ভরযোগ্য তথ্য প্রকাশ করার জন্য এই প্রমাণ নেওয়া হয়।</p>
            </>
          ) : (
            <>
              <div><Label>BMDC রেজিস্ট্রেশন নম্বর</Label><ExampleInput value={proof.bmdc_registration_no} onChange={e=>changeProof("bmdc_registration_no",e.target.value)} placeholder="উদাহরণ: A-12345"/></div>
              <div><Label>BMDC নথি (যদি অনলাইন যাচাই সম্ভব না হয়)</Label><ImageUploader bucket="verification-docs" folder={user.id} value={proof.bmdc_document_url||""} onUploaded={url=>changeProof("bmdc_document_url",url)} aspect="landscape" maxSizeKB={1024} autoCompress compressTargetMinKB={100} compressTargetMaxKB={200}/></div>
              <div><Label>NID-এর সামনের অংশ (শুধু BMDC থেকে অনলাইনে যাচাই সম্ভব না হলে)</Label><ImageUploader bucket="verification-docs" folder={user.id} value={proof.nid_front_url||""} onUploaded={url=>changeProof("nid_front_url",url)} aspect="landscape" maxSizeKB={1024} autoCompress compressTargetMinKB={100} compressTargetMaxKB={200}/></div>
              <p className="rounded-xl bg-secondary/40 p-3 text-xs text-muted-foreground">BMDC নম্বর দিয়ে অনলাইনে তথ্য যাচাই করা সম্ভব হলে NID লাগবে না। যাচাই সম্ভব না হলে পরিচয় নিশ্চিত করার অতিরিক্ত প্রমাণ হিসেবে শুধু NID-এর সামনের অংশ চাওয়া হতে পারে।</p>
            </>
          )}
          {status && <p className="text-xs text-muted-foreground">বর্তমান অবস্থা: <b>{status==="approved"?"অনুমোদিত":status==="pending"?"পর্যালোচনাধীন":"পুনরায় জমা দিতে হবে"}</b></p>}
          <div className="flex items-center justify-between gap-3"><SaveState saved={saved==="proof"} error={errors.proof}/><Button onClick={()=>save("proof")} disabled={saving==="proof"}>{saving==="proof"?"সংরক্ষণ হচ্ছে...":"ভেরিফিকেশন অংশ সংরক্ষণ করুন"}</Button></div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader><CardTitle className="flex items-center gap-2 text-base"><LockKeyhole className="h-5 w-5 text-primary"/>নিরাপত্তা</CardTitle><CardDescription>পাসওয়ার্ড পরিবর্তন করুন।</CardDescription></CardHeader>
        <CardContent><ChangePasswordForm/></CardContent>
      </Card>
    </div>
  );
}
