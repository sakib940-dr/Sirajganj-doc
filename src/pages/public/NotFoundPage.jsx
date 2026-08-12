import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { ROUTES } from "@/constants/routes";

export default function NotFoundPage() {
  return (
    <div className="container flex flex-col items-center justify-center py-24 text-center">
      <p className="text-6xl font-bold text-primary" style={{ fontFamily: "'Tiro Bangla', serif" }}>
        ৪০৪
      </p>
      <h1 className="mt-4 text-xl font-semibold">পেজটি খুঁজে পাওয়া যায়নি</h1>
      <p className="mt-2 text-sm text-muted-foreground">
        আপনি যে পেজটি খুঁজছেন তা হয়তো সরিয়ে ফেলা হয়েছে অথবা কখনো ছিল না।
      </p>
      <Button asChild className="mt-6">
        <Link to={ROUTES.HOME}>হোমপেজে ফিরে যান</Link>
      </Button>
    </div>
  );
}
