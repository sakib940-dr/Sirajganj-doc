import { useState } from "react";
import { User, Phone, CheckCircle2, MapPin, KeyRound } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import ChangePasswordForm from "@/components/shared/ChangePasswordForm.jsx";
import { useAuth } from "@/hooks/useAuth";
import { ROLE_LABEL_BN } from "@/constants/roles";

export default function PersonalDetailsPage() {
  const { profile, role, updateProfile } = useAuth();
  const [fullName,setFullName]=useState(profile?.full_name||"");
  const [phone,setPhone]=useState(profile?.phone||"");
  const [address,setAddress]=useState(profile?.address||"");
  const [avatarUrl,setAvatarUrl]=useState(profile?.avatar_url||"");
  const [saving,setSaving]=useState(false); const [saved,setSaved]=useState(false); const [error,setError]=useState("");
  const initial=(fullName?.trim()?.charAt(0)||"ব").toUpperCase();
  const submit=async(e)=>{e.preventDefault();setSaving(true);setSaved(false);setError("");const {error}=await updateProfile({full_name:fullName.trim(),phone:phone.trim(),address:address.trim()||null,avatar_url:avatarUrl});setSaving(false);if(error){setError("তথ্য সংরক্ষণ ব্যর্থ হয়েছে: "+error.message);return;}setSaved(true);};
  return <div className="mx-auto max-w-2xl space-y-5">
    <div><h1 className="text-xl font-bold" style={{fontFamily:"'Tiro Bangla', serif"}}>ব্যক্তিগত তথ্য</h1><p className="mt-1 text-sm text-muted-foreground">{ROLE_LABEL_BN[role]} অ্যাকাউন্টের ব্যক্তিগত তথ্য</p></div>
    <Card><CardContent className="pt-6">
      <div className="mb-5 flex flex-col items-center gap-3"><div className="h-24 w-24 overflow-hidden rounded-full border-4 border-card bg-primary text-center text-2xl font-bold leading-[88px] text-primary-foreground shadow-md">{avatarUrl?<img src={avatarUrl} alt="" className="h-full w-full object-cover"/>:initial}</div><ImageUploader bucket="user-avatars" folder={profile?.id} value="" onUploaded={async url=>{setAvatarUrl(url);await updateProfile({avatar_url:url});}} aspect="square" maxSizeKB={1024} autoCompress compressTargetMinKB={80} compressTargetMaxKB={150}/></div>
      <form onSubmit={submit} className="space-y-4">
        <div className="space-y-1.5"><Label htmlFor="staff-name">পুরো নাম</Label><div className="relative"><User className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"/><Input id="staff-name" value={fullName} onChange={e=>setFullName(e.target.value)} className="pl-9" placeholder="আপনার নাম লিখুন"/></div></div>
        <div className="space-y-1.5"><Label htmlFor="staff-phone">ফোন নম্বর</Label><div className="relative"><Phone className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"/><Input id="staff-phone" value={phone} onChange={e=>setPhone(e.target.value)} className="pl-9" placeholder="০১XXXXXXXXX"/></div></div>
        <div className="space-y-1.5"><Label htmlFor="staff-address">ঠিকানা</Label><div className="relative"><MapPin className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-muted-foreground"/><Textarea id="staff-address" value={address} onChange={e=>setAddress(e.target.value)} rows={2} className="pl-9" placeholder="ঠিকানা লিখুন"/></div></div>
        {error&&<p className="text-sm text-destructive">{error}</p>}{saved&&<p className="flex items-center gap-1.5 text-sm text-primary"><CheckCircle2 className="h-4 w-4"/>তথ্য সংরক্ষিত হয়েছে।</p>}
        <Button type="submit" disabled={saving}>{saving?"সংরক্ষণ হচ্ছে...":"তথ্য সংরক্ষণ করুন"}</Button>
      </form>
    </CardContent></Card>
    <Card><CardHeader><span className="mb-1 flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary"><KeyRound className="h-5 w-5"/></span><CardTitle>পাসওয়ার্ড পরিবর্তন</CardTitle><CardDescription>আপনার অ্যাকাউন্টের লগইন পাসওয়ার্ড পরিবর্তন করুন।</CardDescription></CardHeader><CardContent><ChangePasswordForm/></CardContent></Card>
  </div>;
}
