import { useParams, useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";
import { Phone, MapPin, Facebook, Map, MessageCircle, Store, Package, Heart, Navigation, Globe2 } from "lucide-react";
import { useShopBySlug } from "@/hooks/useShops";
import { supabase } from "@/lib/supabaseClient";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import ProductCard from "@/components/shared/ProductCard.jsx";
import ProductGridSkeleton from "@/components/shared/ProductGridSkeleton.jsx";
import ShareShopButton from "@/components/shared/ShareShopButton.jsx";
import { useShopSave } from "@/hooks/useProductAnalytics";

export default function ShopPage() {
  const { shopSlug } = useParams();
  const navigate = useNavigate();
  const { shop, loading, error } = useShopBySlug(shopSlug);
  const [products, setProducts] = useState([]);
  const [productsLoading, setProductsLoading] = useState(true);
  const [gallery, setGallery] = useState([]);
  const { isSaved, saving, toggleSave } = useShopSave(shop?.id);

  const handleSaveClick = async () => {
    const { requiresLogin } = await toggleSave();
    if (requiresLogin) navigate("/login");
  };

  useEffect(() => {
    if (!shop?.id) return;
    setProductsLoading(true);
    supabase
      .from("products")
      .select("*")
      .eq("shop_id", shop.id)
      .eq("is_active", true)
      .order("created_at", { ascending: false })
      .then(({ data }) => {
        setProducts(data ?? []);
        setProductsLoading(false);
      });

    supabase
      .from("shop_gallery")
      .select("*")
      .eq("shop_id", shop.id)
      .order("sort_order", { ascending: true })
      .then(({ data }) => setGallery(data ?? []));
  }, [shop?.id]);

  if (loading) return <LoadingSpinner fullScreen label="চেম্বার লোড হচ্ছে..." />;

  if (error || !shop) {
    return (
      <div className="container py-16">
        <EmptyState
          icon={Store}
          title="চেম্বারটি খুঁজে পাওয়া যায়নি"
          description="লিংকটি সঠিক কিনা যাচাই করুন অথবা হোমপেজে ফিরে যান।"
        />
      </div>
    );
  }

  const website = { enabled: true, hero_title: shop.shop_name, hero_subtitle: "সিরাজগঞ্জের রোগীদের জন্য বিশ্বস্ত চিকিৎসা সেবা", about_title: "আমাদের সম্পর্কে", contact_title: "যোগাযোগ ও দিকনির্দেশনা", show_doctors: true, show_gallery: true, show_about: true, cta_text: "অ্যাপয়েন্টমেন্ট নিন", ...(shop.website_config || {}) };
  const directionUrl = shop.google_map_link || (shop.address ? `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(shop.address)}` : "");

  if (website.enabled === false) {
    return <div className="container py-16"><EmptyState icon={Globe2} title="ওয়েবসাইটটি বর্তমানে বন্ধ" description="চেম্বার / হাসপাতাল কর্তৃপক্ষ এই পাবলিক পেজটি সাময়িকভাবে বন্ধ রেখেছেন।" /></div>;
  }

  return (
    <div>
      <div className="h-40 w-full bg-secondary md:h-64">

        {shop.banner_url && <img src={shop.banner_url} alt="" className="h-full w-full object-cover" />}
      </div>

      <div className="container -mt-12 pb-16">
        <div className="flex flex-col items-start gap-4 rounded-xl border border-border bg-card p-6 shadow-sm md:flex-row md:items-center">
          <div className="flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-xl border-4 border-card bg-primary text-primary-foreground shadow">
            {shop.logo_url ? (
              <img src={shop.logo_url} alt={shop.shop_name} className="h-full w-full object-cover" />
            ) : (
              <Store className="h-8 w-8" />
            )}
          </div>
          <div className="flex-1">
            <h1 className="text-2xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>{website.hero_title || shop.shop_name}</h1>
            {website.hero_subtitle && <p className="mt-1 text-sm text-primary/80">{website.hero_subtitle}</p>}
            {shop.about && <p className="mt-1 max-w-2xl text-sm text-muted-foreground">{shop.about}</p>}
          </div>
          <button
            type="button"
            onClick={handleSaveClick}
            disabled={saving}
            aria-pressed={isSaved}
            className={`inline-flex shrink-0 items-center gap-2 self-start rounded-lg border px-4 py-2 text-sm font-medium transition-colors md:self-center ${
              isSaved
                ? "border-destructive bg-destructive/10 text-destructive"
                : "border-border bg-card text-muted-foreground hover:text-destructive"
            }`}
            title={isSaved ? "সেভ করা তালিকা থেকে সরান" : "চেম্বারটি সেভ করুন"}
          >
            <Heart className={`h-4 w-4 ${isSaved ? "fill-current" : ""}`} />
            {isSaved ? "সেভ করা হয়েছে" : "চেম্বার সেভ করুন"}
          </button>
          <ShareShopButton shop={shop} className="self-start md:self-center" />
        </div>

        <div className="mt-6 grid gap-6 md:grid-cols-3">
          <div className="space-y-4 rounded-xl border border-border bg-card p-5 md:col-span-1">
            <h3 className="font-semibold">যোগাযোগ</h3>
            {shop.phone && (
              <a href={`tel:${shop.phone}`} className="flex items-center gap-2 text-sm text-foreground hover:text-primary">
                <Phone className="h-4 w-4 text-primary" /> {shop.phone}
              </a>
            )}
            {shop.whatsapp_number && (
              <a
                href={`https://wa.me/${shop.whatsapp_number.replace(/\D/g, "")}`}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-2 text-sm text-foreground hover:text-primary"
              >
                <MessageCircle className="h-4 w-4 text-primary" /> হোয়াটসঅ্যাপে বার্তা দিন
              </a>
            )}
            {shop.address && (
              <p className="flex items-center gap-2 text-sm text-foreground">
                <MapPin className="h-4 w-4 shrink-0 text-primary" /> {shop.address}
              </p>
            )}
            {directionUrl && (
              <a
                href={directionUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground shadow-sm hover:opacity-95"
              >
                <Navigation className="h-4 w-4" /> দিকনির্দেশনা
              </a>
            )}
            {shop.facebook_link && (
              <a
                href={shop.facebook_link}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-2 text-sm text-foreground hover:text-primary"
              >
                <Facebook className="h-4 w-4 text-primary" /> ফেসবুক পেজ
              </a>
            )}
          </div>

          <div className="md:col-span-2">
            {website.show_about && shop.about && <section className="mb-6 rounded-2xl border bg-card p-5"><h3 className="mb-2 font-semibold">{website.about_title}</h3><p className="whitespace-pre-line text-sm leading-relaxed text-muted-foreground">{shop.about}</p></section>}
            {website.show_doctors && <><h3 className="mb-3 font-semibold">ডাক্তার প্রোফাইল</h3>
            {productsLoading ? (
              <ProductGridSkeleton count={6} className="sm:grid-cols-3 md:grid-cols-3" />
            ) : products.length === 0 ? (
              <EmptyState icon={Package} title="এই চেম্বারে এখনো কোনো ডাক্তার প্রোফাইল যোগ করা হয়নি" />
            ) : (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
                {products.map((p) => (
                  <ProductCard key={p.id} product={p} />
                ))}
              </div>
            )}
            </>}
          </div>
        </div>

        {website.show_gallery && gallery.length > 0 && (
          <div className="mt-8">
            <h3 className="mb-3 font-semibold">গ্যালারি</h3>
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-6">
              {gallery.map((g) => (
                <img key={g.id} src={g.image_url} alt="" className="aspect-square w-full rounded-lg object-cover" />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
