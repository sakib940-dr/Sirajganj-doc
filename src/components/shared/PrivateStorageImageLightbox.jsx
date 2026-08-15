import { useEffect, useState } from "react";
import ImageLightbox from "@/components/shared/ImageLightbox.jsx";
import { resolvePrivateStorageUrl } from "@/lib/storageAssets";

export default function PrivateStorageImageLightbox({
  value,
  buckets = ["seller-verification", "verification-docs"],
  ...props
}) {
  const [src, setSrc] = useState("");
  useEffect(() => {
    let active = true;
    if (!value) { setSrc(""); return () => { active = false; }; }
    resolvePrivateStorageUrl(value, buckets).then((url) => { if (active) setSrc(url || ""); });
    return () => { active = false; };
  }, [value, JSON.stringify(buckets)]);
  return src ? <ImageLightbox src={src} {...props} /> : null;
}
