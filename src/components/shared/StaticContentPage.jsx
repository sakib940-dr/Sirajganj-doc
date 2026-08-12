import { Link } from "react-router-dom";
import { ChevronLeft, FileText } from "lucide-react";
import { ROUTES } from "@/constants/routes";
import EmptyState from "@/components/shared/EmptyState.jsx";

// About Us, Terms & Conditions, Privacy Policy — তিনটে পেজই বিদ্যমান
// Super Admin CMS (site_settings টেবিলের about_us_content /
// terms_conditions_content / privacy_policy_content) থেকে কনটেন্ট নেয়।
// এই কনটেন্ট আগে থেকেই admin panel-এ এডিট করা যেত, কিন্তু পাবলিক সাইটে
// কোথাও প্রদর্শিত হতো না — এখন হ্যামবার্গার মেনু থেকে দেখা যাবে। কোনো
// নতুন backend/টেবিল লাগেনি, শুধু বিদ্যমান useSiteSettings হুক ব্যবহার হয়েছে।
export default function StaticContentPage({ title, content, loading }) {
  return (
    <div className="container max-w-2xl py-6 md:py-10">
      <div className="mb-6 flex items-center gap-2">
        <Link
          to={ROUTES.HOME}
          className="flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-secondary"
          aria-label="ফিরে যান"
        >
          <ChevronLeft className="h-5 w-5" />
        </Link>
        <h1 className="text-xl font-bold md:text-2xl" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          {title}
        </h1>
      </div>

      {loading ? null : !content?.trim() ? (
        <EmptyState
          icon={FileText}
          title="এখনো কোনো কনটেন্ট যোগ করা হয়নি"
          description="অ্যাডমিন প্যানেল থেকে এই পাতার কনটেন্ট যোগ করলে তা এখানে দেখা যাবে।"
        />
      ) : (
        <div className="whitespace-pre-line rounded-xl border border-border bg-card p-5 text-sm leading-relaxed text-foreground/90 md:p-8 md:text-base">
          {content}
        </div>
      )}
    </div>
  );
}
