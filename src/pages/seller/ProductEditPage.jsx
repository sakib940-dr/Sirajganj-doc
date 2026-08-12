import { useEffect, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { Save, Check, X } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { useCategories } from "@/hooks/useCategories";
import { slugify } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import PendingApprovalNotice from "@/components/seller/PendingApprovalNotice.jsx";
import { ROUTES } from "@/constants/routes";
import { ROLES, SELLER_STATUS, isAdminOrAbove } from "@/constants/roles";

const EMPTY = {
  name:"", slug:"", category_id:"", price:"", description:"", thumbnail_url:"",
  is_active:true, name_en:"", name_bn:"", search_keywords:"",
  degree:"", designation:"", bmdc_registration_no:"", consultation_fee:"",
  visiting_days:"", visiting_time:""
};
const MAX_EXTRA_IMAGES = 3;
const MAX_KB = 1024;
const MIN_COMPRESS_KB = 100;
const MAX_COMPRESS_KB = 200;

export default function ProductEditPage({ embedded = false }) {
  const { id } = useParams();
  const [প্রোফাইলId, setProfileId] = useState(id || null);
  const editing = !!প্রোফাইলId;
  const navigate = useNavigate();
  const { user, role, sellerStatus } = useAuth();
  const { categories } = useCategories();
  const approved = isAdminOrAbove(role) || (role === ROLES.DOCTOR && sellerStatus === SELLER_STATUS.APPROVED);
  const [shopId,setShopId]=useState(null);
  const [product,setProduct]=useState(EMPTY);
  const [extraImages,setExtraImages]=useState([]);
  const [loading,setLoading]=useState(true);
  const [saving,setSaving]=useState(false);
  const [saved,setSaved]=useState(false);
  const [error,setError]=useState("");
  const [slugEdited,setSlugEdited]=useState(editing);

  useEffect(()=>{
    async function load(){
      const {data:shop}=await supabase.from("shops").select("id").eq("owner_id",user.id).maybeSingle();
      setShopId(shop?.id??null);
      if(editing){
        const targetId = প্রোফাইলId || null;
        const {data}=await supabase.from("products").select("*").eq("id",targetId).single();
        if(data) setProduct({...EMPTY,...data, consultation_fee:data.consultation_fee ?? data.price ?? ""});
        const {data:imgs}=await supabase.from("product_images").select("*").eq("product_id",targetId).order("sort_order");
        setExtraImages(imgs??[]);
      }
      setLoading(false);
    }
    if(user) load();
  },[user,id,প্রোফাইলId,editing]);

  const update=(k,v)=>setProduct(p=>({...p,[k]:v}));
  const nameChange=(v)=>{update("name",v); if(!slugEdited) update("slug",slugify(v));};

  const submit=async(e)=>{
    e.preventDefault(); setError(""); setSaved(false);
    if(!product.name.trim() || !product.slug.trim()) return setError("ডাক্তারের নাম ও প্রোফাইল লিংক অবশ্যই দিতে হবে।");
    if(!product.thumbnail_url) return setError("ডাক্তার প্রোফাইল photo আবশ্যক।");
    if(!product.category_id) return setError("বিশেষত্ব নির্বাচন করুন।");
    if(!shopId) return setError("আগে Chamber Settings পূরণ করুন।");
    const fee=product.consultation_fee==="" ? Number(product.price||0) : Number(product.consultation_fee);
    if(fee<0) return setError("পরামর্শ ফি সঠিকভাবে দিন।");

    setSaving(true);
    const payload={
      name:product.name.trim(), slug:slugify(product.slug), category_id:product.category_id,
      price:fee, consultation_fee:fee, description:product.description||null,
      thumbnail_url:product.thumbnail_url, প্রোফাইল_photo_url:product.thumbnail_url,
      is_active:!!product.is_active, name_en:product.name_en||null, name_bn:product.name_bn||null,
      search_keywords:product.search_keywords||null, degree:product.degree||null,
      designation:product.designation||null, bmdc_registration_no:product.bmdc_registration_no||null,
      visiting_days:product.visiting_days||null, visiting_time:product.visiting_time||null,
      shop_id:shopId, doctor_id:user.id
    };
    const result=editing
      ? await supabase.from("products").update(payload).eq("id",প্রোফাইলId).select().single()
      : await supabase.from("products").insert(payload).select().single();
    if(result.error){
      const msg=result.error.message||"";
      if(msg.includes("duplicate") || msg.includes("ux_one_doctor_প্রোফাইল_per_owner"))
        setError("এই ডাক্তার অ্যাকাউন্ট-এর একটি প্রোফাইল ইতিমধ্যে আছে।");
      else if(msg.toLowerCase().includes("row-level security"))
        setError("অনুমতি নেই — ডাক্তার verification অনুমোদিত হওয়ার পর প্রোফাইল publish করা যাবে।");
      else setError("সংরক্ষণ ব্যর্থ হয়েছে: "+msg);
      setSaving(false); return;
    }
    setSaved(true);
    if(!editing){ setProfileId(result.data.id); if(!embedded) navigate(`/dashboard/products/${result.data.id}/edit`,{replace:true}); }
    setSaving(false);
  };

  const addImage=async(url)=>{
    if(!url || !প্রোফাইলId || extraImages.length>=MAX_EXTRA_IMAGES) return;
    const {data}=await supabase.from("product_images").insert({product_id:প্রোফাইলId,image_url:url,sort_order:extraImages.length}).select().single();
    if(data) setExtraImages(v=>[...v,data]);
  };
  const removeImage=async(imgId)=>{await supabase.from("product_images").delete().eq("id",imgId);setExtraImages(v=>v.filter(x=>x.id!==imgId));};

  if(!approved) return embedded ? null : <PendingApprovalNotice status={sellerStatus}/>;
  if(loading) return <LoadingSpinner label="ডাক্তার প্রোফাইল লোড হচ্ছে..."/>;

  const roots=categories.filter(c=>!c.parent_id);
  const children=categories.reduce((a,c)=>{if(c.parent_id)(a[c.parent_id]??=[]).push(c);return a;},{});

  const content = <div className="space-y-5">
    {!embedded && <div>
      <h1 className="text-xl font-bold" style={{fontFamily:"'Tiro Bangla', serif"}}>{editing?"ডাক্তার প্রোফাইল সম্পাদনা":"ডাক্তার প্রোফাইল প্রকাশ"}</h1>
      <p className="text-sm text-muted-foreground">প্রতি ডাক্তার অ্যাকাউন্টে সর্বোচ্চ ১টি পাবলিক প্রোফাইল থাকবে।</p>
    </div>}

    <form onSubmit={submit} className="space-y-5">
      <Card><CardHeader><CardTitle className="text-base">প্রোফাইল ছবি</CardTitle><CardDescription>১ MB পর্যন্ত ছবি দিন; upload-এর সময় 100–200 KB-এর মধ্যে compress হবে। সর্বোচ্চ ৪টি ছবি।</CardDescription></CardHeader>
        <CardContent>
          <ImageUploader bucket="product-images" folder={user.id} value={product.thumbnail_url} onUploaded={u=>update("thumbnail_url",u)} maxSizeKB={MAX_KB} autoCompress compressTargetMinKB={MIN_COMPRESS_KB} compressTargetMaxKB={MAX_COMPRESS_KB}/>
          {editing && <div className="mt-4 flex flex-wrap gap-3">{extraImages.map(img=><div key={img.id} className="relative h-24 w-24 overflow-hidden rounded-lg border"><img src={img.image_url} className="h-full w-full object-cover"/><button type="button" onClick={()=>removeImage(img.id)} className="absolute right-1 top-1 rounded-full bg-destructive p-1 text-white"><X className="h-3 w-3"/></button></div>)}{extraImages.length<MAX_EXTRA_IMAGES&&<ImageUploader bucket="product-images" folder={user.id} value="" onUploaded={addImage} maxSizeKB={MAX_KB} autoCompress compressTargetMinKB={MIN_COMPRESS_KB} compressTargetMaxKB={MAX_COMPRESS_KB}/>}</div>}
        </CardContent>
      </Card>

      <Card><CardHeader><CardTitle className="text-base">ডাক্তারের তথ্য</CardTitle></CardHeader><CardContent className="space-y-4">
        <div><Label>ডাক্তারের নাম *</Label><Input required value={product.name} onChange={e=>nameChange(e.target.value)} /></div>
        <div><Label>প্রোফাইল লিংক *</Label><Input required value={product.slug} onChange={e=>{setSlugEdited(true);update("slug",e.target.value)}}/></div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div><Label>ডিগ্রি</Label><Input placeholder="এমবিবিএস, বিডিএস, এফসিপিএস" value={product.degree||""} onChange={e=>update("degree",e.target.value)}/></div>
          <div><Label>পদবি</Label><Input placeholder="কনসালট্যান্ট / অধ্যাপক" value={product.designation||""} onChange={e=>update("designation",e.target.value)}/></div>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div><Label>বিএমডিসি রেজিস্ট্রেশন নম্বর</Label><Input value={product.bmdc_registration_no||""} onChange={e=>update("bmdc_registration_no",e.target.value)}/></div>
          <div><Label>পরামর্শ ফি (৳) *</Label><Input type="number" min="0" required value={product.consultation_fee} onChange={e=>update("consultation_fee",e.target.value)}/></div>
        </div>
        <div><Label>বিশেষত্ব *</Label><select required value={product.category_id||""} onChange={e=>update("category_id",e.target.value)} className="flex h-10 w-full rounded-lg border border-input bg-card px-3 text-sm">
          <option value="">বিশেষত্ব নির্বাচন করুন</option>
          {roots.map(c=>children[c.id]?.length ? <optgroup key={c.id} label={c.name}>{children[c.id].map(sub=><option key={sub.id} value={sub.id}>{sub.name}</option>)}</optgroup> : <option key={c.id} value={c.id}>{c.name}</option>)}
        </select></div>
        <div><Label>ডাক্তার সম্পর্কে</Label><textarea rows={5} value={product.description||""} onChange={e=>update("description",e.target.value)} className="flex w-full rounded-lg border border-input bg-card px-3 py-2 text-sm"/></div>
      </CardContent></Card>

      <Card><CardHeader><CardTitle className="text-base">রোগী দেখার সময়সূচি</CardTitle></CardHeader><CardContent className="grid gap-4 sm:grid-cols-2">
        <div><Label>রোগী দেখার দিন</Label><Input placeholder="শনি, রবি, সোম" value={product.visiting_days||""} onChange={e=>update("visiting_days",e.target.value)}/></div>
        <div><Label>রোগী দেখার সময়</Label><Input placeholder="বিকেল ৫টা – রাত ৯টা" value={product.visiting_time||""} onChange={e=>update("visiting_time",e.target.value)}/></div>
      </CardContent></Card>

      <Card><CardHeader><CardTitle className="text-base">খোঁজার কীওয়ার্ড</CardTitle><CardDescription>বাংলা/ইংরেজি রোগের বা বিশেষত্ব শব্দ দিন যাতে রোগী সহজে প্রোফাইল খুঁজে পায়।</CardDescription></CardHeader><CardContent className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2"><div><Label>ইংরেজি নাম</Label><Input value={product.name_en||""} onChange={e=>update("name_en",e.target.value)}/></div><div><Label>বাংলা নাম</Label><Input value={product.name_bn||""} onChange={e=>update("name_bn",e.target.value)}/></div></div>
        <div><Label>সম্পর্কিত কীওয়ার্ড</Label><textarea rows={2} placeholder="cardiologist, heart doctor, হৃদরোগ বিশেষজ্ঞ" value={product.search_keywords||""} onChange={e=>update("search_keywords",e.target.value)} className="flex w-full rounded-lg border border-input bg-card px-3 py-2 text-sm"/></div>
      </CardContent></Card>

      {error&&<p className="text-sm text-destructive">{error}</p>}
      <div className="flex gap-3"><Button type="submit" disabled={saving} size="lg">{saved?<Check className="h-4 w-4"/>:<Save className="h-4 w-4"/>}{saving?"সংরক্ষণ হচ্ছে...":saved?"সংরক্ষিত হয়েছে":"ডাক্তারের প্রোফাইল সংরক্ষণ করুন"}</Button><Button variant="outline" asChild><Link to={ROUTES.DASHBOARD_PRODUCTS}>বাতিল</Link></Button></div>
    </form>
  </div>;
  return embedded ? content : <div className="max-w-2xl space-y-6">{content}</div>;
}
