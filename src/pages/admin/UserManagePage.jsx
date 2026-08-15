import { useEffect, useState, useCallback } from "react";
import { Link } from "react-router-dom";
import {
  Users,
  X,
  Ban,
  ShieldCheck,
  Trash2,
  MapPin,
  Facebook,
  Map as MapIcon,
  Phone,
  BadgeCheck,
  Loader2,
  UserCircle2,
  Navigation,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { formatDateBn } from "@/lib/utils";
import PrivateStorageImageLightbox from "@/components/shared/PrivateStorageImageLightbox.jsx";
import { fetchSuperAdminUserLocations } from "@/services/adminMedicalService";
import { ROUTES } from "@/constants/routes";
import {
  ROLES,
  ROLE_LABEL_BN,
  ACCOUNT_STATUS,
  ACCOUNT_STATUS_LABEL_BN,
  VERIFICATION_STATUS_LABEL_BN,
} from "@/constants/roles";

const ROLE_BADGE_CLASS = {
  [ROLES.SUPER_ADMIN]: "bg-primary/10 text-primary",
  [ROLES.ADMIN]: "bg-accent/15 text-accent",
  [ROLES.DOCTOR]: "bg-secondary text-foreground/80",
  [ROLES.HOSPITAL]: "bg-accent/10 text-accent",
  [ROLES.PATIENT]: "bg-muted text-muted-foreground",
};

// সিস্টেমে সবসময় ঠিক ১ জনই Super Admin থাকেন (protected, singleton) — তাই
// এখান থেকে কাউকে নতুন করে Super Admin বানানোর অপশন রাখা হয়নি (DB লেভেলেও
// এটি ব্লক করা আছে — দেখুন 0018_super_admin_singleton.sql)। নিজের
// অ্যাকাউন্ট (অর্থাৎ একমাত্র বিদ্যমান Super Admin) এই প্যানেল থেকে এডিট
// করা যায় না, তাই এই তালিকায় SUPER_ADMIN থাকারও দরকার নেই।
const ROLE_OPTIONS = [ROLES.PATIENT, ROLES.DOCTOR, ROLES.HOSPITAL, ROLES.ADMIN];

export default function UserManagePage() {
  const { user: currentUser, role: myRole } = useAuth();
  const isSuperAdmin = myRole === ROLES.SUPER_ADMIN;

  const [profiles, setProfiles] = useState([]);
  const [locations, setLocations] = useState({});
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null); // profile row that was clicked
  const [detail, setDetail] = useState(null); // { verification, shop }
  const [detailLoading, setDetailLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    const [{ data }, locationResult] = await Promise.all([
      supabase.from("profiles").select("*").order("created_at", { ascending: false }),
      isSuperAdmin ? fetchSuperAdminUserLocations() : Promise.resolve({ data: [] }),
    ]);
    setProfiles(data ?? []);
    const locationMap = {};
    for (const row of locationResult?.data || []) locationMap[row.user_id] = row;
    setLocations(locationMap);
    setLoading(false);
  }, [isSuperAdmin]);

  useEffect(() => {
    load();
  }, [load]);

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

  const patchLocal = (id, patch) => {
    setProfiles((prev) => prev.map((p) => (p.id === id ? { ...p, ...patch } : p)));
    setSelected((prev) => (prev && prev.id === id ? { ...prev, ...patch } : prev));
  };

  const changeRole = async (newRole) => {
    if (!selected) return;
    if (
      !window.confirm(
        `"${selected.full_name || selected.email}"-এর role "${ROLE_LABEL_BN[newRole]}"-এ পরিবর্তন করতে চান?`
      )
    )
      return;
    setBusy(true);
    setActionError("");
    const { error } = await supabase.from("profiles").update({ role: newRole }).eq("id", selected.id);
    setBusy(false);
    if (error) {
      setActionError(error.message);
      return;
    }
    patchLocal(selected.id, { role: newRole });
  };


  const toggleBan = async () => {
    if (!selected) return;
    const nextAction = selected.account_status === ACCOUNT_STATUS.BANNED ? "unban" : "ban";
    if (
      !window.confirm(
        nextAction === "ban"
          ? `"${selected.full_name || selected.email}"-কে ব্যান করতে চান? এই ইউজার আর লগইন করতে পারবে না।`
          : `"${selected.full_name || selected.email}"-এর ব্যান তুলে নিতে চান?`
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

  const deleteUser = async () => {
    if (!selected) return;
    if (
      !window.confirm(
        `"${selected.full_name || selected.email}"-কে সম্পূর্ণভাবে মুছে ফেলতে চান? এই কাজটি ফিরিয়ে নেওয়া যাবে না।`
      )
    )
      return;

    setBusy(true);
    setActionError("");
    const { data, error } = await supabase.functions.invoke("admin-manage-user", {
      body: { userId: selected.id, action: "delete" },
    });
    setBusy(false);
    if (error || data?.error) {
      setActionError(data?.error || error.message || "ডিলিট ব্যর্থ হয়েছে।");
      return;
    }
    setProfiles((prev) => prev.filter((p) => p.id !== selected.id));
    closeDetail();
  };

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

  if (loading) return <LoadingSpinner label="ইউজার তালিকা লোড হচ্ছে..." />;

  if (profiles.length === 0) {
    return <EmptyState icon={Users} title="কোনো ইউজার পাওয়া যায়নি" />;
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          ইউজার (রোলসহ)
        </h1>
        <p className="text-sm text-muted-foreground">
          একজন ইউজারে ক্লিক করলে বিস্তারিত তথ্য দেখা যাবে
          {!isSuperAdmin && " — role পরিবর্তন, ব্যান/আনব্যান বা ডিলিট শুধুমাত্র নির্দিষ্ট Admin করতে পারবেন"}
        </p>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border bg-card">
        <table className="w-full text-sm">
          <thead className="border-b border-border bg-secondary/50 text-left">
            <tr>
              <th className="p-3 font-medium">প্রোফাইল</th>
              <th className="p-3 font-medium">নাম</th>
              <th className="p-3 font-medium">ফোন</th>
              <th className="p-3 font-medium">রোল</th>
              <th className="p-3 font-medium">শেষ লোকেশন</th>
              <th className="p-3 font-medium">অ্যাকাউন্ট অবস্থা</th>
            </tr>
          </thead>
          <tbody>
            {profiles.map((p) => (
              <tr
                key={p.id}
                onClick={() => openDetail(p)}
                className="cursor-pointer border-b border-border last:border-0 hover:bg-secondary/40"
              >
                <td className="p-3">
                  <UserCircle2 className="h-8 w-8 text-muted-foreground" />
                </td>
                <td className="p-3">
                  {p.full_name || "—"} {p.id === currentUser.id && <span className="text-xs text-muted-foreground">(আপনি)</span>}
                </td>
                <td className="p-3 text-muted-foreground">{p.phone || "—"}</td>
                <td className="p-3">
                  <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${ROLE_BADGE_CLASS[p.role] || ROLE_BADGE_CLASS[ROLES.PATIENT]}`}>
                    {ROLE_LABEL_BN[p.role] || p.role}
                  </span>
                </td>
                <td className="p-3 text-xs text-muted-foreground"><div className="flex flex-wrap items-center gap-2"><span>{[locations[p.id]?.upazila, locations[p.id]?.district].filter(Boolean).join(", ") || "লোকেশন নেই"}</span>{locations[p.id]?.latitude != null && locations[p.id]?.longitude != null && <a onClick={(e)=>e.stopPropagation()} target="_blank" rel="noreferrer" href={`https://www.google.com/maps/search/?api=1&query=${locations[p.id].latitude},${locations[p.id].longitude}`} className="inline-flex min-h-8 items-center gap-1 rounded-lg border bg-card px-2 text-[11px] font-semibold text-primary"><Navigation className="h-3.5 w-3.5"/> Maps</a>}</div></td>
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
                  <span className={`inline-block rounded-full px-2.5 py-0.5 text-xs font-medium ${ROLE_BADGE_CLASS[selected.role]}`}>
                    {ROLE_LABEL_BN[selected.role] || selected.role}
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
                  value={detail?.verification ? VERIFICATION_STATUS_LABEL_BN[detail.verification.status] : "জমা দেওয়া হয়নি"}
                />
                {isSuperAdmin && <div className="rounded-xl border border-border bg-secondary/30 p-3">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-xs text-muted-foreground">শেষ জানা লোকেশন</p>
                      <p className="mt-1 font-medium">{[locations[selected.id]?.upazila, locations[selected.id]?.district].filter(Boolean).join(", ") || "লোকেশন পাওয়া যায়নি"}</p>
                      {locations[selected.id]?.updated_at && <p className="mt-1 text-xs text-muted-foreground">আপডেট: {formatDateBn(locations[selected.id].updated_at)} • উৎস: {locations[selected.id].source === "gps" ? "GPS" : locations[selected.id].source === "manual" ? "ম্যানুয়াল" : locations[selected.id].source || "—"}{locations[selected.id].accuracy_m != null ? ` • নির্ভুলতা ~${Math.round(locations[selected.id].accuracy_m)} মিটার` : ""}</p>}
                    </div>
                    {locations[selected.id]?.latitude != null && locations[selected.id]?.longitude != null && <a target="_blank" rel="noreferrer" href={`https://www.google.com/maps/search/?api=1&query=${locations[selected.id].latitude},${locations[selected.id].longitude}`} className="inline-flex min-h-10 shrink-0 items-center gap-1 rounded-lg border bg-card px-3 text-xs font-semibold text-primary"><Navigation className="h-4 w-4"/> Google Maps</a>}
                  </div>
                </div>}
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

                {selected.id === currentUser.id ? (
                  <p className="text-xs text-muted-foreground">(এটি আপনার নিজের অ্যাকাউন্ট)</p>
                ) : isSuperAdmin ? (
                  <div className="space-y-3 border-t border-border pt-3">
                    <div>
                      <label className="mb-1 block text-xs font-medium text-muted-foreground">Role পরিবর্তন করুন</label>
                      <select
                        disabled={busy}
                        value={selected.role}
                        onChange={(e) => changeRole(e.target.value)}
                        className="w-full rounded border border-border bg-background px-2 py-1.5 text-sm"
                      >
                        {ROLE_OPTIONS.map((r) => (
                          <option key={r} value={r}>
                            {ROLE_LABEL_BN[r]}
                          </option>
                        ))}
                      </select>
                    </div>
                    {(selected.role === ROLES.DOCTOR || selected.role === ROLES.HOSPITAL) && (
                      <div className="rounded-xl border border-border bg-secondary/30 p-3">
                        <p className="text-xs font-medium">প্রোভাইডার অবস্থা: <strong>{selected.seller_status === "approved" ? "অনুমোদিত" : selected.seller_status === "rejected" ? "প্রত্যাখ্যাত" : "অপেক্ষমাণ"}</strong></p>
                        <p className="mt-1 text-xs text-muted-foreground">নিরাপত্তার জন্য প্রোভাইডার অনুমোদন শুধুমাত্র ভেরিফিকেশন প্যানেল থেকে করা যাবে।</p>
                        <Link to={ROUTES.ADMIN_VERIFICATIONS} className="mt-2 inline-flex min-h-9 items-center rounded-lg bg-primary px-3 text-xs font-semibold text-primary-foreground">ভেরিফিকেশন প্যানেল খুলুন</Link>
                      </div>
                    )}
                    <div className="flex flex-wrap gap-2">
                      <Button size="sm" variant="outline" disabled={busy} onClick={toggleBan}>
                        {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : selected.account_status === ACCOUNT_STATUS.BANNED ? (
                          <ShieldCheck className="h-4 w-4" />
                        ) : (
                          <Ban className="h-4 w-4" />
                        )}
                        {selected.account_status === ACCOUNT_STATUS.BANNED ? "আনব্যান করুন" : "ব্যান করুন"}
                      </Button>
                      <Button size="sm" variant="destructive" disabled={busy} onClick={deleteUser}>
                        <Trash2 className="h-4 w-4" /> ডিলিট করুন
                      </Button>
                    </div>
                  </div>
                ) : (
                  <p className="border-t border-border pt-3 text-xs text-muted-foreground">
                    Role পরিবর্তন, ব্যান/আনব্যান বা ডিলিট করার অনুমতি শুধুমাত্র নির্দিষ্ট Admin-এর আছে।
                  </p>
                )}
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
