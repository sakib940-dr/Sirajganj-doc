import { Ambulance, MapPin, Phone, Navigation, ShieldCheck } from "lucide-react";
import { useVisitorLocation } from "@/hooks/useVisitorLocation";
import { useAmbulances } from "@/hooks/useAmbulances";
import { formatDistanceKm } from "@/lib/geo";
import { recordAmbulanceCallClick, recordAmbulanceDirectionClick } from "@/services/discoveryService";

export default function AmbulancePage() {
  const { location } = useVisitorLocation();
  const { ambulances, loading } = useAmbulances({ latitude: location.latitude, longitude: location.longitude });
  return <div className="container max-w-5xl py-6 md:py-10">
    <div className="rounded-2xl border bg-card p-5 shadow-sm"><div className="flex items-start gap-3"><span className="flex h-11 w-11 items-center justify-center rounded-full bg-primary/10 text-primary"><Ambulance /></span><div><h1 className="text-xl font-bold">অ্যাম্বুলেন্স ডিরেক্টরি</h1><p className="mt-1 text-sm text-muted-foreground">সিরাজগঞ্জের কাছাকাছি অ্যাম্বুলেন্স সার্ভিস খুঁজুন।</p></div></div></div>
    <div className="mt-5 space-y-3">
      {loading && <div className="rounded-xl border p-6 text-center text-sm text-muted-foreground">অ্যাম্বুলেন্স খোঁজা হচ্ছে...</div>}
      {!loading && !ambulances.length && <div className="rounded-xl border p-8 text-center text-sm text-muted-foreground">এখনো কোনো অ্যাম্বুলেন্স সার্ভিস যোগ করা হয়নি।</div>}
      {ambulances.map(a=><div key={a.id} className="rounded-2xl border bg-card p-4 shadow-sm">
        <div className="flex items-start gap-3"><span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary"><Ambulance /></span><div className="min-w-0 flex-1"><div className="flex flex-wrap items-center gap-2"><h2 className="font-semibold">{a.name}</h2>{a.is_verified&&<span className="inline-flex items-center gap-1 text-xs text-primary"><ShieldCheck className="h-3.5 w-3.5"/> যাচাই করা</span>}{a.is_available?<span className="rounded-full bg-emerald-50 px-2 py-0.5 text-xs text-emerald-700">সেবা চালু</span>:<span className="rounded-full bg-secondary px-2 py-0.5 text-xs">এই মুহূর্তে বন্ধ</span>}</div><p className="mt-1 text-sm text-muted-foreground">{a.ambulance_type || "অ্যাম্বুলেন্স"}{a.service_area?` • ${a.service_area}`:""}</p><div className="mt-2 flex flex-wrap gap-3 text-xs text-muted-foreground">{a.address&&<span className="flex items-center gap-1"><MapPin className="h-3.5 w-3.5"/>{a.address}</span>}{a.distance_km!=null&&<span>{formatDistanceKm(a.distance_km)}</span>}</div></div></div>
        <div className="mt-3 flex flex-wrap gap-2"><a href={`tel:${a.phone}`} onClick={()=>recordAmbulanceCallClick(a.id)} className="inline-flex h-9 items-center gap-1 rounded-lg bg-primary px-3 text-sm font-semibold text-primary-foreground"><Phone className="h-4 w-4"/> কল করুন</a>{a.latitude&&a.longitude&&<a target="_blank" rel="noreferrer" onClick={()=>recordAmbulanceDirectionClick(a.id)} href={`https://www.google.com/maps/dir/?api=1&destination=${a.latitude},${a.longitude}`} className="inline-flex h-9 items-center gap-1 rounded-lg border px-3 text-sm font-medium"><Navigation className="h-4 w-4"/> দিকনির্দেশনা</a>}</div>
      </div>)}
    </div>
  </div>;
}
