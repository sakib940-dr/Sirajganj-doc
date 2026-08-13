import { useEffect, useState } from "react";
import { Save, ExternalLink, Globe2, Eye } from "lucide-react";
import { Link } from "react-router-dom";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { shopPath } from "@/constants/routes";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

const DEFAULT_CONFIG = {
  enabled: true,
  hero_title: "",
  hero_subtitle: "সিরাজগঞ্জের রোগীদের জন্য বিশ্বস্ত চিকিৎসা সেবা",
  about_title: "আমাদের সম্পর্কে",
  contact_title: "যোগাযোগ ও দিকনির্দেশনা",
  show_doctors: true,
  show_gallery: true,
  show_about: true,
  cta_text: "অ্যাপয়েন্টমেন্ট নিন",
};

export default function WebsiteBuilderPage() {
  const { user } = useAuth();
  const [shop, setShop] = useState(null);
  const [config, setConfig] = useState(DEFAULT_CONFIG);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!user) return;
    supabase.from("shops").select("*").eq("owner_id", user.id).maybeSingle().then(({ data }) => {
      setShop(data || null);
      setConfig({ ...DEFAULT_CONFIG, ...(data?.website_config || {}), hero_title: data?.website_config?.hero_title || data?.shop_name || "" });
      setLoading(false);
    });
  }, [user]);

  const update = (key, value) => setConfig(prev => ({ ...prev, [key]: value }));

  const save = async () => {
    if (!shop?.id) return;
    setSaving(true); setMessage("");
    const { error } = await supabase.from("shops").update({ website_config: config }).eq("id", shop.id);
    if (error) setMessage("সংরক্ষণ করা যায়নি: " + error.message);
    else setMessage("ওয়েবসাইটের পরিবর্তন সংরক্ষিত হয়েছে।");
    setSaving(false);
  };

  if (loading) return <LoadingSpinner label="ওয়েবসাইট বিল্ডার লোড হচ্ছে..." />;

  if (!shop) return (
    <div className="max-w-2xl rounded-2xl border bg-card p-6">
      <h1 className="text-xl font-bold">ওয়েবসাইট বিল্ডার</h1>
      <p className="mt-2 text-sm text-muted-foreground">আগে চেম্বার / হাসপাতালের তথ্য সংরক্ষণ করুন। তারপর এখান থেকে পাবলিক ওয়েবসাইট সাজাতে পারবেন।</p>
    </div>
  );

  return (
    <div className="max-w-3xl space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>ওয়েবসাইট বিল্ডার</h1>
          <p className="text-sm text-muted-foreground">আপনার চেম্বার / হাসপাতালের পাবলিক পেজের লেখা ও সেকশন সাজান।</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" asChild>
            <Link to={shopPath(shop.slug)} target="_blank"><Eye className="h-4 w-4" /> প্রিভিউ</Link>
          </Button>
          <Button onClick={save} disabled={saving}><Save className="h-4 w-4" /> {saving ? "সংরক্ষণ হচ্ছে..." : "সংরক্ষণ করুন"}</Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base"><Globe2 className="h-4 w-4" /> পাবলিক ওয়েবসাইট</CardTitle>
          <CardDescription>এই সেটিংস আপনার চেম্বার / হাসপাতালের পাবলিক পেজে দেখা যাবে।</CardDescription>
        </CardHeader>
        <CardContent className="space-y-5">
          <label className="flex items-center justify-between rounded-xl border p-4">
            <div><p className="font-medium">ওয়েবসাইট সক্রিয়</p><p className="text-xs text-muted-foreground">পাবলিক চেম্বার পেজ চালু রাখুন</p></div>
            <input type="checkbox" checked={!!config.enabled} onChange={e => update("enabled", e.target.checked)} className="h-5 w-5 accent-primary" />
          </label>

          <div>
            <Label>প্রধান শিরোনাম</Label>
            <Input value={config.hero_title} onChange={e => update("hero_title", e.target.value)} placeholder="যেমন: সিরাজগঞ্জ আই কেয়ার হাসপাতাল" />
          </div>
          <div>
            <Label>শিরোনামের নিচের লেখা</Label>
            <Input value={config.hero_subtitle} onChange={e => update("hero_subtitle", e.target.value)} placeholder="বিশ্বস্ত চিকিৎসা সেবা, এক জায়গায়" />
          </div>
          <div>
            <Label>পরিচিতি সেকশনের শিরোনাম</Label>
            <Input value={config.about_title} onChange={e => update("about_title", e.target.value)} placeholder="আমাদের সম্পর্কে" />
          </div>
          <div>
            <Label>যোগাযোগ সেকশনের শিরোনাম</Label>
            <Input value={config.contact_title} onChange={e => update("contact_title", e.target.value)} placeholder="যোগাযোগ ও দিকনির্দেশনা" />
          </div>
          <div>
            <Label>অ্যাপয়েন্টমেন্ট বাটনের লেখা</Label>
            <Input value={config.cta_text} onChange={e => update("cta_text", e.target.value)} placeholder="অ্যাপয়েন্টমেন্ট নিন" />
          </div>

          <div className="grid gap-3 sm:grid-cols-3">
            {[
              ["show_about", "পরিচিতি দেখান"],
              ["show_doctors", "ডাক্তার দেখান"],
              ["show_gallery", "গ্যালারি দেখান"],
            ].map(([key, label]) => (
              <label key={key} className="flex items-center gap-2 rounded-xl border p-3 text-sm">
                <input type="checkbox" checked={!!config[key]} onChange={e => update(key, e.target.checked)} className="h-4 w-4 accent-primary" />
                {label}
              </label>
            ))}
          </div>

          {message && <p className="rounded-lg bg-secondary p-3 text-sm">{message}</p>}
        </CardContent>
      </Card>
    </div>
  );
}
