import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  // eslint-disable-next-line no-console
  console.error(
    "Supabase env variable পাওয়া যায়নি। .env ফাইলে VITE_SUPABASE_URL ও VITE_SUPABASE_ANON_KEY সেট করুন।"
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
