import { useRef, useState } from "react";
import { Upload, X, ImageIcon, AlertCircle } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { compressImageToRange } from "@/lib/imageCompression";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const DEFAULT_MAX_SIZE_KB = 100;

/**
 * @param {string} bucket - Supabase storage bucket name
 * @param {string} folder - user id বা shop id, ফাইল path prefix হিসেবে ব্যবহৃত হয়
 * @param {string} value - বর্তমান ছবির URL (থাকলে)
 * @param {(url: string) => void} onUploaded - আপলোড সফল হলে public URL ফেরত দেয়
 * @param {"square" | "wide"} aspect - প্রিভিউ শেপ
 * @param {number} maxSizeKB - সর্বোচ্চ অনুমোদিত (আপলোডের সময় সিলেক্ট করা) ফাইল সাইজ (KB), ডিফল্ট ১০০ KB
 * @param {boolean} autoCompress - true হলে maxSizeKB চেক করার আগে ছবিটি স্বয়ংক্রিয়ভাবে কমপ্রেস করা হয়
 * @param {number} compressTargetMinKB - অটো-কমপ্রেসের সর্বনিম্ন টার্গেট সাইজ (KB)
 * @param {number} compressTargetMaxKB - অটো-কমপ্রেসের সর্বোচ্চ টার্গেট সাইজ (KB)
 */
export default function ImageUploader({
  bucket,
  folder,
  value,
  onUploaded,
  aspect = "square",
  maxSizeKB = DEFAULT_MAX_SIZE_KB,
  autoCompress = false,
  compressTargetMinKB = 100,
  compressTargetMaxKB = 200,
}) {
  const inputRef = useRef(null);
  const [uploading, setUploading] = useState(false);
  const [compressing, setCompressing] = useState(false);
  const [error, setError] = useState("");
  const maxSizeBytes = maxSizeKB * 1024;

  const handleFile = async (e) => {
    let file = e.target.files?.[0];
    if (!file) return;
    setError("");

    if (!file.type.startsWith("image/")) {
      setError("শুধুমাত্র ছবি ফাইল আপলোড করা যাবে।");
      return;
    }

    if (autoCompress) {
      try {
        setCompressing(true);
        file = await compressImageToRange(file, {
          targetMinKB: compressTargetMinKB,
          targetMaxKB: compressTargetMaxKB,
        });
      } catch {
        // কমপ্রেশন ব্যর্থ হলে মূল ফাইল দিয়েই এগিয়ে যাওয়া হবে (নিচের সাইজ চেক তখন কাজ করবে)
      } finally {
        setCompressing(false);
      }
    }

    if (file.size > maxSizeBytes) {
      setError(
        `ছবিটির সাইজ ${(file.size / 1024).toFixed(0)} KB — সর্বোচ্চ ${maxSizeKB} KB অনুমোদিত। অনুগ্রহ করে একটি Image Resizer/Compressor অ্যাপ বা ওয়েবসাইট (যেমন TinyPNG, Squoosh) দিয়ে ছবিটি ${maxSizeKB} KB-এর মধ্যে ছোট করে আবার আপলোড করুন।`
      );
      e.target.value = "";
      return;
    }

    setUploading(true);
    const ext = autoCompress ? "jpg" : file.name.split(".").pop();
    const path = `${folder}/${Date.now()}.${ext}`;

    const { error: uploadError } = await supabase.storage.from(bucket).upload(path, file, {
      upsert: true,
    });

    if (uploadError) {
      setError("আপলোড ব্যর্থ হয়েছে: " + uploadError.message);
      setUploading(false);
      return;
    }

    const { data } = supabase.storage.from(bucket).getPublicUrl(path);
    onUploaded(data.publicUrl);
    setUploading(false);
  };

  return (
    <div>
      <div
        className={cn(
          "relative flex items-center justify-center overflow-hidden rounded-xl border-2 border-dashed border-border bg-secondary/50",
          aspect === "square" ? "h-28 w-28" : "h-28 w-full"
        )}
      >
        {value ? (
          <>
            <img src={value} alt="" className="h-full w-full object-cover" />
            <button
              type="button"
              onClick={() => onUploaded("")}
              className="absolute right-1 top-1 flex h-6 w-6 items-center justify-center rounded-full bg-destructive text-destructive-foreground"
              aria-label="ছবি মুছুন"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          </>
        ) : (
          <ImageIcon className="h-8 w-8 text-muted-foreground" />
        )}
      </div>

      <input ref={inputRef} type="file" accept="image/*" className="hidden" onChange={handleFile} />
      <Button
        type="button"
        variant="outline"
        size="sm"
        className="mt-2"
        disabled={uploading || compressing}
        onClick={() => inputRef.current?.click()}
      >
        <Upload className="h-3.5 w-3.5" />
        {compressing ? "ছবি কমপ্রেস হচ্ছে..." : uploading ? "আপলোড হচ্ছে..." : "ছবি আপলোড করুন"}
      </Button>
      {autoCompress ? (
        <p className="mt-1 text-xs text-muted-foreground">
          সর্বোচ্চ {maxSizeKB >= 1024 ? `${(maxSizeKB / 1024).toFixed(maxSizeKB % 1024 === 0 ? 0 : 1)} MB` : `${maxSizeKB} KB`} সাইজের ছবি আপলোড করা যাবে — সিস্টেম স্বয়ংক্রিয়ভাবে ছবিটি প্রায় {compressTargetMinKB}–{compressTargetMaxKB} KB-এ কমপ্রেস করে দেবে।
        </p>
      ) : (
        <p className="mt-1 text-xs text-muted-foreground">
          সর্বোচ্চ {maxSizeKB >= 1024 ? `${(maxSizeKB / 1024).toFixed(maxSizeKB % 1024 === 0 ? 0 : 1)} MB` : `${maxSizeKB} KB`} সাইজের ছবি আপলোড করা যাবে। আপলোডের আগে Image Resizer/Compressor দিয়ে ছবি ছোট করে নিন।
        </p>
      )}

      {error && (
        <p className="mt-1.5 flex items-start gap-1.5 text-xs text-destructive">
          <AlertCircle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          {error}
        </p>
      )}
    </div>
  );
}
