import { Link } from "react-router-dom";
import { CalendarDays, Heart, Search, UserRound, LogOut } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useAuth } from "@/hooks/useAuth";
import { ROUTES } from "@/constants/routes";

export default function PatientDashboardPage() {
  const { profile, signOut } = useAuth();

  return (
    <div className="container mx-auto max-w-5xl px-4 py-6">
      <div className="mb-6 flex flex-col gap-4 rounded-2xl border bg-card p-5 shadow-sm sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm text-muted-foreground">রোগী ড্যাশবোর্ড</p>
          <h1 className="mt-1 text-2xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
            স্বাগতম, {profile?.full_name || "রোগী"}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">আপনার ডাক্তার ও অ্যাপয়েন্টমেন্ট এক জায়গায় দেখুন।</p>
        </div>
        <Button variant="outline" onClick={signOut} className="gap-2 self-start sm:self-auto">
          <LogOut className="h-4 w-4" /> লগআউট
        </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Link to={ROUTES.DOCTORS}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><Search className="h-6 w-6 text-primary" /><CardTitle className="text-base">ডাক্তার খুঁজুন</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">বিশেষত্ব ও এলাকার ভিত্তিতে ডাক্তার দেখুন।</p></CardContent>
          </Card>
        </Link>
        <Link to={ROUTES.APPOINTMENTS}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><CalendarDays className="h-6 w-6 text-primary" /><CardTitle className="text-base">অ্যাপয়েন্টমেন্ট</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">আপনার অনুরোধ ও অ্যাপয়েন্টমেন্টের অবস্থা দেখুন।</p></CardContent>
          </Card>
        </Link>
        <Link to={ROUTES.SAVED}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><Heart className="h-6 w-6 text-primary" /><CardTitle className="text-base">সংরক্ষিত ডাক্তার</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">পছন্দের ডাক্তারগুলো দ্রুত খুঁজে নিন।</p></CardContent>
          </Card>
        </Link>
        <Link to={ROUTES.ACCOUNT}>
          <Card className="h-full transition hover:-translate-y-0.5 hover:shadow-md">
            <CardHeader><UserRound className="h-6 w-6 text-primary" /><CardTitle className="text-base">আমার প্রোফাইল</CardTitle></CardHeader>
            <CardContent><p className="text-sm text-muted-foreground">নাম, ফোন ও অ্যাকাউন্টের তথ্য আপডেট করুন।</p></CardContent>
          </Card>
        </Link>
      </div>
    </div>
  );
}
