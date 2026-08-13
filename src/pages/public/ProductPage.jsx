import { useEffect, useRef, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { UserRound, Heart, ChevronLeft, ChevronRight, MapPin, Phone, MessageCircle, CalendarDays, Share2, Check, Navigation } from "lucide-react";
import { useProductBySlug, useRelatedProducts } from "@/hooks/useProducts";
import { formatPriceBn } from "@/lib/utils";
import { shopPath } from "@/constants/routes";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import ProductCard from "@/components/shared/ProductCard.jsx";
import CurrentViewersBadge from "@/components/shared/CurrentViewersBadge.jsx";
import AppointmentDialog from "@/components/public/AppointmentDialog.jsx";
import { trackProductView, useProductSave } from "@/hooks/useProductAnalytics";

export default function ProductPage() {
  const { productSlug } = useParams();
  const navigate = useNavigate();
  const { product, images, loading, error } = useProductBySlug(productSlug);
  const allImages = product ? [product.thumbnail_url, ...images.map(i=>i.image_url)].filter(Boolean) : [];
  const [activeImage,setActiveImage]=useState(0);
  const { isSaved,saving,toggleSave }=useProductSave(product?.id);
  const { products:relatedProducts }=useRelatedProducts(product?.category_id,product?.id);
  const viewed=useRef(new Set());
  const [appointmentOpen, setAppointmentOpen] = useState(false);
  const [shared, setShared] = useState(false);

  useEffect(()=>{ if(!product?.id||viewed.current.has(product.id))return; viewed.current.add(product.id); trackProductView(product.id); },[product?.id]);
  useEffect(()=>setActiveImage(0),[product?.id]);
  useEffect(()=>{ if(product?.name) document.title = `${product.name} — সিরাজগঞ্জ ডাক্তার`; },[product?.name]);

  if(loading)return <LoadingSpinner fullScreen label="ডাক্তারের প্রোফাইল লোড হচ্ছে..."/>;
  if(error||!product)return <div className="container py-16"><EmptyState icon={UserRound} title="ডাক্তারের প্রোফাইল পাওয়া যায়নি"/></div>;

  const chamber=product.shops;
  const phone=chamber?.phone_public !== false ? chamber?.phone : null;
  const whatsapp=chamber?.whatsapp_public !== false ? chamber?.whatsapp_number : null;
  const whatsappText=encodeURIComponent(`আমি Dr. ${product.name}-এর appointment/consultation সম্পর্কে জানতে চাই। ${window.location.href}`);

  return <div className="container py-8 md:py-10">
    <div className="grid gap-8 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
      <div>
        <div className="relative aspect-square overflow-hidden rounded-2xl border bg-secondary">
          {allImages.length?<img src={allImages[activeImage]} alt={product.name} className="h-full w-full object-cover"/>:<div className="flex h-full items-center justify-center"><UserRound className="h-16 w-16 text-muted-foreground"/></div>}
          {allImages.length>1&&<><button type="button" onClick={()=>setActiveImage(i=>(i-1+allImages.length)%allImages.length)} className="absolute left-2 top-1/2 rounded-full bg-background/80 p-2 shadow"><ChevronLeft className="h-5 w-5"/></button><button type="button" onClick={()=>setActiveImage(i=>(i+1)%allImages.length)} className="absolute right-2 top-1/2 rounded-full bg-background/80 p-2 shadow"><ChevronRight className="h-5 w-5"/></button></>}
        </div>
        {allImages.length>1&&<div className="mt-3 flex gap-2 overflow-x-auto">{allImages.map((img,i)=><button key={img+i} onClick={()=>setActiveImage(i)} className={`h-16 w-16 shrink-0 overflow-hidden rounded-lg border-2 ${i===activeImage?"border-primary":"border-transparent"}`}><img src={img} className="h-full w-full object-cover"/></button>)}</div>}
      </div>

      <div>
        {product.categories?.name&&<span className="inline-block rounded-full bg-secondary px-3 py-1 text-xs font-medium text-primary">{product.categories.name}</span>}
        <div className="mt-3 flex items-start justify-between gap-3">
          <div><h1 className="text-2xl font-bold md:text-3xl" style={{fontFamily:"'Tiro Bangla', serif"}}>{product.name}</h1>
            {product.designation&&<p className="mt-1 text-sm text-muted-foreground">{product.designation}</p>}
            {product.degree&&<p className="text-sm text-muted-foreground">{product.degree}</p>}
          </div>
          <button type="button" onClick={async()=>{const r=await toggleSave();if(r.requiresLogin)navigate("/login")}} disabled={saving} className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full border ${isSaved?"text-destructive":"text-muted-foreground"}`} aria-label="ডাক্তার সেভ করুন"><Heart className={`h-5 w-5 ${isSaved?"fill-current":""}`}/></button><button type="button" onClick={async()=>{const data={title:product.name,text:`${product.name} — সিরাজগঞ্জ ডাক্তার`,url:window.location.href};try{if(navigator.share) await navigator.share(data);else{await navigator.clipboard.writeText(window.location.href);setShared(true);setTimeout(()=>setShared(false),2200);}}catch{}}} className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border text-muted-foreground" aria-label="ডাক্তার প্রোফাইল শেয়ার করুন" title="শেয়ার করুন">{shared?<Check className="h-5 w-5 text-primary"/>:<Share2 className="h-5 w-5"/>}</button>
        </div>
        <div className="mt-3"><CurrentViewersBadge productId={product.id}/></div>
        <div className="mt-4 grid gap-2 rounded-2xl border bg-secondary/30 p-4 text-sm">
          {product.bmdc_registration_no && <p><span className="text-muted-foreground">বিএমডিসি রেজিস্ট্রেশন:</span> <strong>{product.bmdc_registration_no}</strong></p>}
          {product.categories?.name && <p><span className="text-muted-foreground">বিশেষত্ব:</span> <strong>{product.categories.name}</strong></p>}
        </div>

        <div className="mt-5 rounded-2xl border bg-card p-4">
          <div className="flex items-center justify-between"><span className="text-sm text-muted-foreground">পরামর্শ ফি</span><span className="text-2xl font-bold text-primary">{formatPriceBn(product.consultation_fee ?? product.price)}</span></div>
          {product.visiting_days||product.visiting_time?<div className="mt-3 flex items-start gap-2 text-sm"><CalendarDays className="mt-0.5 h-4 w-4 text-primary"/><span>{product.visiting_days||""}{product.visiting_days&&product.visiting_time?" • ":""}{product.visiting_time||""}</span></div>:null}
        </div>

        <div className="mt-5 flex flex-wrap gap-2">
          {phone&&<a href={`tel:${phone}`} className="inline-flex items-center gap-2 rounded-xl bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground"><Phone className="h-4 w-4"/> কল</a>}
          {whatsapp&&<a href={`https://wa.me/${String(whatsapp).replace(/\D/g,"")}?text=${whatsappText}`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 rounded-xl border px-4 py-3 text-sm font-semibold"><MessageCircle className="h-4 w-4"/> হোয়াটসঅ্যাপ</a>}
          <button type="button" onClick={()=>setAppointmentOpen(true)} className="inline-flex items-center gap-2 rounded-xl bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground"><CalendarDays className="h-4 w-4"/> অ্যাপয়েন্টমেন্ট</button>
        </div>

        {product.description&&<div className="mt-6"><h2 className="mb-2 font-semibold">ডাক্তারের সম্পর্কে</h2><p className="whitespace-pre-line text-sm leading-relaxed text-foreground/90">{product.description}</p></div>}

        {chamber&&<div className="mt-6 rounded-2xl border bg-card p-4">
          <Link to={shopPath(chamber.slug)} className="block hover:text-primary">
            <div className="flex items-start gap-3"><MapPin className="mt-0.5 h-5 w-5 text-primary"/><div><p className="font-semibold">{chamber.chamber_name||chamber.shop_name}</p><p className="mt-1 text-sm text-muted-foreground">{chamber.address}</p>{chamber.visiting_days&&<p className="mt-1 text-xs text-muted-foreground">{chamber.visiting_days}{chamber.visiting_time?` • ${chamber.visiting_time}`:""}</p>}</div></div>
          </Link>
          {(chamber.google_map_link || chamber.address) && <a
            href={chamber.google_map_link || `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(chamber.address || "")}`}
            target="_blank" rel="noreferrer"
            className="mt-3 inline-flex items-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground"
          ><Navigation className="h-4 w-4"/> দিকনির্দেশনা</a>}
        </div>}
      </div>
    </div>

    {relatedProducts.length>0&&<section className="mt-12"><h2 className="mb-4 text-lg font-bold" style={{fontFamily:"'Tiro Bangla', serif"}}>সম্পর্কিত ডাক্তার</h2><div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">{relatedProducts.map(p=><ProductCard key={p.id} product={p}/>)}</div></section>}
    {appointmentOpen && <AppointmentDialog
      doctor={product}
      chamber={chamber}
      onClose={()=>setAppointmentOpen(false)}
      onCreated={()=>{ setAppointmentOpen(false); window.alert("অ্যাপয়েন্টমেন্ট অনুরোধ পাঠানো হয়েছে।"); }}
    />}
  </div>;
}
