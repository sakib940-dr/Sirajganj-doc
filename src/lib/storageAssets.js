import { supabase } from "@/lib/supabaseClient";

function decodePath(value) {
  try { return decodeURIComponent(value); } catch { return value; }
}

export function extractStorageObjectPath(value, bucket) {
  if (!value || !bucket) return "";
  const raw = String(value).trim();
  const markers = [
    `/storage/v1/object/public/${bucket}/`,
    `/storage/v1/object/sign/${bucket}/`,
    `/storage/v1/object/authenticated/${bucket}/`,
  ];
  for (const marker of markers) {
    const idx = raw.indexOf(marker);
    if (idx >= 0) {
      return decodePath(raw.slice(idx + marker.length).split("?")[0]);
    }
  }
  if (!/^https?:\/\//i.test(raw) && !raw.startsWith("blob:")) {
    return raw.startsWith(`${bucket}/`) ? raw.slice(bucket.length + 1) : raw;
  }
  return "";
}

export async function resolvePrivateStorageUrl(value, buckets, expiresIn = 1800) {
  if (!value) return "";
  const raw = String(value).trim();
  if (raw.startsWith("blob:")) return raw;
  const candidates = Array.isArray(buckets) ? buckets : [buckets];
  for (const bucket of candidates.filter(Boolean)) {
    const path = extractStorageObjectPath(raw, bucket);
    if (!path) continue;
    const { data, error } = await supabase.storage.from(bucket).createSignedUrl(path, expiresIn);
    if (!error && data?.signedUrl) return data.signedUrl;
  }
  // External/non-Supabase URLs are preserved for backward compatibility.
  if (/^https?:\/\//i.test(raw) && !raw.includes("/storage/v1/object/")) return raw;
  return "";
}
