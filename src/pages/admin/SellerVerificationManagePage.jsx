import { useEffect, useState, useCallback, useMemo } from "react";
import { Check, X, ShieldCheck, MapPin, Facebook, ChevronDown, ChevronUp, UserCircle2 } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import EmptyState from "@/components/shared/EmptyState.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import PrivateStorageImageLightbox from "@/components/shared/PrivateStorageImageLightbox.jsx";
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
      .select("*, profiles:user_id ( full_name, email, phone, role )")
      .order("created_at", { ascending: false });
    setItems(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const updateStatus = async (id, status) => {
    let note = null;
    if (status === VERIFICATION_STATUS.REJECTED) {
      note = window.prompt("প্রত্যাখ্যানের কারণ লিখুন:", "");
      if (note === null) return;
      if (!note.trim()) { window.alert("প্রত্যাখ্যানের কারণ লিখতে হবে।"); return; }
    }
    setBusyId(id);
    const { error } = await supabase.rpc("review_provider_verification", { p_verification_id: id, p_status: status, p_admin_note: note });
    if (!error) setItems((prev) => prev.map((it) => (it.id === id ? { ...it, status, admin_note: note } : it)));
    else window.alert(error.message || "ভেরিফিকেশন আপডেট করা যায়নি।");
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
    return <EmptyState icon={ShieldCheck} title="এখনো কোনো প্রোভাইডার ভেরিফিকেশন আবেদন নেই" />;
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
        ডাক্তার ও হাসপাতাল ভেরিফিকেশন
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
            <PrivateStorageImageLightbox
              value={v.profile_photo_url}
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
          <p><span className="text-muted-foreground">অ্যাকাউন্ট ধরন: </span>{v.profiles?.role === "hospital" ? "হাসপাতাল / চেম্বার" : "ডাক্তার"}</p>
          {v.profiles?.role === "doctor" && <>
            <p><span className="text-muted-foreground">ডিগ্রি: </span>{v.degree || "—"}</p>
            <p><span className="text-muted-foreground">বিশেষত্ব: </span>{v.specialty || "—"}</p>
            <p><span className="text-muted-foreground">পদবি: </span>{v.designation || "—"}</p>
            <p><span className="text-muted-foreground">BMDC নম্বর: </span>{v.bmdc_registration_no || "—"}</p>
            <p><span className="text-muted-foreground">চেম্বার: </span>{v.chamber_name || "—"}</p>
            <p><span className="text-muted-foreground">চেম্বারের ঠিকানা: </span>{v.chamber_address || "—"}</p>
            <p><span className="text-muted-foreground">রোগী দেখার দিন: </span>{v.visiting_days || "—"}</p>
            <p><span className="text-muted-foreground">রোগী দেখার সময়: </span>{v.visiting_time || "—"}</p>
            <p><span className="text-muted-foreground">পরামর্শ ফি: </span>{v.consultation_fee != null ? `৳${v.consultation_fee}` : "—"}</p>
          </>}
          {v.profiles?.role === "hospital" && <>
            <p><span className="text-muted-foreground">প্রতিষ্ঠান / চেম্বার: </span>{v.chamber_name || v.full_name || "—"}</p>
            <p><span className="text-muted-foreground">ট্রেড লাইসেন্স: </span>{v.trade_license_no || "—"}</p>
            <p><span className="text-muted-foreground">প্রতিষ্ঠানের ঠিকানা: </span>{v.chamber_address || v.address || "—"}</p>
          </>}
          <p><span className="text-muted-foreground">যোগাযোগের ঠিকানা: </span>{v.address || "—"}</p>
          <p><span className="text-muted-foreground">NID নম্বর: </span>{v.nid_number || "—"}</p>
          {v.admin_note && <p className="rounded-lg bg-secondary/60 p-2"><span className="text-muted-foreground">অ্যাডমিন নোট: </span>{v.admin_note}</p>}
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
              <PrivateStorageImageLightbox value={v.nid_front_url} alt="NID সামনের পাশ" shape="wide" thumbClassName="h-24 w-40" />
            </div>
          )}
          {v.nid_back_url && (
            <div>
              <p className="mb-1 text-[11px] text-muted-foreground">NID পেছনে</p>
              <PrivateStorageImageLightbox value={v.nid_back_url} alt="NID পেছনের পাশ" shape="wide" thumbClassName="h-24 w-40" />
            </div>
          )}
          {v.bmdc_document_url && (
            <div>
              <p className="mb-1 text-[11px] text-muted-foreground">BMDC প্রমাণপত্র</p>
              <PrivateStorageImageLightbox value={v.bmdc_document_url} alt="BMDC প্রমাণপত্র" shape="wide" thumbClassName="h-24 w-40" />
            </div>
          )}
          {v.trade_license_url && (
            <div>
              <p className="mb-1 text-[11px] text-muted-foreground">ট্রেড লাইসেন্স</p>
              <PrivateStorageImageLightbox value={v.trade_license_url} alt="ট্রেড লাইসেন্স" shape="wide" thumbClassName="h-24 w-40" />
            </div>
          )}
        </div>
      </div>

      {!readOnlyActions && (
        <div className="mt-4 flex flex-wrap gap-2">
          {v.status === VERIFICATION_STATUS.PENDING && <Button
            size="sm"
            disabled={busy}
            onClick={() => onUpdate(v.id, VERIFICATION_STATUS.UNDER_REVIEW)}
          >
            <ShieldCheck className="h-4 w-4" /> পর্যালোচনা শুরু
          </Button>}
          {v.status === VERIFICATION_STATUS.UNDER_REVIEW && <>
            <Button size="sm" disabled={busy} onClick={() => onUpdate(v.id, VERIFICATION_STATUS.APPROVED)}>
              <Check className="h-4 w-4" /> অনুমোদন
            </Button>
            <Button size="sm" variant="outline" disabled={busy} onClick={() => onUpdate(v.id, VERIFICATION_STATUS.REJECTED)}>
              <X className="h-4 w-4" /> প্রত্যাখ্যান
            </Button>
          </>}
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
