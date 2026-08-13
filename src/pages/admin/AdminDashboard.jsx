import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Users, UserRound, Building2, ShieldCheck, HeartPulse, Ambulance, ArrowUpRight, UserCog } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { ROLES } from "@/constants/roles";
import { ROUTES } from "@/constants/routes";

function Card({ icon: Icon, label, value, href, accent = false }) {
  const body = <div className={`rounded-2xl border bg-card p-4 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md ${accent ? "border-primary/30" : "border-border"}`}>
    <div className="flex items-start justify-between"><span className={`flex h-10 w-10 items-center justify-center rounded-xl ${accent ? "bg-primary text-primary-foreground" : "bg-primary/10 text-primary"}`}><Icon className="h-5 w-5" /></span>{href && <ArrowUpRight className="h-4 w-4 text-muted-foreground" />}</div>
    <p className="mt-4 text-2xl font-bold">{value}</p><p className="mt-1 text-xs text-muted-foreground">{label}</p>
  </div>;
  return href ? <Link to={href}>{body}</Link> : body;
}

export default function AdminDashboard() {
  const { role, profile } = useAuth();
  const isSuper = role === ROLES.SUPER_ADMIN;
  const [s, setS] = useState({ doctors: 0, chambers: 0, patients: 0, pending: 0, ambulances: 0, donors: 0, loading: true });
  useEffect(() => {
    let active = true;
    (async () => {
      const queries = await Promise.all([
        supabase.from("profiles").select("id", { count: "exact", head: true }).eq("role", "doctor"),
        supabase.from("shops").select("id", { count: "exact", head: true }),
        supabase.from("profiles").select("id", { count: "exact", head: true }).eq("role", "patient"),
        supabase.from("profiles").select("id", { count: "exact", head: true }).eq("role", "doctor").eq("seller_status", "pending"),
        supabase.from("ambulances").select("id", { count: "exact", head: true }),
        supabase.from("blood_donors").select("id", { count: "exact", head: true }).eq("is_volunteer", true),
      ]);
      if (active) setS({ doctors: queries[0].count || 0, chambers: queries[1].count || 0, patients: queries[2].count || 0, pending: queries[3].count || 0, ambulances: queries[4].count || 0, donors: queries[5].count || 0, loading: false });
    })();
    return () => { active = false; };
  }, []);
  const adminLinks = [
    [ROUTES.ADMIN_SELLERS, UserRound, "ডাক্তার ব্যবস্থাপনা", "ডাক্তার অ্যাকাউন্ট ও প্রোফাইল পরিচালনা"],
    [ROUTES.ADMIN_VERIFICATIONS, ShieldCheck, "ভেরিফিকেশন", "নতুন আবেদন যাচাই ও অনুমোদন"],
    [ROUTES.ADMIN_USERS, Users, "ইউজার", "Patient, Doctor ও অন্যান্য অ্যাকাউন্ট"],
    [ROUTES.ADMIN_AMBULANCE, Ambulance, "অ্যাম্বুলেন্স", "সেবা প্রদানকারী পরিচালনা"],
  ];
  return <div className="space-y-6">
    <section className="rounded-3xl border border-border bg-card p-5 shadow-sm sm:p-7">
      <p className="text-xs font-semibold text-primary">{isSuper ? "সুপার অ্যাডমিন" : "অ্যাডমিন"}</p>
      <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-3xl">স্বাগতম, {profile?.full_name || "অ্যাডমিন"}</h1>
      <p className="mt-2 text-sm text-muted-foreground">সিরাজগঞ্জ ডাক্তার প্ল্যাটফর্মের গুরুত্বপূর্ণ কাজগুলো এক নজরে পরিচালনা করুন।</p>
    </section>
    <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
      <Card icon={UserRound} label="মোট ডাক্তার" value={s.doctors} href={ROUTES.ADMIN_SELLERS} />
      <Card icon={Building2} label="চেম্বার / হাসপাতাল" value={s.chambers} />
      <Card icon={Users} label="রোগী" value={s.patients} href={ROUTES.ADMIN_USERS} />
      <Card icon={ShieldCheck} label="অপেক্ষমাণ যাচাই" value={s.pending} href={ROUTES.ADMIN_VERIFICATIONS} accent={s.pending > 0} />
      <Card icon={HeartPulse} label="স্বেচ্ছাসেবী রক্তদাতা" value={s.donors} />
      <Card icon={Ambulance} label="অ্যাম্বুলেন্স" value={s.ambulances} href={ROUTES.ADMIN_AMBULANCE} />
    </section>
    <section>
      <div className="mb-3 flex items-end justify-between"><div><h2 className="text-lg font-bold">দ্রুত ব্যবস্থাপনা</h2><p className="text-sm text-muted-foreground">প্রয়োজনীয় কাজগুলো এখান থেকেই খুলুন।</p></div></div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">{adminLinks.map(([to, Icon, title, desc]) => <Link key={to} to={to} className="rounded-2xl border border-border bg-card p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md"><Icon className="h-5 w-5 text-primary"/><h3 className="mt-4 font-semibold">{title}</h3><p className="mt-1 text-sm text-muted-foreground">{desc}</p><span className="mt-4 inline-flex items-center gap-1 text-xs font-semibold text-primary">খুলুন <ArrowUpRight className="h-3.5 w-3.5"/></span></Link>)}</div>
    </section>
    {isSuper && <section className="rounded-2xl border border-primary/20 bg-primary/5 p-5"><div className="flex items-start gap-3"><UserCog className="mt-0.5 h-5 w-5 text-primary"/><div><h2 className="font-semibold">সুপার অ্যাডমিন নিয়ন্ত্রণ</h2><p className="mt-1 text-sm text-muted-foreground">রোল পরিবর্তন, অ্যাডমিন তৈরি এবং পুরো সিস্টেমের settings পরিচালনা করতে ইউজার ব্যবস্থাপনা ব্যবহার করুন।</p><Link to={ROUTES.ADMIN_USERS} className="mt-3 inline-flex items-center gap-1 text-sm font-semibold text-primary">ইউজার ব্যবস্থাপনা <ArrowUpRight className="h-4 w-4"/></Link></div></div></section>}
  </div>;
}
