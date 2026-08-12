import { Clock, XCircle } from "lucide-react";
import { SELLER_STATUS } from "@/constants/roles";

export default function PendingApprovalNotice({ status }) {
  const isRejected = status === SELLER_STATUS.REJECTED;
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
        {isRejected ? "আপনার ডাক্তার আবেদন প্রত্যাখ্যাত হয়েছে" : "আপনার ডাক্তার আবেদন পর্যালোচনাধীন"}
      </h2>
      <p className="max-w-sm text-sm text-muted-foreground">
        {isRejected
          ? "বিস্তারিত জানতে অনুগ্রহ করে অ্যাডমিনের সাথে যোগাযোগ করুন।"
          : "অ্যাডমিন আপনার আবেদন যাচাই করছেন। অনুমোদন হলে আপনি চেম্বার ও ডাক্তার প্রোফাইল ম্যানেজ করতে পারবেন।"}
      </p>
    </div>
  );
}
