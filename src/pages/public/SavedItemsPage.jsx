import { useEffect, useState } from "react";
import { Heart, Store, Package } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { supabase } from "@/lib/supabaseClient";
import ProductCard from "@/components/shared/ProductCard.jsx";
import ShopCard from "@/components/shared/ShopCard.jsx";
import ProductGridSkeleton from "@/components/shared/ProductGridSkeleton.jsx";
import ShopGridSkeleton from "@/components/shared/ShopGridSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";

const PRODUCT_SELECT =
  "*, shops:shop_id ( shop_name, slug, whatsapp_number, facebook_link ), categories:category_id ( name, slug )";

export default function SavedItemsPage() {
  const { user } = useAuth();
  const [savedProducts, setSavedProducts] = useState([]);
  const [savedShops, setSavedShops] = useState([]);
  const [loadingProducts, setLoadingProducts] = useState(true);
  const [loadingShops, setLoadingShops] = useState(true);

  useEffect(() => {
    if (!user) return;
    let active = true;

    supabase
      .from("product_saves")
      .select(`created_at, products:product_id ( ${PRODUCT_SELECT} )`)
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .then(({ data }) => {
        if (!active) return;
        setSavedProducts((data ?? []).map((row) => row.products).filter(Boolean));
        setLoadingProducts(false);
      });

    supabase
      .from("shop_saves")
      .select("created_at, shops:shop_id ( * )")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .then(({ data }) => {
        if (!active) return;
        setSavedShops((data ?? []).map((row) => row.shops).filter(Boolean));
        setLoadingShops(false);
      });

    return () => {
      active = false;
    };
  }, [user]);

  return (
    <div className="container space-y-10 py-8">
      <div>
        <h1
          className="flex items-center gap-2 text-xl font-bold"
          style={{ fontFamily: "'Tiro Bangla', serif" }}
        >
          <Heart className="h-5 w-5 text-primary" />
          আমার সংরক্ষিত
        </h1>
        <p className="text-sm text-muted-foreground">আপনার সেভ করা ডাক্তার প্রোফাইল ও চেম্বার এখানে দেখুন</p>
      </div>

      <section>
        <h2 className="mb-3 flex items-center gap-2 text-base font-semibold">
          <Package className="h-4 w-4 text-primary" /> সেভ করা ডাক্তার প্রোফাইল
        </h2>
        {loadingProducts ? (
          <ProductGridSkeleton count={4} />
        ) : savedProducts.length === 0 ? (
          <EmptyState icon={Package} title="এখনো কোনো ডাক্তার প্রোফাইল সেভ করা হয়নি" description="ডাক্তার প্রোফাইলের পেজে ♥ বাটনে ক্লিক করে সেভ করুন।" />
        ) : (
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
            {savedProducts.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        )}
      </section>

      <section>
        <h2 className="mb-3 flex items-center gap-2 text-base font-semibold">
          <Store className="h-4 w-4 text-primary" /> সেভ করা চেম্বার
        </h2>
        {loadingShops ? (
          <ShopGridSkeleton count={3} />
        ) : savedShops.length === 0 ? (
          <EmptyState icon={Store} title="এখনো কোনো চেম্বার সেভ করা হয়নি" description="চেম্বারের পেজে ♥ বাটনে ক্লিক করে সেভ করুন।" />
        ) : (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
            {savedShops.map((s) => (
              <ShopCard key={s.id} shop={s} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
