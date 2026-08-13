import { useState } from "react";
import { Link } from "react-router-dom";
import { User, Phone, Heart, KeyRound, CheckCircle2, ChevronLeft, MapPin } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import ImageUploader from "@/components/shared/ImageUploader.jsx";
import ChangePasswordForm from "@/components/shared/ChangePasswordForm.jsx";
import { useAuth } from "@/hooks/useAuth";
import { ROUTES } from "@/constants/routes";
import { ROLE_LABEL_BN } from "@/constants/roles";
import { cn } from "@/lib/utils";

const GENDER_OPTIONS = [
  { value: "male", label: "পুরুষ" },
  { value: "female", label: "নারী" },
  { value: "other", label: "অন্যান্য" },
];

// Bottom Navigation-এর "প্রোফাইল" ট্যাব এখানে নিয়ে আসে। বিদ্যমান
// /account রুট ও ProtectedRoute-ই reuse করা হয়েছে (লগইন না থাকলে
// স্বয়ংক্রিয়ভাবে লগইন পেজে পাঠিয়ে দেয়) — কোনো নতুন রুট/গার্ড লজিক
// তৈরি করা হয়নি। প্রোফাইল ছবি আপলোডে বিদ্যমান ImageUploader-এর
// autoCompress নিয়মই (compressImageToRange) ব্যবহৃত হয়েছে।
export default function AccountPage() {
  const { profile, role, updateProfile } = useAuth();

  const [fullName, setFullName] = useState(profile?.full_name || "");
  const [phone, setPhone] = useState(profile?.phone || "");
  const [gender, setGender] = useState(profile?.gender || "");
  const [address, setAddress] = useState(profile?.address || "");
  const [avatarUrl, setAvatarUrl] = useState(profile?.avatar_url || "");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");

  const avatarInitial = (fullName?.trim()?.charAt(0) || "ব").toUpperCase();

  const handleAvatarUploaded = async (url) => {
    setAvatarUrl(url);
    // ছবি আপলোড হওয়ার সাথে সাথেই সংরক্ষণ করা হয় — বাকি ফিল্ডের জন্য
    // আলাদা "সংরক্ষণ করুন" বাটন চাপার আগেই অ্যাভাটার আপডেট দেখা যাবে
    await updateProfile({ avatar_url: url });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setSaved(false);
    setSaving(true);
    const { error: updateError } = await updateProfile({
      full_name: fullName.trim(),
      phone: phone.trim(),
      gender: gender || null,
      address: address.trim() || null,
      avatar_url: avatarUrl,
    });
    setSaving(false);
    if (updateError) {
      setError("প্রোফাইল সংরক্ষণ ব্যর্থ হয়েছে: " + updateError.message);
      return;
    }
    setSaved(true);
  };

  return (
    <div className="container max-w-lg py-6 md:py-10">
      <div className="mb-6 flex items-center gap-2">
        <Link
          to={ROUTES.HOME}
          className="flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-secondary md:hidden"
          aria-label="ফিরে যান"
        >
          <ChevronLeft className="h-5 w-5" />
        </Link>
        <div>
          <h1 className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
            আমার প্রোফাইল
          </h1>
          <p className="text-sm text-muted-foreground">{ROLE_LABEL_BN[role]}</p>
        </div>
      </div>

      {/* অ্যাভাটার + মৌলিক তথ্য */}
      <Card className="mb-4">
        <CardContent className="pt-6">
          <div className="mb-5 flex flex-col items-center gap-3">
            <div className="flex h-24 w-24 items-center justify-center overflow-hidden rounded-full border-4 border-card bg-primary text-2xl font-bold text-primary-foreground shadow-md ring-1 ring-border">
              {avatarUrl ? (
                <img src={avatarUrl} alt="প্রোফাইল ছবি" className="h-full w-full object-cover" />
              ) : (
                avatarInitial
              )}
            </div>
            <ImageUploader
              bucket="user-avatars"
              folder={profile?.id}
              value=""
              onUploaded={handleAvatarUploaded}
              aspect="square"
              maxSizeKB={1024}
              autoCompress
              compressTargetMinKB={80}
              compressTargetMaxKB={150}
            />
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="full-name">পুরো নাম</Label>
              <div className="relative">
                <User className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  id="full-name"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="আপনার নাম লিখুন"
                  className="pl-9"
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="phone">ফোন নম্বর</Label>
              <div className="relative">
                <Phone className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  id="phone"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="০১XXXXXXXXX"
                  className="pl-9"
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <Label>লিঙ্গ</Label>
              <div className="grid grid-cols-3 gap-2">
                {GENDER_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => setGender(gender === opt.value ? "" : opt.value)}
                    className={cn(
                      "rounded-lg border px-3 py-2 text-sm font-medium transition-colors",
                      gender === opt.value
                        ? "border-primary bg-primary/10 text-primary"
                        : "border-border text-muted-foreground hover:bg-secondary"
                    )}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="address">ঠিকানা</Label>
              <div className="relative">
                <MapPin className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Textarea
                  id="address"
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  placeholder="আপনার বাসা/এলাকার ঠিকানা লিখুন"
                  rows={2}
                  className="pl-9"
                />
              </div>
            </div>

            {error && <p className="text-sm text-destructive">{error}</p>}
            {saved && (
              <p className="flex items-center gap-1.5 text-sm text-primary">
                <CheckCircle2 className="h-4 w-4" /> প্রোফাইল সফলভাবে সংরক্ষিত হয়েছে।
              </p>
            )}

            <Button type="submit" disabled={saving} className="w-full sm:w-auto">
              {saving ? "সংরক্ষণ হচ্ছে..." : "প্রোফাইল সংরক্ষণ করুন"}
            </Button>
          </form>
        </CardContent>
      </Card>

      {/* সংরক্ষিত ডাক্তার প্রোফাইলের শর্টকাট */}
      <Link
        to={ROUTES.SAVED}
        className="mb-4 flex items-center justify-between rounded-xl border border-border bg-card p-4 transition-colors hover:bg-secondary/50"
      >
        <span className="flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-destructive/10 text-destructive">
            <Heart className="h-5 w-5" />
          </span>
          <span>
            <span className="block text-sm font-semibold text-foreground">সংরক্ষিত ডাক্তার প্রোফাইল</span>
            <span className="block text-xs text-muted-foreground">আপনার পছন্দের তালিকা দেখুন</span>
          </span>
        </span>
        <ChevronLeft className="h-4 w-4 rotate-180 text-muted-foreground" />
      </Link>

      {/* পাসওয়ার্ড পরিবর্তন */}
      <Card>
        <CardHeader>
          <span className="mb-1 flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <KeyRound className="h-5 w-5" />
          </span>
          <CardTitle>পাসওয়ার্ড পরিবর্তন করুন</CardTitle>
          <CardDescription>
            আপনার নিজের অ্যাকাউন্টের লগইন পাসওয়ার্ড এখান থেকে নিরাপদে পরিবর্তন করতে পারবেন।
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ChangePasswordForm />
        </CardContent>
      </Card>
    </div>
  );
}
