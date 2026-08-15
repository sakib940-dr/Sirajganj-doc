import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { CalendarDays, Eye, Heart, MapPin, UserRound, ArrowUpRight, Clock3 } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import PendingApprovalNotice from "@/components/seller/PendingApprovalNotice.jsx";
import { ROUTES } from "@/constants/routes";
import { ROLES, SELLER_STATUS, isAdminOrAbove } from "@/constants/roles";
import { getProviderDashboardSummary } from "@/services/providerService";

function Metric({ icon: Icon, label, value, href }) {
  const content = (
    <div className="rounded-2xl border border-border bg-card p-4 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
      <div className="flex items-start justify-between gap-3">
        <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
          <Icon className="h-5 w-5" />
        </span>
        {href && <ArrowUpRight className="h-4 w-4 text-muted-foreground" />}
      </div>
      <p className="mt-4 text-2xl font-bold">{value}</p>
      <p className="mt-1 text-xs text-muted-foreground">{label}</p>
    </div>
  );
  return href ? <Link to={href}>{content}</Link> : content;
}

export default function DashboardHome() {
  const { user, role, sellerStatus, profile } = useAuth();
  const [data, setData] = useState({ doctors: 0, appointments: 0, pending: 0, views: 0, saves: 0, loading: true });

  const approved = isAdminOrAbove(role) || ([ROLES.DOCTOR, ROLES.HOSPITAL].includes(role) && sellerStatus === SELLER_STATUS.APPROVED);

  useEffect(() => {
    if (!user || !approved) return;
    let active = true;
    (async () => {
      const { data: summary } = await getProviderDashboardSummary(role, user.id);
      if (active) setData({ ...summary, loading: false });
    })();
    return () => { active = false; };
  }, [user?.id, role, approved]);

  if (!approved) return <PendingApprovalNotice status={sellerStatus} />;

  const isHospital = role === ROLES.HOSPITAL;
  return (
    <div className="space-y-6">
      <section className="rounded-3xl border border-border bg-card p-5 shadow-sm sm:p-7">
        <div className="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-xs font-semibold text-primary">{isHospital ? "চেম্বার / হাসপাতাল" : "ডাক্তার প্যানেল"}</p>
            <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-3xl">স্বাগতম, {profile?.full_name || (isHospital ? "চেম্বার" : "ডাক্তার")}</h1>
            <p className="mt-2 max-w-xl text-sm text-muted-foreground">আপনার প্রোফাইল, রোগীর অ্যাপয়েন্টমেন্ট এবং চেম্বারের তথ্য এক জায়গা থেকে পরিচালনা করুন।</p>
          </div>
          <Link to={ROUTES.DASHBOARD_APPOINTMENTS} className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground shadow-sm">
            <CalendarDays className="h-4 w-4" /> অ্যাপয়েন্টমেন্ট দেখুন
          </Link>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        <Metric icon={UserRound} label={isHospital ? "ডাক্তার প্রোফাইল" : "আমার প্রোফাইল"} value={data.doctors} href={isHospital ? ROUTES.DASHBOARD_PRODUCTS : ROUTES.DASHBOARD_PERSONAL} />
        <Metric icon={CalendarDays} label="অপেক্ষমাণ অ্যাপয়েন্টমেন্ট" value={data.appointments} href={ROUTES.DASHBOARD_APPOINTMENTS} />
        <Metric icon={Eye} label="প্রোফাইল ভিউ" value={data.views} />
        <Metric icon={Heart} label="সংরক্ষণ" value={data.saves} />
        <Metric icon={Clock3} label="অপেক্ষমাণ ভেরিফিকেশন" value={data.pending} href={ROUTES.DASHBOARD_VERIFICATION} />
      </section>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Link to={ROUTES.DASHBOARD_PERSONAL} className="group rounded-2xl border border-border bg-card p-5 shadow-sm transition hover:border-primary/40 hover:shadow-md">
          <UserRound className="h-5 w-5 text-primary" />
          <h2 className="mt-4 font-semibold">ব্যক্তিগত তথ্য</h2>
          <p className="mt-1 text-sm text-muted-foreground">নাম, ছবি, যোগাযোগ ও পেশাগত তথ্য আপডেট করুন।</p>
        </Link>
        <Link to={ROUTES.DASHBOARD_SHOP} className="group rounded-2xl border border-border bg-card p-5 shadow-sm transition hover:border-primary/40 hover:shadow-md">
          <MapPin className="h-5 w-5 text-primary" />
          <h2 className="mt-4 font-semibold">চেম্বার / হাসপাতাল</h2>
          <p className="mt-1 text-sm text-muted-foreground">ঠিকানা, অবস্থান ও চেম্বারের তথ্য পরিচালনা করুন।</p>
        </Link>
        <Link to={ROUTES.DASHBOARD_WEBSITE} className="group rounded-2xl border border-border bg-card p-5 shadow-sm transition hover:border-primary/40 hover:shadow-md">
          <Eye className="h-5 w-5 text-primary" />
          <h2 className="mt-4 font-semibold">ওয়েবসাইট</h2>
          <p className="mt-1 text-sm text-muted-foreground">আপনার public chamber page সাজান ও preview দেখুন।</p>
        </Link>
      </section>
    </div>
  );
}
