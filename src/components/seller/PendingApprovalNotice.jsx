import { Clock, XCircle, ShieldCheck } from "lucide-react";
import { Link } from "react-router-dom";
import { ROUTES } from "@/constants/routes";
import { SELLER_STATUS } from "@/constants/roles";

export default function PendingApprovalNotice({ status, role = "doctor" }) {
  const isRejected = status === SELLER_STATUS.REJECTED;
  const isHospital = role === "hospital";
  const providerLabel = isHospital ? "হাসপাতাল/চেম্বার" : "ডাক্তার";
  return (
    <div className="flex flex-col items-center gap-3 rounded-xl border border-dashed border-border bg-card p-10 text-center">
      <span
        className={`flex h-12 w-12 items-center justify-center rounded-full ${
          isRejected ? "bg-destructive/10 text-destructive" : "bg-accent/15 text-accent"
        }`}
      >
        {isRejected ? <XCircle className="h-6 w-6" /> : <Clock className="h-6 w-6" />}
      </span>
      <h2 className="text-lg font-semibold">
        {isRejected ? `আপনার ${providerLabel} আবেদন প্রত্যাখ্যাত হয়েছে` : `আপনার ${providerLabel} আবেদন পর্যালোচনাধীন`}
      </h2>
      <p className="max-w-sm text-sm text-muted-foreground">
        {isRejected
          ? "বিস্তারিত জানতে অনুগ্রহ করে অ্যাডমিনের সাথে যোগাযোগ করুন।"
          : `অ্যাডমিন আপনার আবেদন যাচাই করছেন। অনুমোদন হলে আপনি ${isHospital ? "ডাক্তার সংযোগ, সময়সূচি ও প্রতিষ্ঠান" : "চেম্বার, সময়সূচি ও ডাক্তার প্রোফাইল"} ম্যানেজ করতে পারবেন।`}
      </p>
      <Link to={ROUTES.DASHBOARD_VERIFICATION} className="mt-2 inline-flex items-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground">
        <ShieldCheck className="h-4 w-4" /> ভেরিফিকেশন করুন
      </Link>
    </div>
  );
}
