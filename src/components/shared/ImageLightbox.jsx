import { useState } from "react";
import { ZoomIn } from "lucide-react";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog.jsx";
import { cn } from "@/lib/utils";

/**
 * Admin Panel-এ ভেরিফিকেশন ছবি (প্রোফাইল ছবি / NID) বড় ও স্পষ্টভাবে দেখার জন্য
 * থাম্বনেইল + লাইটবক্স/মোডাল প্রিভিউ। থাম্বনেইলে ক্লিক করলে ছবিটি বড় সাইজে
 * (viewport-এর প্রায় পুরোটা জুড়ে) মোডালে খোলে, যাতে Admin স্পষ্টভাবে ছবিটি
 * পড়তে/চিনতে পারেন।
 *
 * @param {string} src - ছবির URL
 * @param {string} alt - alt text / লাইটবক্স শিরোনাম
 * @param {"square" | "wide"} shape - থাম্বনেইলের আকৃতি
 * @param {string} thumbClassName - থাম্বনেইল কন্টেইনারের জন্য অতিরিক্ত ক্লাস
 */
export default function ImageLightbox({ src, alt = "", shape = "square", thumbClassName }) {
  const [open, setOpen] = useState(false);

  if (!src) return null;

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(
          "group relative shrink-0 overflow-hidden rounded-lg border border-border bg-secondary/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
          shape === "square" ? "h-24 w-24" : "h-24 w-40",
          thumbClassName
        )}
        aria-label={`${alt} — বড় করে দেখুন`}
      >
        <img src={src} alt={alt} className="h-full w-full object-cover" />
        <span className="absolute inset-0 flex items-center justify-center bg-black/0 transition-colors group-hover:bg-black/40">
          <ZoomIn className="h-5 w-5 text-white opacity-0 transition-opacity group-hover:opacity-100" />
        </span>
      </button>

      <DialogContent className="flex max-h-[92vh] w-[95vw] max-w-4xl flex-col items-center justify-center gap-3 rounded-xl bg-card p-3">
        <DialogTitle className="sr-only">{alt || "ছবি প্রিভিউ"}</DialogTitle>
        <img
          src={src}
          alt={alt}
          className="max-h-[80vh] w-auto max-w-full rounded-lg object-contain"
        />
        {alt && <p className="text-sm font-medium text-foreground">{alt}</p>}
      </DialogContent>
    </Dialog>
  );
}
