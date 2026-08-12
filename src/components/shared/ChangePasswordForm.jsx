import { useState } from "react";
import { KeyRound, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuth } from "@/hooks/useAuth";

/**
 * সবার জন্য (রোগী/ডাক্তার/অ্যাডমিন — যার যার permission অনুযায়ী) নিজের
 * লগইন পাসওয়ার্ড পরিবর্তনের ফর্ম। এটি একই বিদ্যমান নিরাপদ auth flow ব্যবহার
 * করে যা ResetPasswordPage-এ ব্যবহৃত হয় (supabase.auth.updateUser — শুধু
 * সচল সেশনের জন্যই কাজ করে, তাই এই ইউজারের নিজের পাসওয়ার্ড ছাড়া অন্য কারো
 * পাসওয়ার্ড এর মাধ্যমে বদলানো সম্ভব না)। কোনো পাসওয়ার্ড কোথাও প্রদর্শন বা
 * সংরক্ষণ করা হয় না।
 */
export default function ChangePasswordForm() {
  const { updatePassword } = useAuth();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setDone(false);

    if (password.length < 6) {
      setError("পাসওয়ার্ড কমপক্ষে ৬ ডিজিটের হতে হবে।");
      return;
    }
    if (password !== confirm) {
      setError("দুটো পাসওয়ার্ড মিলছে না।");
      return;
    }

    setSubmitting(true);
    const { error: updateError } = await updatePassword(password);
    setSubmitting(false);

    if (updateError) {
      setError("পাসওয়ার্ড আপডেট ব্যর্থ হয়েছে: " + updateError.message);
      return;
    }

    setPassword("");
    setConfirm("");
    setDone(true);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="space-y-1.5">
        <Label htmlFor="new-password">নতুন পাসওয়ার্ড</Label>
        <Input
          id="new-password"
          type="password"
          required
          minLength={6}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="new-password"
        />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="confirm-password">পাসওয়ার্ড আবার লিখুন</Label>
        <Input
          id="confirm-password"
          type="password"
          required
          minLength={6}
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          autoComplete="new-password"
        />
      </div>

      {error && <p className="text-sm text-destructive">{error}</p>}
      {done && (
        <p className="flex items-center gap-1.5 text-sm text-primary">
          <CheckCircle2 className="h-4 w-4" /> পাসওয়ার্ড সফলভাবে পরিবর্তন হয়েছে।
        </p>
      )}

      <Button type="submit" disabled={submitting}>
        <KeyRound className="h-4 w-4" />
        {submitting ? "সংরক্ষণ হচ্ছে..." : "পাসওয়ার্ড পরিবর্তন করুন"}
      </Button>
    </form>
  );
}
