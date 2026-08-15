import { useEffect, useState, useCallback } from "react";
import { Link } from "react-router-dom";
import {
  Check,
  X,
  Users,
  Ban,
  ShieldCheck,
  Loader2,
  UserCircle2,
  Phone,
  MapPin,
  Facebook,
  Map as MapIcon,
  BadgeCheck,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { formatDateBn } from "@/lib/utils";
import { useAuth } from "@/hooks/useAuth";
import PrivateStorageImageLightbox from "@/components/shared/PrivateStorageImageLightbox.jsx";
import { ROUTES } from "@/constants/routes";
import {
  ROLES,
  SELLER_STATUS,
  SELLER_STATUS_LABEL_BN,
  ROLE_LABEL_BN,
  ACCOUNT_STATUS,
  ACCOUNT_STATUS_LABEL_BN,
  VERIFICATION_STATUS_LABEL_BN,
} from "@/constants/roles";

export default function SellerManagePage() {
  // BUGFIX: আগে এই পেজে (Doctor Management) চেম্বারের "সর্বোচ্চ ডাক্তার প্রোফাইলের সীমা"
  // শুধু রিড-অনলি টেক্সট হিসেবে দেখানো হতো — Super Admin এখান থেকে সরাসরি
  // বাড়াতে/কমাতে পারতেন না (এডিট করার UI শুধু আলাদা "Users" পেজে ছিল, যা
  // অ্যাডমিনরা খুঁজে পাচ্ছিলেন না)। এখন এখান থেকেও (Super Admin হলে)
  // ইনপুট বক্সে সরাসরি বাড়ানো/কমানো যাবে — DB পলিসি/trigger আগে থেকেই
  // শুধু Super Admin-কে অনুমতি দেয় (guard_max_products_override), তাই
  // ব্যাকএন্ডে কোনো পরিবর্তন লাগেনি।
  const { role: myRole } = useAuth();
  const isSuperAdmin = myRole === ROLES.SUPER_ADMIN;
  const [profiles, setProfiles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);

  const [selected, setSelected] = useState(null); // ক্লিক করা ডাক্তার প্রোফাইল
  const [detail, setDetail] = useState(null); // { verification, shop }
  const [detailLoading, setDetailLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("profiles")
      .select("*")
      .in("role", ["doctor", "hospital"])
      .order("created_at", { ascending: false });
    setProfiles(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);


  const patchLocal = (id, patch) => {
    setProfiles((prev) => prev.map((p) => (p.id === id ? { ...p, ...patch } : p)));
    setSelected((prev) => (prev && prev.id === id ? { ...prev, ...patch } : prev));
  };

  const openDetail = async (profile) => {
    setSelected(profile);
    setActionError("");
    setDetail(null);
    setDetailLoading(true);

    const [{ data: verifications }, { data: shop }] = await Promise.all([
      supabase
        .from("seller_verifications")
        .select("*")
        .eq("user_id", profile.id)
        .order("created_at", { ascending: false })
        .limit(1),
      supabase.from("shops").select("*").eq("owner_id", profile.id).maybeSingle(),
    ]);
    const verification = verifications?.[0] ?? null;

    setDetail({ verification: verification ?? null, shop: shop ?? null });
    setDetailLoading(false);
  };

  const closeDetail = () => {
    setSelected(null);
    setDetail(null);
    setActionError("");
  };

  // চেম্বারের সর্বোচ্চ ডাক্তার প্রোফাইলের সীমা পরিবর্তন — শুধু Super Admin
  const updateMaxProducts = async (value) => {
    if (!detail?.shop) return;
    setBusy(true);
    setActionError("");
    const parsed = value === "" ? null : Math.max(1, parseInt(value, 10) || 1);
    const { error } = await supabase
      .from("shops")
      .update({ max_products_override: parsed })
      .eq("id", detail.shop.id);
    setBusy(false);
    if (error) {
      setActionError(error.message);
      return;
    }
    setDetail((prev) => ({ ...prev, shop: { ...prev.shop, max_products_override: parsed } }));
  };

  // ডাক্তার অ্যাকাউন্ট Active/Deactivate করা — Admin ও Super Admin উভয়েই পারবেন
  // (Edge Function সার্ভার-সাইডে যাচাই করে যে Admin শুধুমাত্র seller
  // অ্যাকাউন্টেই এই অ্যাকশন নিতে পারবেন, ডিলিট করতে পারবেন না)
  const toggleActive = async () => {
    if (!selected) return;
    const nextAction = selected.account_status === ACCOUNT_STATUS.BANNED ? "unban" : "ban";
    if (
      !window.confirm(
        nextAction === "ban"
          ? `"${selected.full_name || "এই প্রোভাইডার"}"-কে নিষ্ক্রিয় (deactivate) করতে চান? অ্যাকাউন্টটি আর লগইন করতে পারবে না।`
          : `"${selected.full_name || "এই প্রোভাইডার"}"-কে সক্রিয় (activate) করতে চান?`
      )
    )
      return;

    setBusy(true);
    setActionError("");
    const { data, error } = await supabase.functions.invoke("admin-manage-user", {
      body: { userId: selected.id, action: nextAction },
    });
    setBusy(false);
    if (error || data?.error) {
      setActionError(data?.error || error.message || "কাজটি ব্যর্থ হয়েছে।");
      return;
    }
    patchLocal(selected.id, {
      account_status: nextAction === "ban" ? ACCOUNT_STATUS.BANNED : ACCOUNT_STATUS.ACTIVE,
    });
  };

  if (loading) return <LoadingSpinner label="ডাক্তার ও হাসপাতাল তালিকা লোড হচ্ছে..." />;

  if (profiles.length === 0) {
    return <EmptyState icon={Users} title="এখনো কোনো ডাক্তার/হাসপাতাল আবেদন নেই" />;
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          ডাক্তার ও হাসপাতাল ম্যানেজমেন্ট
        </h1>
        <p className="text-sm text-muted-foreground">ডাক্তার বা হাসপাতালে ক্লিক করলে বিস্তারিত প্রোভাইডার তথ্য দেখা যাবে</p>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border bg-card">
        <table className="w-full text-sm">
          <thead className="border-b border-border bg-secondary/50 text-left">
            <tr>
              <th className="p-3 font-medium">নাম</th>
              <th className="p-3 font-medium">আবেদনের অবস্থা</th>
              <th className="p-3 font-medium">অ্যাকাউন্ট অবস্থা</th>
              <th className="p-3 font-medium">অ্যাকশন</th>
            </tr>
          </thead>
          <tbody>
            {profiles.map((p) => (
              <tr
                key={p.id}
                onClick={() => openDetail(p)}
                className="cursor-pointer border-b border-border last:border-0 hover:bg-secondary/40"
              >
                <td className="p-3">{p.full_name || "নাম নেই"}</td>
                <td className="p-3">
                  <span
                    className={`rounded-full px-2.5 py-1 text-xs font-medium ${
                      p.seller_status === SELLER_STATUS.APPROVED
                        ? "bg-primary/10 text-primary"
                        : p.seller_status === SELLER_STATUS.REJECTED
                        ? "bg-destructive/10 text-destructive"
                        : "bg-accent/15 text-accent"
                    }`}
                  >
                    {SELLER_STATUS_LABEL_BN[p.seller_status]}
                  </span>
                </td>
                <td className="p-3">
                  <span
                    className={`rounded-full px-2.5 py-1 text-xs font-medium ${
                      p.account_status === ACCOUNT_STATUS.BANNED
                        ? "bg-destructive/10 text-destructive"
                        : "bg-primary/10 text-primary"
                    }`}
                  >
                    {ACCOUNT_STATUS_LABEL_BN[p.account_status] || ACCOUNT_STATUS_LABEL_BN[ACCOUNT_STATUS.ACTIVE]}
                  </span>
                </td>
                <td className="p-3">
                  <div onClick={(e) => e.stopPropagation()}>
                    <Link to={ROUTES.ADMIN_VERIFICATIONS} className="inline-flex min-h-9 items-center rounded-lg border px-3 text-xs font-semibold text-primary">ভেরিফিকেশন দেখুন</Link>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={closeDetail}>
          <div
            className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-xl bg-card p-5 shadow-lg"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-4 flex items-start justify-between gap-3">
              <div className="flex items-center gap-3">
                {detail?.verification?.profile_photo_url ? (
                  <PrivateStorageImageLightbox
                    value={detail.verification.profile_photo_url}
                    alt={selected.full_name || "ভেরিফিকেশন প্রোফাইল ছবি"}
                    shape="square"
                    thumbClassName="h-14 w-14 rounded-full"
                  />
                ) : (
                  <UserCircle2 className="h-14 w-14 text-muted-foreground" />
                )}
                <div>
                  <h2 className="text-lg font-bold">{selected.full_name || "নাম নেই"}</h2>
                  <span className="inline-block rounded-full bg-secondary px-2.5 py-0.5 text-xs font-medium text-foreground/80">
                    {ROLE_LABEL_BN[selected.role] || "প্রোভাইডার"}
                  </span>
                </div>
              </div>
              <Button size="sm" variant="ghost" onClick={closeDetail}>
                <X className="h-4 w-4" />
              </Button>
            </div>

            {detailLoading ? (
              <LoadingSpinner label="তথ্য লোড হচ্ছে..." />
            ) : (
              <div className="space-y-3 text-sm">
                <DetailRow icon={Phone} label="ফোন নম্বর" value={selected.phone || detail?.verification?.phone} />
                <DetailRow icon={MapPin} label="ঠিকানা" value={detail?.verification?.address || detail?.shop?.address} />
                <DetailRow
                  icon={MapIcon}
                  label="গুগল ম্যাপ লোকেশন"
                  value={detail?.verification?.google_map_link || detail?.shop?.google_map_link}
                  isLink
                />
                <DetailRow
                  icon={Facebook}
                  label="ফেসবুক প্রোফাইল"
                  value={detail?.verification?.facebook_link || detail?.shop?.facebook_link}
                  isLink
                />
                <DetailRow
                  icon={BadgeCheck}
                  label="প্রোভাইডার ভেরিফিকেশন"
                  value={
                    detail?.verification
                      ? VERIFICATION_STATUS_LABEL_BN[detail.verification.status]
                      : "জমা দেওয়া হয়নি"
                  }
                />
                <DetailRow label="আবেদনের অবস্থা" value={SELLER_STATUS_LABEL_BN[selected.seller_status]} />
                <DetailRow label="যোগদান" value={formatDateBn(selected.created_at)} />
                <DetailRow
                  label="অ্যাকাউন্ট অবস্থা"
                  value={ACCOUNT_STATUS_LABEL_BN[selected.account_status] || ACCOUNT_STATUS_LABEL_BN[ACCOUNT_STATUS.ACTIVE]}
                />

                {detail?.shop && (
                  <div className="rounded-lg border border-border p-3">
                    <p className="mb-1 font-medium">চেম্বার: {detail.shop.shop_name}</p>
                    {isSuperAdmin ? (
                      <div className="flex items-center gap-2">
                        <label className="text-xs text-muted-foreground">সর্বোচ্চ ডাক্তার প্রোফাইলের সীমা:</label>
                        <input
                          key={detail.shop.id}
                          type="number"
                          min={1}
                          disabled={busy}
                          defaultValue={detail.shop.max_products_override ?? ""}
                          placeholder="৫০ (ডিফল্ট)"
                          className="w-24 rounded border border-border bg-background px-2 py-1 text-xs"
                          onBlur={(e) => updateMaxProducts(e.target.value)}
                        />
                      </div>
                    ) : (
                      <p className="text-xs text-muted-foreground">
                        সর্বোচ্চ ডাক্তার প্রোফাইলের সীমা: {detail.shop.max_products_override ?? 50}
                      </p>
                    )}
                  </div>
                )}

                {actionError && <p className="text-sm text-destructive">{actionError}</p>}

                <div className="space-y-3 border-t border-border pt-3">
                  <div className="rounded-xl bg-secondary/40 p-3">
                    <p className="text-xs text-muted-foreground">প্রোভাইডার অনুমোদন/প্রত্যাখ্যান এখন শুধুমাত্র ভেরিফিকেশন প্যানেল থেকে করা হয়।</p>
                    <Link to={ROUTES.ADMIN_VERIFICATIONS} className="mt-2 inline-flex min-h-9 items-center rounded-lg bg-primary px-3 text-xs font-semibold text-primary-foreground">ভেরিফিকেশন প্যানেল খুলুন</Link>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <Button size="sm" variant="outline" disabled={busy} onClick={toggleActive}>
                      {busy ? (
                        <Loader2 className="h-4 w-4 animate-spin" />
                      ) : selected.account_status === ACCOUNT_STATUS.BANNED ? (
                        <ShieldCheck className="h-4 w-4" />
                      ) : (
                        <Ban className="h-4 w-4" />
                      )}
                      {selected.account_status === ACCOUNT_STATUS.BANNED ? "সক্রিয় করুন (Activate)" : "নিষ্ক্রিয় করুন (Deactivate)"}
                    </Button>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    নিরাপত্তার জন্য প্রোভাইডার অ্যাকাউন্ট ডিলিট করার অনুমতি শুধুমাত্র Super Admin-এর আছে।
                  </p>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function DetailRow({ icon: Icon, label, value, isLink }) {
  return (
    <div className="flex items-start gap-2">
      {Icon && <Icon className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />}
      <div>
        <p className="text-xs text-muted-foreground">{label}</p>
        {value ? (
          isLink ? (
            <a href={value} target="_blank" rel="noreferrer" className="break-all text-primary underline">
              {value}
            </a>
          ) : (
            <p className="break-words">{value}</p>
          )
        ) : (
          <p className="text-muted-foreground">—</p>
        )}
      </div>
    </div>
  );
}
