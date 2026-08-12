import { useEffect, useState } from "react";
import { Plus, X, Pencil, Trash2, Share2, Eye, EyeOff, AlertCircle } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import { validateUrl } from "@/components/admin/cms/validators.js";

const PLATFORMS = [
  { value: "facebook", label: "Facebook" },
  { value: "instagram", label: "Instagram" },
  { value: "youtube", label: "YouTube" },
  { value: "whatsapp", label: "WhatsApp" },
  { value: "tiktok", label: "TikTok" },
  { value: "twitter", label: "Twitter / X" },
  { value: "linkedin", label: "LinkedIn" },
  { value: "telegram", label: "Telegram" },
  { value: "custom", label: "অন্যান্য (কাস্টম)" },
];

const EMPTY = { platform: "facebook", label: "", url: "", sort_order: 0, is_active: true };

export default function SocialLinksTab() {
  const [links, setLinks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    const { data } = await supabase.from("social_links").select("*").order("sort_order", { ascending: true });
    setLinks(data ?? []);
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

  const openEditForm = (link) => {
    setEditingId(link.id);
    setForm({
      platform: link.platform,
      label: link.label || "",
      url: link.url,
      sort_order: link.sort_order,
      is_active: link.is_active,
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

    if (!form.url.trim()) {
      setError("লিংক আবশ্যক।");
      return;
    }
    const urlError = validateUrl(form.url.trim());
    if (urlError) {
      setError(urlError);
      return;
    }
    if (form.platform === "custom" && !form.label.trim()) {
      setError("কাস্টম প্ল্যাটফর্মের জন্য একটি নাম দিন।");
      return;
    }

    setSaving(true);
    const payload = {
      platform: form.platform,
      label: form.label.trim() || null,
      url: form.url.trim(),
      sort_order: Number(form.sort_order) || 0,
      is_active: !!form.is_active,
    };

    const { error: saveError } = editingId
      ? await supabase.from("social_links").update(payload).eq("id", editingId)
      : await supabase.from("social_links").insert(payload);

    setSaving(false);
    if (saveError) {
      setError("সংরক্ষণ ব্যর্থ হয়েছে: " + saveError.message);
      return;
    }
    closeForm();
    load();
  };

  const toggleActive = async (link) => {
    await supabase.from("social_links").update({ is_active: !link.is_active }).eq("id", link.id);
    load();
  };

  const handleDelete = async (id) => {
    if (!window.confirm("এই সোশ্যাল মিডিয়া লিংকটি মুছে ফেলতে চান?")) return;
    await supabase.from("social_links").delete().eq("id", id);
    load();
  };

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3 rounded-xl border border-border bg-card p-5">
        <div>
          <h2 className="text-base font-semibold">সোশ্যাল মিডিয়া লিংক</h2>
          <p className="mt-0.5 text-sm text-muted-foreground">
            ফেসবুক, ইনস্টাগ্রাম, হোয়াটসঅ্যাপ ইত্যাদি লিংক যোগ করুন — ফুটার/হেডারে প্রদর্শিত হবে।
          </p>
        </div>
        <Button size="sm" onClick={showForm ? closeForm : openAddForm}>
          {showForm ? <X className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
          {showForm ? "বাতিল" : "নতুন লিংক"}
        </Button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="space-y-4 rounded-xl border border-border bg-card p-5">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="sl_platform">প্ল্যাটফর্ম *</Label>
              <select
                id="sl_platform"
                value={form.platform}
                onChange={(e) => setForm((f) => ({ ...f, platform: e.target.value }))}
                className="flex h-10 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                {PLATFORMS.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="sl_order">সিরিয়াল নম্বর (Sort Order)</Label>
              <Input
                id="sl_order"
                type="number"
                value={form.sort_order}
                onChange={(e) => setForm((f) => ({ ...f, sort_order: e.target.value }))}
              />
            </div>
          </div>

          {form.platform === "custom" && (
            <div className="space-y-1.5">
              <Label htmlFor="sl_label">নাম *</Label>
              <Input
                id="sl_label"
                placeholder="যেমন: Pinterest"
                value={form.label}
                onChange={(e) => setForm((f) => ({ ...f, label: e.target.value }))}
              />
            </div>
          )}

          <div className="space-y-1.5">
            <Label htmlFor="sl_url">লিংক (URL) *</Label>
            <Input
              id="sl_url"
              placeholder="https://facebook.com/yourpage"
              value={form.url}
              onChange={(e) => setForm((f) => ({ ...f, url: e.target.value }))}
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
            {saving ? "সংরক্ষণ হচ্ছে..." : editingId ? "আপডেট করুন" : "যোগ করুন"}
          </Button>
        </form>
      )}

      {links.length === 0 ? (
        <EmptyState icon={Share2} title="এখনো কোনো সোশ্যাল মিডিয়া লিংক যোগ করা হয়নি" />
      ) : (
        <div className="divide-y divide-border rounded-xl border border-border bg-card">
          {links.map((link) => (
            <div key={link.id} className="flex items-center justify-between gap-3 p-4">
              <div className="min-w-0">
                <p className="truncate text-sm font-medium">
                  {PLATFORMS.find((p) => p.value === link.platform)?.label || link.label || link.platform}
                  {link.platform === "custom" && link.label ? ` — ${link.label}` : ""}
                </p>
                <p className="truncate text-xs text-muted-foreground">{link.url}</p>
              </div>
              <div className="flex shrink-0 gap-1.5">
                <Button variant="ghost" size="icon" onClick={() => toggleActive(link)} title={link.is_active ? "নিষ্ক্রিয় করুন" : "সক্রিয় করুন"}>
                  {link.is_active ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                </Button>
                <Button variant="ghost" size="icon" onClick={() => openEditForm(link)} title="এডিট করুন">
                  <Pencil className="h-4 w-4" />
                </Button>
                <Button variant="ghost" size="icon" onClick={() => handleDelete(link.id)} title="মুছুন">
                  <Trash2 className="h-4 w-4 text-destructive" />
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
