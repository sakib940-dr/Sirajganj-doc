import { useState } from "react";
import { Link, useNavigate, useLocation } from "react-router-dom";
import { Stethoscope } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { useAuth } from "@/hooks/useAuth";
import { supabase } from "@/lib/supabaseClient";
import { ROUTES } from "@/constants/routes";
import { ROLES } from "@/constants/roles";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setSubmitting(true);
    const { data, error } = await signIn(email, password);
    setSubmitting(false);
    if (error) {
      setError("ইমেইল অথবা পাসওয়ার্ড সঠিক নয়।");
      return;
    }

    // Login সফল হলে সবসময় role অনুযায়ী নিজের dashboard-এ যাবে।
    // কোনো পুরোনো/visitor URL যেন অন্য role-এর dashboard দেখাতে না পারে।
    const userId = data?.user?.id;
    let destination = ROUTES.PATIENT_DASHBOARD;

    if (userId) {
      const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", userId)
        .single();

      if (profileError) {
        setError("প্রোফাইল তথ্য লোড করা যায়নি। আবার চেষ্টা করুন।");
        return;
      }

      if (profile?.role === ROLES.DOCTOR || profile?.role === ROLES.HOSPITAL) {
        destination = ROUTES.DASHBOARD;
      } else if (profile?.role === ROLES.ADMIN || profile?.role === ROLES.SUPER_ADMIN) {
        destination = ROUTES.ADMIN;
      } else {
        destination = ROUTES.PATIENT_DASHBOARD;
      }
    }

    navigate(destination, { replace: true });
  };

  return (
    <div className="container flex min-h-[80vh] items-center justify-center py-12">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          <span className="mb-2 flex h-11 w-11 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <Stethoscope className="h-5 w-5" />
          </span>
          <CardTitle style={{ fontFamily: "'Tiro Bangla', serif" }}>লগইন করুন</CardTitle>
          <CardDescription>আপনার অ্যাকাউন্টে প্রবেশ করুন</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
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
              <div className="flex items-center justify-between">
                <Label htmlFor="password">পাসওয়ার্ড</Label>
                <Link to={ROUTES.FORGOT_PASSWORD} className="text-xs font-medium text-primary hover:underline">
                  পাসওয়ার্ড ভুলে গেছেন?
                </Link>
              </div>
              <Input
                id="password"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </div>
            {error && <p className="text-sm text-destructive">{error}</p>}
            <Button type="submit" className="w-full" disabled={submitting}>
              {submitting ? "লগইন হচ্ছে..." : "লগইন"}
            </Button>
          </form>
          <p className="mt-5 text-center text-sm text-muted-foreground">
            অ্যাকাউন্ট নেই?{" "}
            <Link to={ROUTES.REGISTER} className="font-medium text-primary hover:underline">
              রেজিস্টার করুন
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
