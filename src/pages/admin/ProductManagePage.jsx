import { useEffect, useState } from "react";
import { Package, Eye, EyeOff, Trash2 } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import { formatPriceBn, getDiscountedPrice } from "@/lib/utils";

export default function ProductManagePage() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);

  const load = async () => {
    setLoading(true);
    const { data } = await supabase
      .from("products")
      .select("*, shops:shop_id ( shop_name )")
      .order("created_at", { ascending: false });
    setProducts(data ?? []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const toggleActive = async (product) => {
    setBusyId(product.id);
    await supabase.from("products").update({ is_active: !product.is_active }).eq("id", product.id);
    setProducts((prev) => prev.map((p) => (p.id === product.id ? { ...p, is_active: !p.is_active } : p)));
    setBusyId(null);
  };

  const handleDelete = async (id) => {
    if (!window.confirm("এই ডাক্তার প্রোফাইলটি স্থায়ীভাবে মুছে ফেলতে চান?")) return;
    setBusyId(id);
    await supabase.from("products").delete().eq("id", id);
    setProducts((prev) => prev.filter((p) => p.id !== id));
    setBusyId(null);
  };

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  if (products.length === 0) {
    return <EmptyState icon={Package} title="এখনো কোনো ডাক্তার প্রোফাইল যোগ করা হয়নি" />;
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
        সকল ডাক্তার প্রোফাইল ম্যানেজমেন্ট
      </h1>
      <div className="overflow-x-auto rounded-xl border border-border bg-card">
        <table className="w-full text-sm">
          <thead className="border-b border-border bg-secondary/50 text-left">
            <tr>
              <th className="p-3 font-medium">ডাক্তার প্রোফাইল</th>
              <th className="p-3 font-medium">চেম্বার</th>
              <th className="p-3 font-medium">কনসালটেশন ফি</th>
              <th className="p-3 font-medium">উপলভ্যতা</th>
              <th className="p-3 font-medium">অবস্থা</th>
              <th className="p-3 font-medium">অ্যাকশন</th>
            </tr>
          </thead>
          <tbody>
            {products.map((p) => (
              <tr key={p.id} className="border-b border-border last:border-0">
                <td className="flex items-center gap-3 p-3">
                  <div className="h-10 w-10 shrink-0 overflow-hidden rounded-lg bg-secondary">
                    {p.thumbnail_url && <img src={p.thumbnail_url} alt="" className="h-full w-full object-cover" />}
                  </div>
                  <span className="line-clamp-1 font-medium">{p.name}</span>
                </td>
                <td className="p-3 text-muted-foreground">{p.shops?.shop_name || "—"}</td>
                <td className="p-3">
                  {getDiscountedPrice(p).hasDiscount ? (
                    <span className="flex items-center gap-1.5">
                      <span className="font-medium">{formatPriceBn(getDiscountedPrice(p).finalPrice)}</span>
                      <span className="text-xs text-muted-foreground line-through">{formatPriceBn(p.price)}</span>
                    </span>
                  ) : (
                    formatPriceBn(p.price)
                  )}
                </td>
                <td className="p-3">
                  <div className="flex flex-col gap-0.5 text-xs">
                    <span
                      className={
                        Number(p.stock_quantity ?? 0) <= 0
                          ? "font-medium text-destructive"
                          : "font-medium text-foreground"
                      }
                    >
                      উপলভ্যতা: {p.stock_quantity ?? 0}
                    </span>
                    <span className="text-muted-foreground">অ্যাপয়েন্টমেন্ট: {p.sold_count ?? 0}</span>
                  </div>
                </td>
                <td className="p-3">
                  <span
                    className={`rounded-full px-2.5 py-1 text-xs font-medium ${
                      p.is_active ? "bg-primary/10 text-primary" : "bg-muted text-muted-foreground"
                    }`}
                  >
                    {p.is_active ? "সক্রিয়" : "নিষ্ক্রিয়"}
                  </span>
                </td>
                <td className="p-3">
                  <div className="flex gap-1.5">
                    <Button variant="ghost" size="icon" disabled={busyId === p.id} onClick={() => toggleActive(p)}>
                      {p.is_active ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </Button>
                    <Button variant="ghost" size="icon" disabled={busyId === p.id} onClick={() => handleDelete(p.id)}>
                      <Trash2 className="h-4 w-4 text-destructive" />
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
