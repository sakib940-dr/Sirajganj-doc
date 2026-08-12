// supabase/functions/admin-reset-password/index.ts
//
// এই Edge Function শুধুমাত্র verified Super Admin-কে অন্য যেকোনো ইউজারের
// পাসওয়ার্ড রিসেট করার অনুমতি দেয়। service_role key কখনো browser-এ
// পাঠানো হয় না — এটা শুধু এই সার্ভার-সাইড ফাংশনের ভেতরেই ব্যবহৃত হয়।
//
// Deploy: supabase functions deploy admin-reset-password
// (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY —
//  এই তিনটি secret Supabase Edge Function-এ অটোমেটিক্যালি available থাকে)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { userId, newPassword } = await req.json();

    if (!userId || !newPassword || newPassword.length < 6) {
      return new Response(
        JSON.stringify({ error: "userId ও কমপক্ষে ৬ ডিজিটের newPassword প্রয়োজন।" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ১. যে ইউজার রিকোয়েস্ট পাঠিয়েছে তার JWT দিয়ে ক্লায়েন্ট বানানো — নিজের identity যাচাইয়ের জন্য
    const authHeader = req.headers.get("Authorization");
    const callerClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader ?? "" } } }
    );

    const {
      data: { user: caller },
    } = await callerClient.auth.getUser();

    if (!caller) {
      return new Response(JSON.stringify({ error: "লগইন প্রয়োজন।" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ২. caller সত্যিই super_admin কিনা যাচাই (নিজের profile সে নিজেই RLS দিয়ে পড়তে পারবে)
    const { data: callerProfile } = await callerClient
      .from("profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    if (callerProfile?.role !== "super_admin") {
      return new Response(JSON.stringify({ error: "শুধুমাত্র নির্দিষ্ট Admin এই কাজ করতে পারবেন।" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ৩. এখন service_role client দিয়ে আসল পাসওয়ার্ড রিসেট করা হচ্ছে
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { error: resetError } = await adminClient.auth.admin.updateUserById(userId, {
      password: newPassword,
    });

    if (resetError) {
      return new Response(JSON.stringify({ error: resetError.message }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
