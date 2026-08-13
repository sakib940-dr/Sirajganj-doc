import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

const UPZILAS = [
  "সিরাজগঞ্জ সদর",
  "বেলকুচি",
  "চৌহালী",
  "কামারখন্দ",
  "কাজীপুর",
  "রায়গঞ্জ",
  "শাহজাদপুর",
  "তাড়াশ",
  "উল্লাপাড়া",
];

const DISTRICT_ALIASES = {
  "সিরাজগঞ্জ": "সিরাজগঞ্জ",
  "sirajganj": "সিরাজগঞ্জ",
};

function findBanglaUpazila(addressText = "") {
  const normalized = addressText.toLowerCase();
  const aliases = {
    "সিরাজগঞ্জ সদর": ["সিরাজগঞ্জ সদর", "sirajganj sadar", "sirajganj"],
    "বেলকুচি": ["বেলকুচি", "belkuchi"],
    "চৌহালী": ["চৌহালী", "chauhali"],
    "কামারখন্দ": ["কামারখন্দ", "kamarkhanda"],
    "কাজীপুর": ["কাজীপুর", "kazipur"],
    "রায়গঞ্জ": ["রায়গঞ্জ", "raiganj"],
    "শাহজাদপুর": ["শাহজাদপুর", "shahjadpur"],
    "তাড়াশ": ["তাড়াশ", "tarash"],
    "উল্লাপাড়া": ["উল্লাপাড়া", "ullapara"],
  };

  for (const upazila of UPZILAS) {
    if (aliases[upazila].some((name) => normalized.includes(name.toLowerCase()))) return upazila;
  }
  return "";
}

function findDistrict(address = {}) {
  const raw = [
    address.state_district, address.district, address.county,
    address.state, address.city_district,
  ].filter(Boolean).join(" ");
  const lower = raw.toLowerCase();
  if (lower.includes("sirajganj") || raw.includes("সিরাজগঞ্জ")) return "সিরাজগঞ্জ";
  return address.state_district || address.district || "";
}

async function saveUserLocation(latitude, longitude, district, upazila) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    await supabase.from("profiles").update({
      location_latitude: latitude,
      location_longitude: longitude,
      location_district: district || null,
      location_upazila: upazila || null,
      location_updated_at: new Date().toISOString(),
    }).eq("id", user.id);
  } catch {
    // Location still works locally even if profile persistence is unavailable.
  }
}

