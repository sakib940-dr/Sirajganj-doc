// supabase/functions/admin-manage-user/index.ts
//
// এই Edge Function ইউজার ban / unban / delete করার অনুমতি দেয়:
//   - Super Admin: যেকোনো ইউজারের উপর ban/unban/delete করতে পারবেন (শেষ
//     Super Admin বাদে)।
//   - Admin: শুধুমাত্র "seller" রোলের অ্যাকাউন্ট ban/unban (active/deactivate)
//     করতে পারবেন — delete করতে পারবেন না, অন্য কোনো role-এর অ্যাকাউন্টেও
//     হাত দিতে পারবেন না।
// service_role key কখনো browser-এ পাঠানো হয় না — এটা শুধু এই সার্ভার-সাইড
// ফাংশনের ভেতরেই ব্যবহৃত হয়।
// (এটি admin-reset-password ফাংশনের মতোই একই security প্যাটার্ন অনুসরণ করে।)
//
// action: "ban" | "unban" | "delete"
//
// Deploy: supabase functions deploy admin-manage-user

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const BAN_DURATION = "876000h"; // ~100 বছর, কার্যত স্থায়ী ব্যান

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { userId, action } = await req.json();

    if (!userId || !["ban", "unban", "delete"].includes(action)) {
      return new Response(
        JSON.stringify({ error: "userId এবং সঠিক action (ban/unban/delete) প্রয়োজন।" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ১. caller-এর JWT দিয়ে ক্লায়েন্ট বানানো — identity যাচাইয়ের জন্য
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

    // ২. caller সত্যিই super_admin অথবা admin কিনা যাচাই
    const { data: callerProfile } = await callerClient
      .from("profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    const isSuperAdminCaller = callerProfile?.role === "super_admin";
    const isAdminCaller = callerProfile?.role === "admin";

    if (!isSuperAdminCaller && !isAdminCaller) {
      return new Response(JSON.stringify({ error: "শুধুমাত্র Admin Panel-এর অনুমোদিত ব্যবহারকারী এই কাজ করতে পারবেন।" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (userId === caller.id) {
      return new Response(JSON.stringify({ error: "নিজের অ্যাকাউন্টে এই অ্যাকশন প্রয়োগ করা যাবে না।" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ৩. service_role client দিয়ে আসল কাজ
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Normal Admin (super_admin নন) শুধুমাত্র "seller" রোলের অ্যাকাউন্ট
    // active/deactivate (ban/unban) করতে পারবেন — delete করতে পারবেন না,
    // অন্য কোনো role-এর (visitor/admin/super_admin) অ্যাকাউন্টেও হাত দিতে
    // পারবেন না। এই স্কোপ-চেকটা Super Admin-এর জন্য প্রযোজ্য নয়।
    if (isAdminCaller) {
      if (action === "delete") {
        return new Response(
          JSON.stringify({ error: "এই Admin অ্যাকাউন্ট দিয়ে ইউজার ডিলিট করা যাবে না — শুধুমাত্র নির্দিষ্ট Admin পারবেন।" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: targetProfileForScope } = await adminClient
        .from("profiles")
        .select("role")
        .eq("id", userId)
        .single();

      if (targetProfileForScope?.role !== "seller") {
        return new Response(
          JSON.stringify({ error: "Admin শুধুমাত্র সেলার অ্যাকাউন্ট active/deactivate করতে পারবেন।" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // সিস্টেমে অন্তত ১ জন Super Admin সবসময় থাকতেই হবে — "delete" একটি
    // auth.users cascade delete, যা profiles টেবিলের UPDATE trigger দিয়ে
    // ধরা পড়ে না, তাই এখানেই সরাসরি চেক করা হচ্ছে (ban-এর জন্য এই একই
    // ইনভ্যারিয়েন্ট DB trigger দিয়েও সুরক্ষিত, কিন্তু এখানে আগেভাগে চেক
    // করলে caller একটা পরিষ্কার বার্তা পান, raw SQL error না)।
    if (action === "ban" || action === "delete") {
      const { data: targetProfile } = await adminClient
        .from("profiles")
        .select("role")
        .eq("id", userId)
        .single();

      if (targetProfile?.role === "super_admin") {
        const { count } = await adminClient
          .from("profiles")
          .select("id", { count: "exact", head: true })
          .eq("role", "super_admin");

        if ((count ?? 0) <= 1) {
          return new Response(
            JSON.stringify({
              error:
                "সিস্টেমে অন্তত একজন সর্বোচ্চ-পর্যায়ের Admin থাকতেই হবে — শেষজনকে " +
                (action === "ban" ? "ব্যান" : "ডিলিট") +
                " করা যাবে না।",
            }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }
    }

    if (action === "delete") {
      const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
      if (deleteError) {
        return new Response(JSON.stringify({ error: deleteError.message }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      // profiles row auth.users FK-তে on delete cascade থাকায় স্বয়ংক্রিয়ভাবে মুছে যায়
    } else {
      // ban / unban — Supabase Auth লেভেলে লগইন বন্ধ/চালু করা হচ্ছে
      const { error: authError } = await adminClient.auth.admin.updateUserById(userId, {
        ban_duration: action === "ban" ? BAN_DURATION : "none",
      });
      if (authError) {
        return new Response(JSON.stringify({ error: authError.message }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // profiles.account_status ও আপডেট — এটি অ্যাপের ভেতরের UI/route গার্ডের জন্য ব্যবহৃত হয়
      const { error: profileError } = await adminClient
        .from("profiles")
        .update({ account_status: action === "ban" ? "banned" : "active" })
        .eq("id", userId);
      if (profileError) {
        return new Response(JSON.stringify({ error: profileError.message }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
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
