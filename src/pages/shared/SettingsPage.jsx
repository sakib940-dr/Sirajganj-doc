import { Link } from "react-router-dom";
import { ChevronRight, FileText, HelpCircle, Info, MessageSquareHeart, ShieldQuestion, ShieldCheck } from "lucide-react";
import { ROUTES } from "@/constants/routes";
import { useAuth } from "@/hooks/useAuth";
import { ROLE_LABEL_BN } from "@/constants/roles";

const items = [
  [ROUTES.HELP, "সাহায্য", HelpCircle],
  [ROUTES.ABOUT, "আমাদের সম্পর্কে", Info],
  [ROUTES.FAQ, "সচরাচর জিজ্ঞাসিত প্রশ্ন", ShieldQuestion],
  [ROUTES.FEEDBACK, "মতামত জানান", MessageSquareHeart],
  [ROUTES.TERMS, "শর্তাবলী", FileText],
  [ROUTES.PRIVACY, "প্রাইভেসি পলিসি", ShieldCheck],
];

export default function SettingsPage() {
  const { role } = useAuth();
  return (
    <div className="mx-auto max-w-2xl space-y-5">
      <div>
        <h1 className="text-xl font-bold" style={{fontFamily:"'Tiro Bangla', serif"}}>সেটিংস</h1>
        <p className="mt-1 text-sm text-muted-foreground">{ROLE_LABEL_BN[role]} অ্যাকাউন্টের তথ্য ও সাধারণ সেটিংস</p>
      </div>
      <div className="overflow-hidden rounded-2xl border border-border bg-card">
        {items.map(([to,label,Icon], i) => (
          <Link key={to} to={to} className={`flex items-center justify-between px-4 py-4 hover:bg-secondary/50 ${i ? "border-t border-border" : ""}`}>
            <span className="flex items-center gap-3 text-sm font-medium"><Icon className="h-5 w-5 text-muted-foreground" />{label}</span>
            <ChevronRight className="h-4 w-4 text-muted-foreground" />
          </Link>
        ))}
      </div>
    </div>
  );
}
