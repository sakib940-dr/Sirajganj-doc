import { supabase } from "@/lib/supabaseClient";

// search_synonyms টেবিল ছোট এবং প্রায় স্ট্যাটিক — একবার fetch করে module-level
// cache-এ রাখা হচ্ছে, যাতে প্রতিটা সার্চে বারবার নেটওয়ার্ক কল না লাগে।
let cachedSynonyms = null;
let inFlightFetch = null;

export async function getSearchSynonyms() {
  if (cachedSynonyms) return cachedSynonyms;
  if (inFlightFetch) return inFlightFetch;

  inFlightFetch = supabase
    .from("search_synonyms")
    .select("term_en, term_bn")
    .then(({ data, error }) => {
      cachedSynonyms = error ? [] : data ?? [];
      inFlightFetch = null;
      return cachedSynonyms;
    })
    .catch(() => {
      cachedSynonyms = [];
      inFlightFetch = null;
      return cachedSynonyms;
    });

  return inFlightFetch;
}

// PostgREST-এর .or() ফিল্টার স্ট্রিং-এ ব্যবহার করা যাবে না এমন ক্যারেক্টার সরানো হয়
// (ইউজারের কাঁচা ইনপুট সরাসরি filter string-এ বসানো হচ্ছে বলে এটা দরকার)
function sanitizeTerm(term) {
  return term.replace(/[,()%*]/g, "").trim();
}

/**
 * ইউজারের সার্চ কোয়েরি থেকে সমার্থক শব্দসহ (বাংলা ⇄ ইংরেজি) একগুচ্ছ সার্চ-টার্ম
 * তৈরি করে। উদাহরণ: "shirt" লিখলে ["shirt", "শার্ট"] রিটার্ন করবে, যাতে
 * ইংরেজি সার্চেও বাংলা নামের ডাক্তার প্রোফাইল পাওয়া যায় (এবং উল্টোটাও)।
 */
export function expandSearchTerms(rawQuery, synonyms) {
  const query = sanitizeTerm(rawQuery.toLowerCase());
  const terms = new Set();
  if (query) terms.add(query);

  // খুব ছোট কোয়েরি (১ অক্ষর) দিয়ে dictionary শব্দ ম্যাচ করানো হয় না, নাহলে
  // অনেক অপ্রাসঙ্গিক শব্দ মিলে গিয়ে ফলাফল নোংরা হয়ে যাবে
  if (query.length >= 2) {
    for (const { term_en, term_bn } of synonyms ?? []) {
      if (!term_en || !term_bn) continue;
      const en = term_en.toLowerCase().trim();
      const bn = term_bn.trim();

      // কোয়েরি একটা পরিচিত শব্দ ধারণ করে থাকলে, বা পরিচিত শব্দটাই কোয়েরিকে ধারণ করে থাকলে
      const matchesEn = en.includes(query) || query.includes(en);
      const matchesBn = bn.toLowerCase().includes(query) || query.includes(bn.toLowerCase());

      if (matchesEn || matchesBn) {
        terms.add(sanitizeTerm(en));
        terms.add(sanitizeTerm(bn));
      }
    }
  }

  return Array.from(terms).filter(Boolean);
}
