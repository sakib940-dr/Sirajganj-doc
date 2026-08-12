import { useEffect, useState } from "react";
import { Images } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

const MAX_GALLERY_IMAGES = 4;

export default function GalleryPage() {
  const { user } = useAuth();
  const [shopId, setShopId] = useState(null);
  const [images, setImages] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const { data: shop } = await supabase.from("shops").select("id").eq("owner_id", user.id).maybeSingle();
      if (!shop) {
        setLoading(false);
        return;
      }
      setShopId(shop.id);
      const { data } = await supabase
        .from("shop_gallery")
        .select("*")
        .eq("shop_id", shop.id)
        .order("sort_order", { ascending: true });
      setImages(data ?? []);
      setLoading(false);
    }
    if (user) load();
  }, [user]);

  const addImage = async (url) => {
    if (!url || !shopId || images.length >= MAX_GALLERY_IMAGES) return;
    const { data } = await supabase
      .from("shop_gallery")
      .insert({ shop_id: shopId, image_url: url, sort_order: images.length })
      .select()
      .single();
    if (data) setImages((prev) => [...prev, data]);
  };

  const removeImage = async (id) => {
    await supabase.from("shop_gallery").delete().eq("id", id);
    setImages((prev) => prev.filter((i) => i.id !== id));
  };

  const replaceImage = async (id, url) => {
    const { data } = await supabase.from("shop_gallery").update({ image_url: url }).eq("id", id).select().single();
    if (data) setImages((prev) => prev.map((i) => (i.id === id ? data : i)));
  };

  // প্রতিটা বিদ্যমান ছবির নিজস্ব ImageUploader-এ ব্যবহৃত হয় — নতুন ছবি সিলেক্ট
  // করলে পুরনোটা replace হয়ে যায়, X চাপলে remove হয় (ImageUploader-এর
  // বিল্ট-ইন আচরণ: খালি URL মানে মুছে ফেলা)
  const handleImageChange = (id) => (url) => {
    if (!url) removeImage(id);
    else replaceImage(id, url);
  };

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  if (!shopId) {
    return <EmptyState icon={Images} title="প্রথমে চেম্বারের তথ্য পূরণ করুন" />;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          চেম্বারের গ্যালারি
        </h1>
        <p className="text-sm text-muted-foreground">
          আপনার চেম্বার/ডাক্তার প্রোফাইলের অতিরিক্ত ছবি এখানে যোগ করুন — সর্বোচ্চ {MAX_GALLERY_IMAGES}টি ({images.length}/
          {MAX_GALLERY_IMAGES} ব্যবহৃত হয়েছে)। বিদ্যমান ছবির উপর নতুন ছবি আপলোড করলে সেটা বদলে (replace) যাবে।
        </p>
      </div>

      <div className="flex flex-wrap gap-4">
        {images.map((img) => (
          <ImageUploader
            key={img.id}
            bucket="shop-gallery"
            folder={user.id}
            value={img.image_url}
            onUploaded={handleImageChange(img.id)}
          />
        ))}
        {images.length < MAX_GALLERY_IMAGES && (
          <ImageUploader bucket="shop-gallery" folder={user.id} value="" onUploaded={addImage} />
        )}
      </div>
    </div>
  );
}
