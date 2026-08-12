import { useState, useEffect } from "react";
import { useNavigate, Link } from "react-router-dom";
import { KeyRound, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { useAuth } from "@/hooks/useAuth";
import { supabase } from "@/lib/supabaseClient";
import { ROUTES } from "@/constants/routes";

export default function ResetPasswordPage() {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [ready, setReady] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState("");
  const { updatePassword } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    // ইমেইলের লিংক থেকে আসা recovery session সক্রিয় হওয়ার জন্য এই ইভেন্টটার অপেক্ষা করা হয়
    const { data: listener } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") setReady(true);
    });
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) setReady(true);
    });
    return () => listener.subscription.unsubscribe();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (password.length < 6) {
      setError("পাসওয়ার্ড কমপক্ষে ৬ ডিজিটের হতে হবে।");
      return;
    }
    if (password !== confirm) {
      setError("দুটো পাসওয়ার্ড মিলছে না।");
      return;
    }
    setSubmitting(true);
    const { error } = await updatePassword(password);
    setSubmitting(false);
    if (error) {
      setError("পাসওয়ার্ড আপডেট ব্যর্থ হয়েছে: " + error.message);
      return;
    }
    setDone(true);
    setTimeout(() => navigate(ROUTES.HOME), 2000);
  };

  return (
    <div className="container flex min-h-[80vh] items-center justify-center py-12">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          <span className="mb-2 flex h-11 w-11 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <KeyRound className="h-5 w-5" />
          </span>
          <CardTitle style={{ fontFamily: "'Tiro Bangla', serif" }}>নতুন পাসওয়ার্ড সেট করুন</CardTitle>
          <CardDescription>নিরাপদ একটি নতুন পাসওয়ার্ড দিন</CardDescription>
        </CardHeader>
        <CardContent>
          {done ? (
            <div className="flex flex-col items-center gap-3 py-4 text-center">
              <CheckCircle2 className="h-10 w-10 text-primary" />
              <p className="text-sm text-foreground">পাসওয়ার্ড সফলভাবে পরিবর্তন হয়েছে। হোমপেজে নিয়ে যাওয়া হচ্ছে...</p>
            </div>
          ) : !ready ? (
            <p className="py-6 text-center text-sm text-muted-foreground">
              লিংকটি যাচাই করা হচ্ছে... এটি সরাসরি না খুলে ইমেইলের লিংক থেকে আসুন।
            </p>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="password">নতুন পাসওয়ার্ড</Label>
                <Input id="password" type="password" required minLength={6} value={password} onChange={(e) => setPassword(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="confirm">পাসওয়ার্ড আবার লিখুন</Label>
                <Input id="confirm" type="password" required minLength={6} value={confirm} onChange={(e) => setConfirm(e.target.value)} />
              </div>
              {error && <p className="text-sm text-destructive">{error}</p>}
              <Button type="submit" className="w-full" disabled={submitting}>
                {submitting ? "সংরক্ষণ হচ্ছে..." : "পাসওয়ার্ড পরিবর্তন করুন"}
              </Button>
            </form>
          )}
          <p className="mt-4 text-center text-sm text-muted-foreground">
            <Link to={ROUTES.LOGIN} className="font-medium text-primary hover:underline">
              লগইন পেজে ফিরে যান
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
