import { useEffect, useState } from "react";
import { Plus, Trash2, Pencil, X, GalleryHorizontal, Eye, EyeOff, AlertCircle } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

const EMPTY = { title: "", image_url: "", link_url: "", sort_order: 0, is_active: true };

/**
 * হোমপেজ ব্যানার/স্লাইডার ম্যানেজমেন্ট — Add, Edit, Delete সবই সাপোর্ট করে।
 * এই কম্পোনেন্টটি standalone route (/admin/banners) এবং Super Admin CMS
 * প্যানেলের "ব্যানার/স্লাইডার" ট্যাব — দুই জায়গাতেই ব্যবহৃত হয়।
 */
export default function BannerManagePage() {
  const [banners, setBanners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    const { data } = await supabase.from("banners").select("*").order("sort_order", { ascending: true });
    setBanners(data ?? []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openAddForm = () => {
    setEditingId(null);
    setForm(EMPTY);
    setError("");
    setShowForm(true);
  };

  const openEditForm = (banner) => {
    setEditingId(banner.id);
    setForm({
      title: banner.title || "",
      image_url: banner.image_url,
      link_url: banner.link_url || "",
      sort_order: banner.sort_order,
      is_active: banner.is_active,
    });
    setError("");
    setShowForm(true);
  };

  const closeForm = () => {
    setShowForm(false);
    setEditingId(null);
    setForm(EMPTY);
    setError("");
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (!form.image_url) {
      setError("ব্যানারের ছবি আপলোড করুন।");
      return;
    }
    setSaving(true);
    const payload = {
      title: form.title.trim() || null,
      image_url: form.image_url,
      link_url: form.link_url.trim() || null,
      sort_order: Number(form.sort_order) || 0,
      is_active: !!form.is_active,
    };

    const { error: saveError } = editingId
      ? await supabase.from("banners").update(payload).eq("id", editingId)
      : await supabase.from("banners").insert(payload);

    setSaving(false);
    if (saveError) {
      setError("সংরক্ষণ ব্যর্থ হয়েছে: " + saveError.message);
      return;
    }
    closeForm();
    load();
  };

  const toggleActive = async (banner) => {
    await supabase.from("banners").update({ is_active: !banner.is_active }).eq("id", banner.id);
    load();
  };

  const handleDelete = async (id) => {
    if (!window.confirm("এই ব্যানারটি মুছে ফেলতে চান?")) return;
    await supabase.from("banners").delete().eq("id", id);
    load();
  };

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3 rounded-xl border border-border bg-card p-5">
        <div>
          <h2 className="text-base font-semibold">হোমপেজ ব্যানার / স্লাইডার</h2>
          <p className="mt-0.5 text-sm text-muted-foreground">
            হোমপেজের উপরে প্রদর্শিত স্লাইডিং ব্যানার ছবিগুলো এখান থেকে নিয়ন্ত্রণ করুন।
          </p>
        </div>
        <Button size="sm" onClick={showForm ? closeForm : openAddForm}>
          {showForm ? <X className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
          {showForm ? "বাতিল" : "নতুন ব্যানার"}
        </Button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="space-y-4 rounded-xl border border-border bg-card p-5">
          <div>
            <Label className="mb-2 block">ব্যানার ছবি *</Label>
            <ImageUploader
              bucket="site-assets"
              folder="banners"
              value={form.image_url}
              onUploaded={(url) => setForm((f) => ({ ...f, image_url: url }))}
              aspect="wide"
            />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="banner_title">শিরোনাম (ঐচ্ছিক)</Label>
              <Input id="banner_title" value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="banner_link">লিংক (ঐচ্ছিক)</Label>
              <Input id="banner_link" value={form.link_url} onChange={(e) => setForm((f) => ({ ...f, link_url: e.target.value }))} />
            </div>
          </div>
          <div className="space-y-1.5 max-w-[160px]">
            <Label htmlFor="banner_order">সিরিয়াল নম্বর</Label>
            <Input
              id="banner_order"
              type="number"
              value={form.sort_order}
              onChange={(e) => setForm((f) => ({ ...f, sort_order: e.target.value }))}
            />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
              className="h-4 w-4 rounded border-input"
            />
            সক্রিয় (ওয়েবসাইটে প্রদর্শিত হবে)
          </label>
          {error && (
            <p className="flex items-start gap-1.5 text-sm text-destructive">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
              {error}
            </p>
          )}
          <Button type="submit" disabled={saving}>
            {saving ? "সংরক্ষণ হচ্ছে..." : editingId ? "আপডেট করুন" : "সংরক্ষণ করুন"}
          </Button>
        </form>
      )}

      {banners.length === 0 ? (
        <EmptyState icon={GalleryHorizontal} title="এখনো কোনো ব্যানার যোগ করা হয়নি" />
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {banners.map((b) => (
            <div key={b.id} className="overflow-hidden rounded-xl border border-border bg-card">
              <img src={b.image_url} alt={b.title || ""} className="h-32 w-full object-cover" />
              <div className="flex items-center justify-between p-3">
                <span className="truncate text-sm font-medium">{b.title || "শিরোনামহীন"}</span>
                <div className="flex gap-1.5">
                  <Button variant="ghost" size="icon" onClick={() => toggleActive(b)} title={b.is_active ? "নিষ্ক্রিয় করুন" : "সক্রিয় করুন"}>
                    {b.is_active ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                  </Button>
                  <Button variant="ghost" size="icon" onClick={() => openEditForm(b)} title="এডিট করুন">
                    <Pencil className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="icon" onClick={() => handleDelete(b.id)} title="মুছুন">
                    <Trash2 className="h-4 w-4 text-destructive" />
                  </Button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