export function useVisitorLocation() {
  const [location, setLocation] = useState({
    district: "",
    upazila: "",
    latitude: null,
    longitude: null,
    source: "",
    status: "idle",
    message: "",
  });

  // Logged-in users can reuse their last saved location without asking again.
  useEffect(() => {
    let active = true;
    async function loadSavedLocation() {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user || !active) return;
        const { data } = await supabase
          .from("profiles")
          .select("location_latitude, location_longitude, location_district, location_upazila")
          .eq("id", user.id)
          .maybeSingle();
        if (!active || !data?.location_latitude || !data?.location_longitude) return;
        setLocation((prev) => ({
          ...prev,
          latitude: Number(data.location_latitude),
          longitude: Number(data.location_longitude),
          district: data.location_district || prev.district,
          upazila: data.location_upazila || prev.upazila,
          source: "saved",
          status: "success",
          message: data.location_upazila
            ? `${data.location_upazila}, ${data.location_district || "সিরাজগঞ্জ"} অনুযায়ী ডাক্তার দেখানো হচ্ছে।`
            : `${data.location_district || "সিরাজগঞ্জ"} জেলার ডাক্তার দেখানো হচ্ছে।`,
        }));
      } catch {}
    }
    loadSavedLocation();
    return () => { active = false; };
  }, []);

  const requestLocation = useCallback(() => {
    if (!navigator.geolocation) {
      setLocation((prev) => ({ ...prev, status: "error", message: "এই ডিভাইসে অবস্থান সুবিধা পাওয়া যাচ্ছে না। নিচ থেকে এলাকা বেছে নিন।" }));
      return;
    }

    setLocation((prev) => ({ ...prev, status: "loading", message: "আপনার অবস্থান নির্ধারণ করা হচ্ছে..." }));

    navigator.geolocation.getCurrentPosition(
      async ({ coords }) => {
        try {
          const url =
            `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${coords.latitude}` +
            `&lon=${coords.longitude}&accept-language=bn&zoom=12`;
          const response = await fetch(url, { headers: { Accept: "application/json" } });
          if (!response.ok) throw new Error("reverse geocoding failed");
          const data = await response.json();
          const district = findDistrict(data.address);
          const upazila = findBanglaUpazila([
            data.display_name, data.address?.municipality, data.address?.town,
            data.address?.county, data.address?.city_district,
          ].filter(Boolean).join(" "));

          if (!district) {
            setLocation((prev) => ({
              ...prev, latitude: coords.latitude, longitude: coords.longitude,
              source: "device", status: "manual",
              message: "আপনার জেলা শনাক্ত করা যায়নি। নিচ থেকে এলাকা বেছে নিন।",
            }));
            await saveUserLocation(coords.latitude, coords.longitude, "", "");
            return;
          }

          const next = {
            district, upazila,
            latitude: coords.latitude, longitude: coords.longitude,
            source: "device", status: "success",
            message: upazila
              ? `${upazila}, ${district} অনুযায়ী ডাক্তার দেখানো হচ্ছে।`
              : `${district} জেলার ডাক্তার দেখানো হচ্ছে।`,
          };
          setLocation(next);
          window.localStorage.setItem("doctor_v1_last_location", JSON.stringify(next));
          await saveUserLocation(coords.latitude, coords.longitude, district, upazila);
        } catch {
          setLocation((prev) => ({ ...prev, status: "manual", message: "অবস্থান থেকে এলাকা নির্ধারণ করা যায়নি। নিচ থেকে এলাকা বেছে নিন।" }));
        }
      },
      (error) => {
        let message = "অবস্থান অনুমতি দেওয়া হয়নি। নিচ থেকে এলাকা বেছে নিন।";
        if (error.code === 2) message = "অবস্থান পাওয়া যায়নি। নিচ থেকে এলাকা বেছে নিন।";
        setLocation((prev) => ({ ...prev, status: "denied", message }));
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 10 * 60 * 1000 }
    );
  }, []);

  const selectArea = useCallback(async (district, upazila = "") => {
    // Manual selection can use the selected area's geocoded center as an
    // approximate reference point. It is NOT the patient's exact GPS location.
    const base = {
      district, upazila,
      latitude: null, longitude: null,
      source: "manual", status: "loading",
      message: upazila
        ? `${upazila}, ${district} অনুযায়ী এলাকা নির্ধারণ করা হচ্ছে...`
        : `${district} জেলার ডাক্তার দেখানো হচ্ছে...`,
    };
    setLocation(base);
    try {
      const query = encodeURIComponent(`${upazila ? upazila + ", " : ""}${district}, Bangladesh`);
      const response = await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&accept-language=bn&q=${query}`, {
        headers: { Accept: "application/json" },
      });
      if (!response.ok) throw new Error("geocode failed");
      const rows = await response.json();
      const row = rows?.[0];
      const latitude = row ? Number(row.lat) : null;
      const longitude = row ? Number(row.lon) : null;
      const next = {
        ...base,
        latitude: Number.isFinite(latitude) ? latitude : null,
        longitude: Number.isFinite(longitude) ? longitude : null,
        status: "success",
        message: upazila
          ? `${upazila}, ${district} অনুযায়ী ডাক্তার দেখানো হচ্ছে। দূরত্বটি নির্বাচিত এলাকার আনুমানিক অবস্থান ধরে দেখানো হবে।`
          : `${district} জেলার ডাক্তার দেখানো হচ্ছে। দূরত্বটি জেলা-কেন্দ্রিক আনুমানিক অবস্থান ধরে দেখানো হবে।`,
      };
      setLocation(next);
      window.localStorage.setItem("doctor_v1_last_location", JSON.stringify(next));
    } catch {
      setLocation({
        ...base,
        status: "success",
        message: upazila
          ? `${upazila}, ${district} অনুযায়ী ডাক্তার দেখানো হচ্ছে।`
          : `${district} জেলার ডাক্তার দেখানো হচ্ছে।`,
      });
    }
  }, []);

  return {
    location,
    requestLocation,
    selectArea,
    upazilas: UPZILAS,
    districts: ["সিরাজগঞ্জ"],
    districtAliases: DISTRICT_ALIASES,
  };
}
