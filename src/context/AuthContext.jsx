import { createContext, useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabaseClient";

export const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchProfile = useCallback(async (userId, _retry = true) => {
    if (!userId) {
      setProfile(null);
      return;
    }
    // Prefer the own-profile RPC so login/bootstrap does not depend on a
    // drifting profiles SELECT policy. Keep direct-table fallback for the
    // short deploy window before the hotfix migration reaches Supabase.
    let data = null;
    let error = null;
    const rpcResult = await supabase.rpc("get_my_auth_profile");
    if (!rpcResult.error && rpcResult.data) {
      data = rpcResult.data;
    } else {
      const fallback = await supabase
        .from("profiles")
        .select("*")
        .eq("id", userId)
        .single();
      data = fallback.data;
      error = fallback.error;
    }

    if (error || !data) {
      // Signup-এর ঠিক পরপরই profile row তৈরির trigger সামান্য দেরি করলে
      // (network/replication lag) একবার আবার চেষ্টা করা হয়, যাতে ভুলভাবে
      // "visitor" role ধরে fallback না হয়ে যায়।
      if (_retry) {
        await new Promise((res) => setTimeout(res, 700));
        await fetchProfile(userId, false);
        return;
      }
      // eslint-disable-next-line no-console
      console.error("প্রোফাইল লোড করা যায়নি:", error?.message || "profile not found");
      setProfile(null);
      return;
    }
    setProfile(data);
  }, []);

  useEffect(() => {
    let isMounted = true;

    supabase.auth.getSession().then(async ({ data: { session } }) => {
      if (!isMounted) return;
      setSession(session);
      if (session?.user) {
        await fetchProfile(session.user.id);
      }
      setLoading(false);
    });

    const { data: listener } = supabase.auth.onAuthStateChange(
      async (_event, newSession) => {
        // CRITICAL FIX: এখানে loading=true সেট না করলে, register/login এর ঠিক
        // পরেই কোনো Protected route রেন্ডার হয়ে গেলে, profile fetch শেষ হওয়ার
        // আগেই পুরনো/খালি role ("visitor") ধরে ভুল জায়গায় redirect করে দিতে
        // পারে — যার ফলে ডাক্তার login করেও normal visitor এর মতো panel দেখে।
        setLoading(true);
        setSession(newSession);
        if (newSession?.user) {
          await fetchProfile(newSession.user.id);
        } else {
          setProfile(null);
        }
        setLoading(false);
      }
    );

    return () => {
      isMounted = false;
      listener.subscription.unsubscribe();
    };
  }, [fetchProfile]);

  const signIn = async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    return { data, error };
  };

  const signUp = async (email, password, fullName, phone) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { full_name: fullName, phone } },
    });
    return { data, error };
  };

  const signOut = async () => {
    const { error } = await supabase.auth.signOut();
    // লগআউটের পর সব role-কে visitor homepage-এ ফেরত পাঠানো হবে।
    if (!error && typeof window !== "undefined") {
      window.location.assign("/");
    }
    return { error };
  };

  const sendPasswordResetEmail = async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    return { error };
  };

  const updatePassword = async (newPassword) => {
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    return { error };
  };

  // userId ঐচ্ছিকভাবে সরাসরি দেওয়া যায় — এটা দরকার হয় যখন signUp/signIn এর
  // ঠিক পরপরই profile refresh করতে হয়, কারণ তখন context-এর `session` state
  // এখনো stale/পুরনো থাকতে পারে (onAuthStateChange listener async ভাবে চলে)।
  const refreshProfile = async (userId) => {
    const uid = userId ?? session?.user?.id;
    if (uid) await fetchProfile(uid);
  };

  // রোগী নিজের প্রোফাইল তথ্য (নাম, ফোন, জেন্ডার, অ্যাভাটার) আপডেট করে —
  // role/seller_status এখানে ছোঁয়া হয় না (সেটা trigger দিয়ে already সুরক্ষিত)।
  // বিদ্যমান "profiles_update_own" RLS পলিসি (auth.uid() = id) ব্যবহার করেই
  // এটি কাজ করে, তাই কোনো নতুন পলিসি লাগেনি।
  const updateProfile = async (fields) => {
    const uid = session?.user?.id;
    if (!uid) return { error: new Error("লগইন করা নেই") };
    const { error } = await supabase.from("profiles").update(fields).eq("id", uid);
    if (!error) await fetchProfile(uid);
    return { error };
  };

  const value = {
    session,
    user: session?.user ?? null,
    profile,
    role: profile?.role ?? "patient",
    doctorStatus: profile?.seller_status ?? "none",
    sellerStatus: profile?.seller_status ?? "none", // backward-compatible internal alias
    accountStatus: profile?.account_status ?? "active",
    isLoggedIn: !!session?.user,
    loading,
    signIn,
    signUp,
    signOut,
    refreshProfile,
    updateProfile,
    sendPasswordResetEmail,
    updatePassword,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
