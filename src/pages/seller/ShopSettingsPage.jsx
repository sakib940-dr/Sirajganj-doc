import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ExternalLink, Save, Check, Navigation } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { slugify } from "@/lib/utils";
import { shopPath } from "@/constants/routes";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import ShareShopButton from "@/components/shared/ShareShopButton.jsx";
import ProductEditPage from "@/pages/seller/ProductEditPage.jsx";

const EMPTY = {
  shop_name: "", slug: "", logo_url: "", banner_url: "", about: "",
  phone: "", whatsapp_number: "", address: "", google_map_link: "",
  facebook_link: "", messenger_link: "", chamber_name: "", chamber_type: "", district: "সিরাজগঞ্জ", upazila: "",
  latitude: "", longitude: "", hospital_photo_urls: [],
  visiting_days: "", visiting_time: "", consultation_fee: "", assistant_phone: ""
};

export default function ShopSettingsPage() {
  const { user, role } = useAuth();
  const [shop, setShop] = useState(EMPTY);
  const [shopId, setShopId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState(false);
  const [slugEdited, setSlugEdited] = useState(false);

  useEffect(() => {
    if (!user) return;
    supabase.from("shops").select("*").eq("owner_id", user.id).maybeSingle().then(({ data }) => {
      if (data) {
        setShop({ ...EMPTY, ...data });
        setShopId(data.id);
        setSlugEdited(true);
      }
      setLoading(false);
    });
  }, [user]);

  const update = (field, value) => setShop(prev => ({ ...prev, [field]: value }));

  const handleName = (value) => {
    update("shop_name", value);
    if (!slugEdited) update("slug", slugify(value));
  };

  const useCurrentLocation = () => {
    if (!navigator.geolocation) {
      setError("এই ডিভাইসে অবস্থান সুবিধা পাওয়া যাচ্ছে না।");
      return;
    }
    setError("");
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        update("latitude", coords.latitude.toFixed(7));
        update("longitude", coords.longitude.toFixed(7));
        setSaved(false);
      },
      () => setError("অবস্থান পাওয়া যায়নি। ব্রাউজারে Location Permission দিন।"),
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 60000 }
    );
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(""); setSaved(false);
    if (!shop.shop_name.trim() || !shop.slug.trim()) {
      setError("চেম্বার/হাসপাতালের নাম ও লিংক অবশ্যই দিতে হবে।"); return;
    }
    setSaving(true);
    try {
      const payload = {
        ...shop,
        owner_id: user.id,
        slug: slugify(shop.slug),
        chamber_name: shop.chamber_name || shop.shop_name,
        latitude: shop.latitude === "" ? null : Number(shop.latitude),
        longitude: shop.longitude === "" ? null : Number(shop.longitude),
        consultation_fee: shop.consultation_fee === "" ? null : Number(shop.consultation_fee)
      };
      const { data, error: saveError } = shopId
        ? await supabase.from("shops").update(payload).eq("id", shopId).select().single()
        : await supabase.from("shops").insert(payload).select().single();
      if (saveError) {
        if (saveError.message.toLowerCase().includes("row-level security"))
          setError("অনুমতি নেই — Doctor account Approved হওয়ার পর চেম্বার তৈরি/আপডেট করা যাবে।");
        else if (saveError.message.includes("duplicate"))
          setError("এই লিংকটি অন্য একটি চেম্বার ব্যবহার করছে।");
        else setError("সংরক্ষণ ব্যর্থ হয়েছে: " + saveError.message);
        return;
      }
      setShop({ ...EMPTY, ...data }); setShopId(data.id); setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } finally { setSaving(false); }
  };

  if (loading) return <LoadingSpinner label="চেম্বার/হাসপাতালের তথ্য লোড হচ্ছে..." />;

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>চেম্বার / হাসপাতালের সেটিংস</h1>
        <p className="text-sm text-muted-foreground">আপনার চেম্বার-এর পাবলিক তথ্য এখান থেকে পরিচালনা করুন।</p>
      </div>

      {shopId && (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-primary/30 bg-secondary/60 p-4 text-sm">
          <span>চেম্বার লিংক: <span className="font-medium text-primary">/shop/{shop.slug}</span></span>
          <div className="flex items-center gap-2">
            <ShareShopButton shop={shop} variant="ghost" />
            <Button variant="ghost" size="sm" asChild>
              <Link to={shopPath(shop.slug)} target="_blank">দেখুন <ExternalLink className="h-3.5 w-3.5" /></Link>
            </Button>
          </div>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-5">
        <Card>
          <CardHeader><CardTitle className="text-base">চেম্বারের ব্র্যান্ডিং</CardTitle><CardDescription>লোগো ও ব্যানার চেম্বারের পাবলিক পেজে দেখাবে।</CardDescription></CardHeader>
          <CardContent className="flex flex-wrap gap-6">
            <div><Label className="mb-2 block">চেম্বারের লোগো</Label>
              <ImageUploader bucket="shop-logos" folder={user.id} value={shop.logo_url} onUploaded={url => update("logo_url", url)} />
            </div>
            <div className="min-w-[220px] flex-1"><Label className="mb-2 block">ব্যানার</Label>
              <ImageUploader bucket="shop-banners" folder={user.id} value={shop.banner_url} onUploaded={url => update("banner_url", url)} aspect="wide" />
            </div>
          </CardContent>
        </Card>

        {role === "hospital" && (
          <Card>
            <CardHeader className="pb-3"><CardTitle className="text-base">হাসপাতালের প্রোফাইল ছবি</CardTitle><CardDescription>এখানে আপনার হাসপাতালের প্রোফাইল/ভবনের সর্বোচ্চ ৪টি ছবি আপলোড করুন। রোগীরা হাসপাতালের পেজ খুললে ছবিগুলো সবার উপরে বড় করে দেখতে পারবে। প্রতিটি ছবি সর্বোচ্চ ১ MB; সিস্টেম স্বয়ংক্রিয়ভাবে কমপ্রেস করবে।</CardDescription></CardHeader>
            <CardContent className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {Array.from({length:4}).map((_,i)=>(
                <div key={i}>
                  <p className="mb-1 text-xs font-semibold text-muted-foreground">ছবি {i+1}</p>
                  <ImageUploader bucket="shop-banners" folder={`${user.id}/hospital`} value={shop.hospital_photo_urls?.[i] || ""} onUploaded={url=>{ const next=[...(shop.hospital_photo_urls||[])]; next[i]=url; update("hospital_photo_urls",next); }} aspect="wide" maxSizeKB={1024} />
                </div>
              ))}
            </CardContent>
          </Card>
        )}

        <Card>
          <CardHeader><CardTitle className="text-base">{role === "hospital" ? "চেম্বার / হাসপাতালের তথ্য" : "চেম্বারের তথ্য"}</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div><Label>চেম্বারের নাম *</Label><Input required value={shop.shop_name} onChange={e => handleName(e.target.value)} /></div>
              <div><Label>চেম্বারের ধরন</Label><Input placeholder="ব্যক্তিগত চেম্বার / ক্লিনিক" value={shop.chamber_type || ""} onChange={e => update("chamber_type", e.target.value)} /></div>
            </div>
            <div><Label>চেম্বারের লিংক *</Label><Input required value={shop.slug} onChange={e => { setSlugEdited(true); update("slug", e.target.value); }} /></div>
            <div><Label>চেম্বার সম্পর্কে</Label><textarea rows={3} value={shop.about || ""} onChange={e => update("about", e.target.value)} className="flex w-full rounded-lg border border-input bg-card px-3 py-2 text-sm" /></div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle className="text-base">সময়সূচি ও পরামর্শ</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div><Label>রোগী দেখার দিন</Label><Input placeholder="শনি, রবি, সোম" value={shop.visiting_days || ""} onChange={e => update("visiting_days", e.target.value)} /></div>
              <div><Label>রোগী দেখার সময়</Label><Input placeholder="বিকেল ৫টা – রাত ৯টা" value={shop.visiting_time || ""} onChange={e => update("visiting_time", e.target.value)} /></div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div><Label>পরামর্শ ফি (৳)</Label><Input type="number" min="0" value={shop.consultation_fee || ""} onChange={e => update("consultation_fee", e.target.value)} /></div>
              <div><Label>সহকারীর ফোন</Label><Input value={shop.assistant_phone || ""} onChange={e => update("assistant_phone", e.target.value)} /></div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle className="text-base">চেম্বার / হাসপাতালের যোগাযোগ ও অবস্থান</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div><Label>ফোন</Label><Input value={shop.phone || ""} onChange={e => update("phone", e.target.value)} /></div>
              <div><Label>হোয়াটসঅ্যাপ</Label><Input value={shop.whatsapp_number || ""} onChange={e => update("whatsapp_number", e.target.value)} /></div>
            </div>
            <div><Label>ঠিকানা</Label><Input value={shop.address || ""} onChange={e => update("address", e.target.value)} /></div>
            <div className="rounded-xl border border-primary/15 bg-primary/5 p-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <p className="text-sm font-semibold">চেম্বারের সঠিক অবস্থান</p>
                  <p className="mt-0.5 text-xs text-muted-foreground">রোগীর অবস্থান থেকে দূরত্ব দেখানোর জন্য এই অবস্থান ব্যবহার হবে।</p>
                </div>
                <Button type="button" variant="outline" size="sm" onClick={useCurrentLocation}>
                  <Navigation className="h-4 w-4" /> বর্তমান অবস্থান ব্যবহার করুন
                </Button>
              </div>
              <div className="mt-3 grid gap-3 sm:grid-cols-2">
                <div><Label>Latitude</Label><Input type="number" step="any" value={shop.latitude || ""} onChange={e => update("latitude", e.target.value)} placeholder="24.4539" /></div>
                <div><Label>Longitude</Label><Input type="number" step="any" value={shop.longitude || ""} onChange={e => update("longitude", e.target.value)} placeholder="89.7000" /></div>
              </div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <Label>জেলা</Label>
                <select
                  value={shop.district || "সিরাজগঞ্জ"}
                  onChange={e => update("district", e.target.value)}
                  className="mt-1 h-10 w-full rounded-lg border border-input bg-card px-3 text-sm"
                >
                  <option value="সিরাজগঞ্জ">সিরাজগঞ্জ</option>
                </select>
              </div>
              <div>
                <Label>উপজেলা</Label>
                <select
                  value={shop.upazila || ""}
                  onChange={e => update("upazila", e.target.value)}
                  className="mt-1 h-10 w-full rounded-lg border border-input bg-card px-3 text-sm"
                >
                  <option value="">উপজেলা নির্বাচন করুন</option>
                  <option>সিরাজগঞ্জ সদর</option>
                  <option>বেলকুচি</option>
                  <option>চৌহালী</option>
                  <option>কামারখন্দ</option>
                  <option>কাজীপুর</option>
                  <option>রায়গঞ্জ</option>
                  <option>শাহজাদপুর</option>
                  <option>তাড়াশ</option>
                  <option>উল্লাপাড়া</option>
                </select>
              </div>
            </div>
            <div><Label>গুগল ম্যাপ লিংক</Label><Input value={shop.google_map_link || ""} onChange={e => update("google_map_link", e.target.value)} /></div>
            <div><Label>ফেসবুক লিংক</Label><Input value={shop.facebook_link || ""} onChange={e => update("facebook_link", e.target.value)} /></div>
          </CardContent>
        </Card>

        {error && <p className="text-sm text-destructive">{error}</p>}
        <Button type="submit" disabled={saving} size="lg">
          {saved ? <Check className="h-4 w-4" /> : <Save className="h-4 w-4" />}
          {saving ? "সংরক্ষণ হচ্ছে..." : saved ? "সংরক্ষিত হয়েছে" : "চেম্বার / হাসপাতালের সেটিংস সংরক্ষণ করুন"}
        </Button>
      </form>

      <div className="pt-2">
        <div className="mb-4">
          <h2 className="text-lg font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>ডাক্তারের প্রোফাইল</h2>
          <p className="text-sm text-muted-foreground">চেম্বার / হাসপাতালের তথ্যের নিচেই আপনার পাবলিক ডাক্তার প্রোফাইল সম্পূর্ণ করুন।</p>
        </div>
        <ProductEditPage embedded />
      </div>
    </div>
  );
}
