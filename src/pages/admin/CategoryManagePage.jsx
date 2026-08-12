import { useEffect, useState } from "react";
import { Plus, Trash2, Pencil, X, FolderTree } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { slugify } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

const EMPTY = { name: "", slug: "", icon_url: "", sort_order: 0, parent_id: "" };

export default function CategoryManagePage() {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(EMPTY);
  const [editingId, setEditingId] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    const { data } = await supabase.from("categories").select("*").order("sort_order", { ascending: true });
    setCategories(data ?? []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openNew = () => {
    setForm(EMPTY);
    setEditingId(null);
    setShowForm(true);
  };

  const openEdit = (cat) => {
    setForm({ ...cat, parent_id: cat.parent_id || "" });
    setEditingId(cat.id);
    setShowForm(true);
  };

  const openNewSub = (parentId) => {
    setForm({ ...EMPTY, parent_id: parentId });
    setEditingId(null);
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (!form.name.trim()) {
      setError("ক্যাটাগরির নাম দিন।");
      return;
    }
    setSaving(true);
    const payload = {
      ...form,
      slug: slugify(form.slug || form.name),
      sort_order: Number(form.sort_order) || 0,
      parent_id: form.parent_id || null,
    };

    const { error: saveError } = editingId
      ? await supabase.from("categories").update(payload).eq("id", editingId)
      : await supabase.from("categories").insert(payload);

    setSaving(false);
    if (saveError) {
      setError("সংরক্ষণ ব্যর্থ হয়েছে: " + saveError.message);
      return;
    }
    setShowForm(false);
    load();
  };

  const handleDelete = async (id) => {
    if (!window.confirm("এই ক্যাটাগরি মুছে ফেললে এর অধীনে থাকা সাব-ক্যাটাগরিও মুছে যাবে এবং এর অধীনে থাকা ডাক্তার প্রোফাইলগুলোর ক্যাটাগরি ফাঁকা হয়ে যাবে। নিশ্চিত?")) return;
    await supabase.from("categories").delete().eq("id", id);
    load();
  };

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          ক্যাটাগরি ম্যানেজমেন্ট
        </h1>
        <Button size="sm" onClick={openNew}>
          <Plus className="h-4 w-4" /> নতুন ক্যাটাগরি
        </Button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="space-y-4 rounded-xl border border-border bg-card p-5">
          <div className="flex items-center justify-between">
            <h3 className="font-semibold">{editingId ? "ক্যাটাগরি এডিট করুন" : "নতুন ক্যাটাগরি"}</h3>
            <button type="button" onClick={() => setShowForm(false)}>
              <X className="h-4 w-4 text-muted-foreground" />
            </button>
          </div>
          <div className="flex flex-wrap items-start gap-6">
            <div>
              <Label className="mb-2 block">আইকন</Label>
              <ImageUploader
                bucket="site-assets"
                folder="categories"
                value={form.icon_url}
                onUploaded={(url) => setForm((f) => ({ ...f, icon_url: url }))}
              />
            </div>
            <div className="flex-1 min-w-[200px] space-y-3">
              <div className="space-y-1.5">
                <Label htmlFor="cat_name">নাম *</Label>
                <Input id="cat_name" required value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="cat_parent">প্যারেন্ট ক্যাটাগরি (ঐচ্ছিক — সাব-ক্যাটাগরি বানাতে নির্বাচন করুন)</Label>
                <select
                  id="cat_parent"
                  value={form.parent_id || ""}
                  onChange={(e) => setForm((f) => ({ ...f, parent_id: e.target.value }))}
                  className="flex h-10 w-full rounded-lg border border-input bg-card px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <option value="">— মূল ক্যাটাগরি (কোনো প্যারেন্ট নেই) —</option>
                  {categories
                    .filter((c) => !c.parent_id && c.id !== editingId)
                    .map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="cat_order">ক্রম (Sort Order)</Label>
                <Input
                  id="cat_order"
                  type="number"
                  value={form.sort_order}
                  onChange={(e) => setForm((f) => ({ ...f, sort_order: e.target.value }))}
                />
              </div>
            </div>
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" disabled={saving}>
            {saving ? "সংরক্ষণ হচ্ছে..." : "সংরক্ষণ করুন"}
          </Button>
        </form>
      )}

      {categories.length === 0 ? (
        <EmptyState icon={FolderTree} title="এখনো কোনো ক্যাটাগরি যোগ করা হয়নি" />
      ) : (
        <div className="space-y-5">
          {categories
            .filter((c) => !c.parent_id)
            .map((root) => {
              const children = categories.filter((c) => c.parent_id === root.id);
              return (
                <div key={root.id} className="space-y-2">
                  <div className="flex items-center gap-3 rounded-xl border border-primary/30 bg-secondary/50 p-3">
                    <div className="h-10 w-10 shrink-0 overflow-hidden rounded-full bg-secondary">
                      {root.icon_url && <img src={root.icon_url} alt="" className="h-full w-full object-cover" />}
                    </div>
                    <span className="flex-1 truncate text-sm font-semibold">{root.name}</span>
                    <button onClick={() => openNewSub(root.id)} title="সাব-ক্যাটাগরি যোগ করুন">
                      <Plus className="h-3.5 w-3.5 text-muted-foreground" />
                    </button>
                    <button onClick={() => openEdit(root)}>
                      <Pencil className="h-3.5 w-3.5 text-muted-foreground" />
                    </button>
                    <button onClick={() => handleDelete(root.id)}>
                      <Trash2 className="h-3.5 w-3.5 text-destructive" />
                    </button>
                  </div>
                  {children.length > 0 && (
                    <div className="ml-6 grid grid-cols-2 gap-2 sm:grid-cols-3 md:grid-cols-4">
                      {children.map((cat) => (
                        <div key={cat.id} className="flex items-center gap-2 rounded-lg border border-border bg-card p-2.5">
                          <span className="flex-1 truncate text-xs font-medium">— {cat.name}</span>
                          <button onClick={() => openEdit(cat)}>
                            <Pencil className="h-3 w-3 text-muted-foreground" />
                          </button>
                          <button onClick={() => handleDelete(cat.id)}>
                            <Trash2 className="h-3 w-3 text-destructive" />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
        </div>
      )}
    </div>
  );
}
