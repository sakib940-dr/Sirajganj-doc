import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

const UPZILAS = ["সিরাজগঞ্জ সদর","বেলকুচি","চৌহালী","কামারখন্দ","কাজীপুর","রায়গঞ্জ","শাহজাদপুর","তাড়াশ","উল্লাপাড়া"];
const DISTRICT_ALIASES = { "সিরাজগঞ্জ": "সিরাজগঞ্জ", "sirajganj": "সিরাজগঞ্জ" };

function findBanglaUpazila(addressText = "") {
  const normalized = addressText.toLowerCase();
  const aliases = {
    "সিরাজগঞ্জ সদর": ["সিরাজগঞ্জ সদর", "sirajganj sadar", "sirajganj"], "বেলকুচি": ["বেলকুচি", "belkuchi"],
    "চৌহালী": ["চৌহালী", "chauhali"], "কামারখন্দ": ["কামারখন্দ", "kamarkhanda"], "কাজীপুর": ["কাজীপুর", "kazipur"],
    "রায়গঞ্জ": ["রায়গঞ্জ", "raiganj"], "শাহজাদপুর": ["শাহজাদপুর", "shahjadpur"], "তাড়াশ": ["তাড়াশ", "tarash"], "উল্লাপাড়া": ["উল্লাপাড়া", "ullapara"],
  };
  for (const upazila of UPZILAS) if (aliases[upazila].some((name) => normalized.includes(name.toLowerCase()))) return upazila;
  return "";
}
function findDistrict(address = {}) {
  const raw = [address.state_district,address.district,address.county,address.state,address.city_district].filter(Boolean).join(" ");
  if (raw.toLowerCase().includes("sirajganj") || raw.includes("সিরাজগঞ্জ")) return "সিরাজগঞ্জ";
  return address.state_district || address.district || "";
}
async function persistSignedInLocation({ latitude=null, longitude=null, district="", upazila="", source="gps", accuracy=null }) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    await supabase.rpc("save_my_last_location", {
      p_latitude: latitude, p_longitude: longitude, p_district: district || null, p_upazila: upazila || null,
      p_source: source, p_accuracy_m: accuracy,
    });
  } catch { /* local visitor location remains usable */ }
}

