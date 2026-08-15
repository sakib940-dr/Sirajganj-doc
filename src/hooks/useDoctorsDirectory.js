import { useEffect, useState } from "react";
import { searchDoctorCatalog } from "@/services/discoveryService";
import { getSearchSynonyms, expandSearchTerms } from "@/lib/searchSynonyms";

function cleanTerm(term) { return term.replace(/[,()%*]/g, "").trim(); }

export function useDoctorsDirectory({ district = "", upazila = "", section = "popular", query = "", page = 1, pageSize = 20 }) {
  const [products, setProducts] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true); setError(null);
      let terms = [];
      if (query.trim()) {
        const synonyms = await getSearchSynonyms();
        terms = expandSearchTerms(query, synonyms).map(cleanTerm).filter(Boolean).slice(0, 12);
      }
      const { data, error: rpcError } = await searchDoctorCatalog({
        p_terms: terms.length ? terms : null,
        p_district: district || null,
        p_upazila: upazila || null,
        p_section: section === "latest" ? "latest" : "popular",
        p_limit: pageSize,
        p_offset: Math.max(0, (page - 1) * pageSize),
      });
      if (!active) return;
      if (rpcError) { setProducts([]); setTotal(0); setError(rpcError.message); }
      else { setProducts(data?.items || []); setTotal(Number(data?.total || 0)); }
      setLoading(false);
    }
    load();
    return () => { active = false; };
  }, [district, upazila, section, query, page, pageSize]);

  return { products, total, loading, error };
}
