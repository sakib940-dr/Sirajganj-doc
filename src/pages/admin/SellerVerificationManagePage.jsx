import { useEffect, useState, useCallback, useMemo } from "react";
import { Check, X, ShieldCheck, MapPin, Facebook, ChevronDown, ChevronUp, UserCircle2 } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import ImageLightbox from "@/components/shared/ImageLightbox.jsx";
import { formatDateBn } from "@/lib/utils";
import { VERIFICATION_STATUS, VERIFICATION_STATUS_LABEL_BN } from "@/constants/roles";

export default function SellerVerificationManagePage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);
  const [expanded, setExpanded] = useState({}); // { [userId]: boolean } — পূর্ববর্তী আবেদন দেখানো হচ্ছে কিনা

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("seller_verifications")
      .select("*, profiles:user_id ( full_name, email, phone )")
      .order("created_at", { ascending: false });
    setItems(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const updateStatus = async (id, status) => {
    setBusyId(id);
    const { error } = await supabase.from("seller_verifications").update({ status }).eq("id", id);
    if (!error) {
      setItems((prev) => prev.map((it) => (it.id === id ? { ...it, status } : it)));
    }
    setBusyId(null);
  };

  // প্রতিটি ডাক্তারের সাম্প্রতিক (বর্তমান) আবেদন + পূর্ববর্তী আবেদনের ইতিহাস
  // — items ইতিমধ্যে created_at অনুযায়ী descending সাজানো, তাই প্রতি ডাক্তারের
  // প্রথম entry-ই বর্তমান আবেদন
  const groups = useMemo(() => {
    const map = new Map();
    for (const v of items) {
      if (!map.has(v.user_id)) map.set(v.user_id, []);
      map.get(v.user_id).push(v);
    }
    return Array.from(map.values());
  }, [items]);

  if (loading) return <LoadingSpinner label="ভেরিফিকেশন তালিকা লোড হচ্ছে..." />;

  if (items.length === 0) {
    return <EmptyState icon={ShieldCheck} title="এখনো কোনো ডাক্তার ভেরিফিকেশন আবেদন নেই" />;
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
        ডাক্তার ভেরিফিকেশন
      </h1>

      <div className="space-y-4">
        {groups.map(([current, ...previous]) => (
          <div key={current.id} className="rounded-xl border border-border bg-card p-5">
            <VerificationCard v={current} busy={busyId === current.id} onUpdate={updateStatus} />

            {previous.length > 0 && (
              <div className="mt-4 border-t border-border pt-3">
                <button
                  type="button"
                  onClick={() => setExpanded((prev) => ({ ...prev, [current.user_id]: !prev[current.user_id] }))}
                  className="flex items-center gap-1.5 text-xs font-medium text-primary hover:underline"
                >
                  {expanded[current.user_id] ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
                  পূর্ববর্তী আবেদন ({previous.length}টি)
                </button>

                {expanded[current.user_id] && (
                  <div className="mt-3 space-y-3">
                    {previous.map((v) => (
                      <div key={v.id} className="rounded-lg border border-border/70 bg-muted/30 p-4">
                        <VerificationCard v={v} busy={busyId === v.id} onUpdate={updateStatus} readOnlyActions isHistory />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function VerificationCard({ v, busy, onUpdate, readOnlyActions = false, isHistory = false }) {
  return (
    <div>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          {v.profile_photo_url ? (
            <ImageLightbox
              src={v.profile_photo_url}
              alt={v.full_name || v.profiles?.full_name || "প্রোফাইল ছবি"}
              shape="square"
              thumbClassName="h-16 w-16 rounded-full"
            />
          ) : (
            <span className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-secondary">
              <UserCircle2 className="h-8 w-8 text-muted-foreground" />
            </span>
          )}
          <div>
            <p className="font-semibold">{v.full_name || v.profiles?.full_name || "নাম নেই"}</p>
            <p className="text-xs text-muted-foreground">
              {v.profiles?.email} {v.phone ? `· ${v.phone}` : ""}
            </p>
            <p className="text-[11px] text-muted-foreground">
              আবেদনের তারিখ: {formatDateBn(v.created_at)}
            </p>
          </div>
        </div>
        <span
          className={`rounded-full px-2.5 py-1 text-xs font-medium ${
            v.status === VERIFICATION_STATUS.APPROVED
              ? "bg-primary/10 text-primary"
              : v.status === VERIFICATION_STATUS.REJECTED
              ? "bg-destructive/10 text-destructive"
              : "bg-accent/15 text-accent"
          }`}
        >
          {VERIFICATION_STATUS_LABEL_BN[v.status]}
        </span>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <div className="space-y-1.5 text-sm">
          <p>
            <span className="text-muted-foreground">ব্যবসার ধরন: </span>
            {v.business_type || "—"}
          </p>
          <p>
            <span className="text-muted-foreground">ডাক্তার প্রোফাইলের ধরন: </span>
            {v.product_type || "—"}
          </p>
          <p>
            <span className="text-muted-foreground">মাসিক গড় বিক্রয়: </span>
            {v.avg_monthly_sales_bdt != null ? `৳${v.avg_monthly_sales_bdt}` : "—"}
          </p>
          <p>
            <span className="text-muted-foreground">মাসিক বিক্রয় লক্ষ্য: </span>
            {v.monthly_sales_target_bdt != null ? `৳${v.monthly_sales_target_bdt}` : "—"}
          </p>
          <p>
            <span className="text-muted-foreground">বিক্রয়ের মাধ্যম: </span>
            {v.sales_channel || "—"}
          </p>
          <p>
            <span className="text-muted-foreground">Facebook Page-এ অ্যাপয়েন্টমেন্ট: </span>
            {v.sells_via_facebook_page === true ? "হ্যাঁ" : v.sells_via_facebook_page === false ? "না" : "—"}
          </p>
          <p>
            <span className="text-muted-foreground">অন্য e-commerce platform: </span>
            {v.uses_other_ecommerce_platform === true
              ? v.other_ecommerce_platform_name
                ? `হ্যাঁ (${v.other_ecommerce_platform_name})`
                : "হ্যাঁ"
              : v.uses_other_ecommerce_platform === false
              ? "না"
              : "—"}
          </p>
          <p>
            <span className="text-muted-foreground">ঠিকানা: </span>
            {v.address || "—"}
          </p>
          <p>
            <span className="text-muted-foreground">NID নম্বর: </span>
            {v.nid_number || "—"}
          </p>
          <div className="flex flex-wrap gap-3 pt-1">
            {v.google_map_link && (
              <a
                href={v.google_map_link}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
              >
                <MapPin className="h-3.5 w-3.5" /> ম্যাপ দেখুন
              </a>
            )}
            {v.facebook_link && (
              <a
                href={v.facebook_link}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
              >
                <Facebook className="h-3.5 w-3.5" /> ফেসবুক প্রোফাইল
              </a>
            )}
          </div>
        </div>

        <div className="flex flex-wrap gap-3">
          {v.nid_front_url && (
            <div>
              <p className="mb-1 text-[11px] text-muted-foreground">NID সামনে</p>
              <ImageLightbox src={v.nid_front_url} alt="NID সামনের পাশ" shape="wide" thumbClassName="h-24 w-40" />
            </div>
          )}
          {v.nid_back_url && (
            <div>
              <p className="mb-1 text-[11px] text-muted-foreground">NID পেছনে</p>
              <ImageLightbox src={v.nid_back_url} alt="NID পেছনের পাশ" shape="wide" thumbClassName="h-24 w-40" />
            </div>
          )}
        </div>
      </div>

      {!readOnlyActions && (
        <div className="mt-4 flex gap-2">
          <Button
            size="sm"
            disabled={busy || v.status === VERIFICATION_STATUS.APPROVED}
            onClick={() => onUpdate(v.id, VERIFICATION_STATUS.APPROVED)}
          >
            <Check className="h-4 w-4" /> অনুমোদন
          </Button>
          <Button
            size="sm"
            variant="outline"
            disabled={busy || v.status === VERIFICATION_STATUS.REJECTED}
            onClick={() => onUpdate(v.id, VERIFICATION_STATUS.REJECTED)}
          >
            <X className="h-4 w-4" /> প্রত্যাখ্যান
          </Button>
        </div>
      )}
      {isHistory && (
        <p className="mt-3 text-[11px] italic text-muted-foreground">
          এটি একটি পূর্ববর্তী (historical) আবেদন — শুধুমাত্র দেখার জন্য সংরক্ষিত, পরিবর্তনযোগ্য নয়।
        </p>
      )}
    </div>
  );
}
