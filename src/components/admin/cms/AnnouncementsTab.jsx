import { useEffect, useState } from "react";
import { Plus, X, Pencil, Trash2, Megaphone, Eye, EyeOff, AlertCircle } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import { validateUrl } from "@/components/admin/cms/validators.js";

const EMPTY = { message: "", link_text: "", link_url: "", sort_order: 0, is_active: true };

export default function AnnouncementsTab() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    const { data } = await supabase.from("announcements").select("*").order("sort_order", { ascending: true });
    setItems(data ?? []);
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

  const openEditForm = (item) => {
    setEditingId(item.id);
    setForm({
      message: item.message,
      link_text: item.link_text || "",
      link_url: item.link_url || "",
      sort_order: item.sort_order,
      is_active: item.is_active,
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

    if (!form.message.trim()) {
      setError("নোটিশের লেখা আবশ্যক।");
      return;
    }
    if (form.message.trim().length > 300) {
      setError("নোটিশের লেখা সর্বোচ্চ ৩০০ অক্ষরের মধ্যে হতে হবে।");
      return;
    }
    if (form.link_url.trim()) {
      const urlError = validateUrl(form.link_url.trim());
      if (urlError) {
        setError(urlError);
        return;
      }
    }

    setSaving(true);
    const payload = {
      message: form.message.trim(),
      link_text: form.link_text.trim() || null,
      link_url: form.link_url.trim() || null,
      sort_order: Number(form.sort_order) || 0,
      is_active: !!form.is_active,
    };

    const { error: saveError } = editingId
      ? await supabase.from("announcements").update(payload).eq("id", editingId)
      : await supabase.from("announcements").insert(payload);

    setSaving(false);
    if (saveError) {
      setError("সংরক্ষণ ব্যর্থ হয়েছে: " + saveError.message);
      return;
    }
    closeForm();
    load();
  };

  const toggleActive = async (item) => {
    await supabase.from("announcements").update({ is_active: !item.is_active }).eq("id", item.id);
    load();
  };

  const handleDelete = async (id) => {
    if (!window.confirm("এই নোটিশটি মুছে ফেলতে চান?")) return;
    await supabase.from("announcements").delete().eq("id", id);
    load();
  };

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3 rounded-xl border border-border bg-card p-5">
        <div>
          <h2 className="text-base font-semibold">অ্যানাউন্সমেন্ট / নোটিশ বার</h2>
          <p className="mt-0.5 text-sm text-muted-foreground">
            সাইটের উপরে প্রদর্শিত হবে এমন গুরুত্বপূর্ণ নোটিশ যোগ করুন — একাধিক সক্রিয় থাকলে সিরিয়াল অনুযায়ী দেখাবে।
          </p>
        </div>
        <Button size="sm" onClick={showForm ? closeForm : openAddForm}>
          {showForm ? <X className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
          {showForm ? "বাতিল" : "নতুন নোটিশ"}
        </Button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="space-y-4 rounded-xl border border-border bg-card p-5">
          <div className="space-y-1.5">
            <Label htmlFor="an_message">নোটিশের লেখা *</Label>
            <Textarea
              id="an_message"
              rows={2}
              placeholder="যেমন: ঈদ উপলক্ষে সকল ডাক্তার প্রোফাইলে ২০% ছাড়!"
              value={form.message}
              onChange={(e) => setForm((f) => ({ ...f, message: e.target.value }))}
            />
            <p className="text-right text-xs text-muted-foreground">{form.message.length}/300</p>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="an_link_text">বাটন/লিংকের লেখা (ঐচ্ছিক)</Label>
              <Input
                id="an_link_text"
                placeholder="যেমন: বিস্তারিত দেখুন"
                value={form.link_text}
                onChange={(e) => setForm((f) => ({ ...f, link_text: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="an_link_url">লিংক (ঐচ্ছিক)</Label>
              <Input
                id="an_link_url"
                placeholder="/search অথবা https://..."
                value={form.link_url}
                onChange={(e) => setForm((f) => ({ ...f, link_url: e.target.value }))}
              />
            </div>
          </div>

          <div className="space-y-1.5 max-w-[160px]">
            <Label htmlFor="an_order">সিরিয়াল নম্বর</Label>
            <Input
              id="an_order"
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
            {saving ? "সংরক্ষণ হচ্ছে..." : editingId ? "আপডেট করুন" : "যোগ করুন"}
          </Button>
        </form>
      )}

      {items.length === 0 ? (
        <EmptyState icon={Megaphone} title="এখনো কোনো নোটিশ যোগ করা হয়নি" />
      ) : (
        <div className="divide-y divide-border rounded-xl border border-border bg-card">
          {items.map((item) => (
            <div key={item.id} className="flex items-center justify-between gap-3 p-4">
              <div className="min-w-0">
                <p className="truncate text-sm font-medium">{item.message}</p>
                {item.link_url && (
                  <p className="truncate text-xs text-muted-foreground">
                    {item.link_text || "লিংক"} → {item.link_url}
                  </p>
                )}
              </div>
              <div className="flex shrink-0 gap-1.5">
                <Button variant="ghost" size="icon" onClick={() => toggleActive(item)} title={item.is_active ? "নিষ্ক্রিয় করুন" : "সক্রিয় করুন"}>
                  {item.is_active ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                </Button>
                <Button variant="ghost" size="icon" onClick={() => openEditForm(item)} title="এডিট করুন">
                  <Pencil className="h-4 w-4" />
                </Button>
                <Button variant="ghost" size="icon" onClick={() => handleDelete(item.id)} title="মুছুন">
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
