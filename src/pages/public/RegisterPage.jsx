import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Store } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { useAuth } from "@/hooks/useAuth";
import { supabase } from "@/lib/supabaseClient";
import { ROUTES } from "@/constants/routes";

export default function RegisterPage() {
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [accountType, setAccountType] = useState("patient");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const { signUp, refreshProfile } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setSubmitting(true);

    const { data, error: signUpError } = await signUp(email, password, fullName, phone);
    if (signUpError) {
      setError(signUpError.message || "রেজিস্ট্রেশন ব্যর্থ হয়েছে।");
      setSubmitting(false);
      return;
    }

    // Provider account হলে নিরাপদ RPC-এর মাধ্যমে আবেদন পাঠানো হয়।
    let rpcFailed = false;
    if (accountType !== "patient" && data?.user) {
      const rpcName = accountType === "doctor" ? "request_doctor_status" : "request_hospital_status";
      const { error: rpcError } = await supabase.rpc(rpcName);
      if (rpcError) {
        // CRITICAL FIX: আগে এই error চেক করা হতো না — RPC silently ব্যর্থ
        // হলেও ইউজার কিছু বুঝতে পারতো না এবং role কখনো 'seller' হতো না,
        // ফলে Dashboard এ ঢুকতে গেলে normal visitor হিসেবে Home এ redirect
        // হয়ে যেত।
        // eslint-disable-next-line no-console
        console.error("ডাক্তার আবেদন ব্যর্থ হয়েছে:", rpcError.message);
        rpcFailed = true;
        setError(
          `অ্যাকাউন্ট তৈরি হয়েছে, কিন্তু ${accountType === "doctor" ? "ডাক্তার" : "চেম্বার/হাসপাতাল"} আবেদন পাঠাতে সমস্যা হয়েছে। কিছুক্ষণ পর লগইন করে আবার চেষ্টা করুন অথবা সাপোর্টে যোগাযোগ করুন।`
        );
      }
    }

    // CRITICAL FIX: RPC কল করার পর ডাটাবেসে role/seller_status বদলে গেলেও
    // AuthContext-এর local state (useAuth থেকে পাওয়া role) সাথে সাথে আপডেট
    // হয় না — কারণ onAuthStateChange listener আলাদা async flow-এ চলে।
    // navigate করার আগে explicit ভাবে profile refresh করে নেওয়া হচ্ছে,
    // যাতে ProtectedRoute সঠিক (নতুন) role দেখে সঠিক জায়গায় নিয়ে যায়।
    await refreshProfile(data?.user?.id);

    setSubmitting(false);

    // RPC ব্যর্থ হলে এই পেজেই থাকুক, যাতে error message দেখতে পায়
    if (!rpcFailed) {
      navigate(ROUTES.DASHBOARD);
    }
  };

  return (
    <div className="container flex min-h-[80vh] items-center justify-center py-12">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          <span className="mb-2 flex h-11 w-11 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <Store className="h-5 w-5" />
          </span>
          <CardTitle style={{ fontFamily: "'Tiro Bangla', serif" }}>নতুন অ্যাকাউন্ট</CardTitle>
          <CardDescription>রোগী হিসেবে শুরু করুন, চাইলে ডাক্তার হওয়ার আবেদনও করতে পারবেন</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="fullName">পুরো নাম</Label>
              <Input
                id="fullName"
                required
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                placeholder="আপনার নাম"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="email">ইমেইল</Label>
              <Input
                id="email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="phone">মোবাইল নম্বর</Label>
              <Input
                id="phone"
                type="tel"
                required
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="01XXXXXXXXX"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="password">পাসওয়ার্ড</Label>
              <Input
                id="password"
                type="password"
                required
                minLength={6}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="কমপক্ষে ৬ ডিজিট"
              />
            </div>
            <div className="space-y-2">
              <Label>অ্যাকাউন্টের ধরন</Label>
              <div className="grid gap-2 sm:grid-cols-3">
                {[
                  ["patient", "রোগী"],
                  ["doctor", "ডাক্তার"],
                  ["hospital", "চেম্বার / হাসপাতাল"],
                ].map(([value, label]) => (
                  <label key={value} className={`flex cursor-pointer items-center gap-2 rounded-xl border p-3 text-sm ${accountType === value ? "border-primary bg-primary/5" : "border-border"}`}>
                    <input type="radio" name="accountType" value={value} checked={accountType === value} onChange={() => setAccountType(value)} />
                    <span>{label}</span>
                  </label>
                ))}
              </div>
              {accountType !== "patient" && <p className="text-xs text-muted-foreground">এই অ্যাকাউন্টটি ভেরিফিকেশন/অ্যাডমিন অনুমোদনের পর প্রকাশ্য তথ্য যোগ করতে পারবে।</p>}
            </div>
            {error && <p className="text-sm text-destructive">{error}</p>}
            <Button type="submit" className="w-full" disabled={submitting}>
              {submitting ? "তৈরি হচ্ছে..." : "অ্যাকাউন্ট তৈরি করুন"}
            </Button>
          </form>
          <p className="mt-5 text-center text-sm text-muted-foreground">
            আগে থেকেই অ্যাকাউন্ট আছে?{" "}
            <Link to={ROUTES.LOGIN} className="font-medium text-primary hover:underline">
              লগইন করুন
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