export function useVisitorLocation() {
  const [location, setLocation] = useState({ district:"",upazila:"",latitude:null,longitude:null,source:"",accuracy:null,status:"idle",message:"" });

  useEffect(() => {
    let active = true;
    try {
      const raw = window.localStorage.getItem("doctor_v1_last_location");
      if (raw) {
        const saved = JSON.parse(raw);
        if (saved && (saved.district || (Number.isFinite(Number(saved.latitude)) && Number.isFinite(Number(saved.longitude))))) {
          setLocation((prev)=>({...prev,...saved,source:saved.source||"saved",status:"success"}));
        }
      }
    } catch {}
    (async()=>{
      try {
        const { data:{ user } } = await supabase.auth.getUser();
        if (!user || !active) return;
        const { data, error } = await supabase.rpc("get_my_last_location");
        if (error || !active) return;
        const row = Array.isArray(data) ? data[0] : data;
        if (!row || (!row.district && row.latitude == null)) return;
        const next = {
          latitude:row.latitude==null?null:Number(row.latitude), longitude:row.longitude==null?null:Number(row.longitude),
          district:row.district||"", upazila:row.upazila||"", source:row.source||"saved", accuracy:row.accuracy_m??null, status:"success",
          message:row.upazila?`${row.upazila}, ${row.district||"সিরাজগঞ্জ"} অনুযায়ী স্বাস্থ্যসেবা দেখানো হচ্ছে।`:`${row.district||"সিরাজগঞ্জ"} এলাকার কাছের স্বাস্থ্যসেবা দেখানো হচ্ছে।`,
        };
        setLocation((prev)=>({...prev,...next}));
        window.localStorage.setItem("doctor_v1_last_location",JSON.stringify(next));
      } catch {}
    })();
    return()=>{active=false;};
  },[]);

  const requestLocation = useCallback(()=>{
    if (!navigator.geolocation) { setLocation((p)=>({...p,status:"error",message:"এই ডিভাইসে অবস্থান সুবিধা পাওয়া যাচ্ছে না। নিচ থেকে এলাকা বেছে নিন।"})); return; }
    setLocation((p)=>({...p,status:"loading",message:"আপনার অবস্থান নির্ধারণ করা হচ্ছে..."}));
    navigator.geolocation.getCurrentPosition(async({coords})=>{
      const immediate={district:"",upazila:"",latitude:coords.latitude,longitude:coords.longitude,source:"gps",accuracy:coords.accuracy??null,status:"success",message:"আপনার GPS অবস্থান অনুযায়ী কাছের স্বাস্থ্যসেবা দেখানো হচ্ছে।"};
      setLocation(immediate); window.localStorage.setItem("doctor_v1_last_location",JSON.stringify(immediate));
      await persistSignedInLocation(immediate);
      try {
        const response=await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${coords.latitude}&lon=${coords.longitude}&accept-language=bn&zoom=12`,{headers:{Accept:"application/json"}});
        if(!response.ok) throw new Error("reverse geocoding failed");
        const data=await response.json();
        const district=findDistrict(data.address); const upazila=findBanglaUpazila([data.display_name,data.address?.municipality,data.address?.town,data.address?.county,data.address?.city_district].filter(Boolean).join(" "));
        const next={...immediate,district,upazila,message:upazila?`${upazila}, ${district||"সিরাজগঞ্জ"} অনুযায়ী স্বাস্থ্যসেবা দেখানো হচ্ছে।`:district?`${district} জেলার কাছের স্বাস্থ্যসেবা দেখানো হচ্ছে।`:"GPS অনুযায়ী কাছের স্বাস্থ্যসেবা দেখানো হচ্ছে।"};
        setLocation(next); window.localStorage.setItem("doctor_v1_last_location",JSON.stringify(next)); await persistSignedInLocation(next);
      } catch { /* GPS result remains active even if reverse geocoder fails */ }
    },(error)=>{let message="অবস্থান অনুমতি দেওয়া হয়নি। নিচ থেকে এলাকা বেছে নিন।";if(error.code===2)message="অবস্থান পাওয়া যায়নি। নিচ থেকে এলাকা বেছে নিন।";setLocation((p)=>({...p,status:"denied",message}));},{enableHighAccuracy:true,timeout:12000,maximumAge:10*60*1000});
  },[]);

  const selectArea=useCallback(async(district,upazila="")=>{
    const base={district,upazila,latitude:null,longitude:null,source:"manual",accuracy:null,status:"loading",message:upazila?`${upazila}, ${district} অনুযায়ী এলাকা নির্ধারণ করা হচ্ছে...`:`${district} জেলার স্বাস্থ্যসেবা দেখানো হচ্ছে...`};
    setLocation(base);
    try {
      const query=encodeURIComponent(`${upazila?upazila+", ":""}${district}, Bangladesh`);
      const response=await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&accept-language=bn&q=${query}`,{headers:{Accept:"application/json"}});
      if(!response.ok)throw new Error("geocode failed"); const rows=await response.json(); const row=rows?.[0];
      const lat=row?Number(row.lat):null, lon=row?Number(row.lon):null;
      const next={...base,latitude:Number.isFinite(lat)?lat:null,longitude:Number.isFinite(lon)?lon:null,status:"success",message:upazila?`${upazila}, ${district} অনুযায়ী স্বাস্থ্যসেবা দেখানো হচ্ছে। দূরত্ব নির্বাচিত এলাকার আনুমানিক কেন্দ্র থেকে হিসাব করা হবে।`:`${district} জেলার স্বাস্থ্যসেবা দেখানো হচ্ছে।`};
      setLocation(next); window.localStorage.setItem("doctor_v1_last_location",JSON.stringify(next)); await persistSignedInLocation(next);
    } catch {
      const next={...base,status:"success",message:upazila?`${upazila}, ${district} অনুযায়ী স্বাস্থ্যসেবা দেখানো হচ্ছে।`:`${district} জেলার স্বাস্থ্যসেবা দেখানো হচ্ছে।`};
      setLocation(next); window.localStorage.setItem("doctor_v1_last_location",JSON.stringify(next)); await persistSignedInLocation(next);
    }
  },[]);

  return { location,requestLocation,selectArea,upazilas:UPZILAS,districts:["সিরাজগঞ্জ"],districtAliases:DISTRICT_ALIASES };
}
