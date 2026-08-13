import { useEffect, useState, useCallback } from "react";
import { KeyRound, Copy, Check, X, ShieldAlert } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { Button } from "@/components/ui/button";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { ROLE_LABEL_BN } from "@/constants/roles";

function generatePassword() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
  let pass = "";
  for (let i = 0; i < 10; i++) pass += chars[Math.floor(Math.random() * chars.length)];
  return pass;
}

export default function CredentialsPage() {
  const [profiles, setProfiles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);
  const [resetResult, setResetResult] = useState(null);
  const [resetError, setResetError] = useState("");
  const [copied, setCopied] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase.from("profiles").select("*").order("created_at", { ascending: false });
    setProfiles(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleResetPassword = async (profile) => {
    if (
      !window.confirm(
        `"${profile.full_name || profile.email}" এর পাসওয়ার্ড রিসেট করতে চান? পুরনো পাসওয়ার্ড আর কাজ করবে না।`
      )
    )
      return;

    setBusyId(profile.id);
    setResetError("");
    const newPassword = generatePassword();

    const { data, error } = await supabase.functions.invoke("admin-reset-password", {
      body: { userId: profile.id, newPassword },
    });

    setBusyId(null);

    if (error || data?.error) {
      setResetError(data?.error || error.message || "পাসওয়ার্ড রিসেট ব্যর্থ হয়েছে।");
      return;
    }

    setResetResult({ name: profile.full_name || profile.email, password: newPassword });
  };

  const copyPassword = () => {
    navigator.clipboard.writeText(resetResult.password);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          লগইন অ্যাক্সেস
        </h1>
        <p className="text-sm text-muted-foreground">শুধুমাত্র নির্দিষ্ট Admin এই পেজ দেখতে পারবেন</p>
      </div>

      <div className="rounded-2xl border border-primary/20 bg-primary/5 p-4">
        <h2 className="font-semibold">সুপার অ্যাডমিন লগইন সেটআপ</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          সুপার অ্যাডমিনের ইমেইল/পাসওয়ার্ড Supabase Authentication-এ তৈরি হবে। পাসওয়ার্ড অ্যাপে বা ডাটাবেসে সংরক্ষণ করা হয় না।
        </p>
        <pre className="mt-3 overflow-x-auto rounded-xl bg-card p-3 text-xs leading-relaxed">{`UPDATE public.profiles
SET role = 'super_admin', seller_status = 'approved'
WHERE id = (
  SELECT id FROM auth.users
  WHERE email = 'YOUR_SUPER_ADMIN_EMAIL'
);`}</pre>
        <p className="mt-2 text-xs text-muted-foreground">
          প্রথমবার account তৈরি করার পর এই SQL একবার চালালেই ওই account Super Admin হবে।
        </p>
      </div>

      <div className="flex items-start gap-3 rounded-xl border border-accent/30 bg-accent/10 p-4 text-sm">
        <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0 text-accent" />
        <p>
          নিরাপত্তার জন্য কোনো ইউজারের পাসওয়ার্ড এখানে প্লেইন টেক্সটে সংরক্ষণ বা প্রদর্শন করা হয় না — এটি
          Supabase Auth নিজেই hash করে রাখে, কেউ (Admin সহ) তা দেখতে পারে না। এর বদলে আপনি যেকোনো
          ইউজারের জন্য একটি নতুন পাসওয়ার্ড <strong>তৈরি করে সেট</strong> করতে পারবেন, যা একবার এখানে দেখানো
          হবে — সেটি কপি করে ইউজারকে নিরাপদ চ্যানেলে (ফোনে বলে বা ব্যক্তিগত মেসেজে) জানিয়ে দিন।
        </p>
      </div>

      {resetResult && (
        <div className="flex items-center justify-between gap-4 rounded-xl border border-accent bg-accent/10 p-4">
          <div>
            <p className="text-sm font-medium">
              {resetResult.name}-এর নতুন পাসওয়ার্ড তৈরি হয়েছে — এখনই কপি করে নিন, পরে আর দেখা যাবে না:
            </p>
            <p className="mt-1 rounded bg-card px-3 py-1.5 font-mono text-base font-semibold tracking-wide">
              {resetResult.password}
            </p>
          </div>
          <div className="flex shrink-0 gap-2">
            <Button size="sm" variant="outline" onClick={copyPassword}>
              {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
              {copied ? "কপি হয়েছে" : "কপি করুন"}
            </Button>
            <Button size="sm" variant="ghost" onClick={() => setResetResult(null)}>
              <X className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}

      {resetError && <p className="text-sm text-destructive">{resetError}</p>}

      {profiles.length === 0 ? (
        <EmptyState icon={KeyRound} title="কোনো ইউজার পাওয়া যায়নি" />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border bg-card">
          <table className="w-full text-sm">
            <thead className="border-b border-border bg-secondary/50 text-left">
              <tr>
                <th className="p-3 font-medium">নাম</th>
                <th className="p-3 font-medium">ইমেইল</th>
                <th className="p-3 font-medium">রোল</th>
                <th className="p-3 font-medium">অ্যাকশন</th>
              </tr>
            </thead>
            <tbody>
              {profiles.map((p) => (
                <tr key={p.id} className="border-b border-border last:border-0">
                  <td className="p-3">{p.full_name || "—"}</td>
                  <td className="p-3 text-muted-foreground">{p.email || "—"}</td>
                  <td className="p-3 text-muted-foreground">{ROLE_LABEL_BN[p.role] || p.role}</td>
                  <td className="p-3">
                    <Button size="sm" variant="outline" disabled={busyId === p.id} onClick={() => handleResetPassword(p)}>
                      <KeyRound className="h-4 w-4" /> পাসওয়ার্ড রিসেট
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
