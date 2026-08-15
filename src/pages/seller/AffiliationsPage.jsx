import { useCallback, useEffect, useState } from "react";
import { Building2, CheckCircle2, Search, Send, UserRound, XCircle, Link2Off, Clock3 } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { ROLES, SELLER_STATUS } from "@/constants/roles";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import PendingApprovalNotice from "@/components/seller/PendingApprovalNotice.jsx";
import {
  inviteDoctor,
  leaveProviderAffiliation,
  listMyProviderInvitations,
  listProviderDoctorLinks,
  respondToProviderInvitation,
  searchInvitableDoctors,
} from "@/services/affiliationService";

const STATUS_BN = { pending: "অপেক্ষমাণ", approved: "যুক্ত", rejected: "প্রত্যাখ্যাত", inactive: "নিষ্ক্রিয়" };

export default function AffiliationsPage() {
  const { role, sellerStatus } = useAuth();
  if (sellerStatus !== SELLER_STATUS.APPROVED) return <PendingApprovalNotice status={sellerStatus} role={role} />;
  return role === ROLES.HOSPITAL ? <HospitalDoctorLinks /> : <DoctorInvitations />;
}

function HospitalDoctorLinks() {
  const [links, setLinks] = useState([]);
  const [doctors, setDoctors] = useState([]);
  const [query, setQuery] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    const [{ data: linkRows, error: linkError }, { data: doctorRows, error: doctorError }] = await Promise.all([
      listProviderDoctorLinks(),
      searchInvitableDoctors(query),
    ]);
    setLinks(linkRows || []);
    setDoctors(doctorRows || []);
    setError(linkError?.message || doctorError?.message || "");
    setLoading(false);
  }, [query]);

  useEffect(() => { const t = setTimeout(load, 250); return () => clearTimeout(t); }, [load]);

  async function sendInvite(doctorId) {
    setBusy(doctorId); setError("");
    const { error: e } = await inviteDoctor(doctorId, message);
    setBusy("");
    if (e) setError(e.message); else { setMessage(""); await load(); }
  }
  async function deactivate(linkId) {
    if (!window.confirm("এই ডাক্তারকে প্রতিষ্ঠান থেকে নিষ্ক্রিয় করতে চান?")) return;
    setBusy(linkId); const { error: e } = await leaveProviderAffiliation(linkId); setBusy("");
    if (e) setError(e.message); else load();
  }

  if (loading && !links.length && !doctors.length) return <LoadingSpinner label="ডাক্তার সংযোগ লোড হচ্ছে..." />;
  const linked = new Map(links.map((l) => [l.doctor_id, l]));
  return <div className="space-y-6">
    <div><h1 className="text-xl font-bold">ডাক্তার সংযোগ ও আমন্ত্রণ</h1><p className="mt-1 text-sm text-muted-foreground">ডাক্তারকে আমন্ত্রণ পাঠান। ডাক্তার গ্রহণ করার পরই তাকে আপনার হাসপাতাল/চেম্বারে প্রকাশ ও সময়সূচিতে যুক্ত করা যাবে।</p></div>
    {error && <div className="rounded-xl bg-destructive/10 p-3 text-sm text-destructive">{error}</div>}

    <section className="rounded-2xl border bg-card p-4 shadow-sm">
      <div className="flex items-center gap-2"><Search className="h-4 w-4 text-primary"/><h2 className="font-semibold">অনুমোদিত ডাক্তার খুঁজুন</h2></div>
      <div className="mt-3 grid gap-2 sm:grid-cols-[1fr_1fr]">
        <Input placeholder="নাম বা ফোন দিয়ে খুঁজুন" value={query} onChange={(e)=>setQuery(e.target.value)} />
        <Input placeholder="আমন্ত্রণ বার্তা (ঐচ্ছিক)" value={message} onChange={(e)=>setMessage(e.target.value)} />
      </div>
      <div className="mt-3 grid gap-2 sm:grid-cols-2">
        {doctors.map((d) => {
          const l = linked.get(d.id);
          return <div key={d.id} className="flex items-center justify-between gap-3 rounded-xl border p-3">
            <div className="min-w-0"><p className="truncate font-medium">{d.full_name || "ডাক্তার"}</p><p className="text-xs text-muted-foreground">{d.phone || "ফোন নেই"}{l ? ` • ${STATUS_BN[l.status] || l.status}` : ""}</p></div>
            {l?.status === "approved" ? <span className="rounded-full bg-primary/10 px-2 py-1 text-xs font-semibold text-primary">যুক্ত</span> :
              l?.status === "pending" ? <span className="rounded-full bg-amber-50 px-2 py-1 text-xs font-semibold text-amber-700">অপেক্ষমাণ</span> :
              <Button size="sm" disabled={busy===d.id} onClick={()=>sendInvite(d.id)}><Send className="h-4 w-4"/>{l ? "পুনরায় আমন্ত্রণ" : "আমন্ত্রণ"}</Button>}
          </div>;
        })}
      </div>
    </section>

    <section><h2 className="mb-3 font-semibold">আমার প্রতিষ্ঠানের ডাক্তার</h2>
      {!links.length ? <div className="rounded-xl border p-6 text-center text-sm text-muted-foreground">এখনো কোনো ডাক্তার আমন্ত্রণ/সংযোগ নেই।</div> : <div className="space-y-2">{links.map(l=><div key={l.link_id} className="rounded-xl border bg-card p-4"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="font-semibold">{l.doctor_name}</p><p className="mt-1 flex items-center gap-1 text-xs text-muted-foreground"><Clock3 className="h-3.5 w-3.5"/>{STATUS_BN[l.status] || l.status}</p>{l.invitation_message&&<p className="mt-2 text-sm text-muted-foreground">{l.invitation_message}</p>}</div>{l.status==='approved'&&<Button size="sm" variant="outline" disabled={busy===l.link_id} onClick={()=>deactivate(l.link_id)}><Link2Off className="h-4 w-4"/> নিষ্ক্রিয়</Button>}</div></div>)}</div>}
    </section>
  </div>;
}

function DoctorInvitations() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const load = useCallback(async()=>{setLoading(true);const {data,error:e}=await listMyProviderInvitations();setRows(data||[]);setError(e?.message||"");setLoading(false);},[]);
  useEffect(()=>{load();},[load]);
  async function respond(id, accept){setBusy(id);const {error:e}=await respondToProviderInvitation(id,accept);setBusy("");if(e)setError(e.message);else load();}
  async function leave(id){if(!window.confirm("এই হাসপাতাল/চেম্বারের সংযোগ শেষ করতে চান?"))return;setBusy(id);const {error:e}=await leaveProviderAffiliation(id);setBusy("");if(e)setError(e.message);else load();}
  if(loading)return <LoadingSpinner label="আমন্ত্রণ লোড হচ্ছে..."/>;
  return <div className="space-y-5"><div><h1 className="text-xl font-bold">হাসপাতাল / চেম্বার আমন্ত্রণ</h1><p className="mt-1 text-sm text-muted-foreground">কোন প্রতিষ্ঠানের সাথে আপনার ডাক্তার প্রোফাইল যুক্ত হবে, সেটি আপনি নিয়ন্ত্রণ করবেন।</p></div>{error&&<div className="rounded-xl bg-destructive/10 p-3 text-sm text-destructive">{error}</div>}{!rows.length?<div className="rounded-2xl border p-8 text-center text-sm text-muted-foreground">এখনো কোনো আমন্ত্রণ নেই।</div>:<div className="space-y-3">{rows.map(r=><div key={r.link_id} className="rounded-2xl border bg-card p-4"><div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"><div className="flex items-start gap-3"><Building2 className="mt-0.5 h-5 w-5 text-primary"/><div><p className="font-semibold">{r.provider_name}</p><p className="mt-1 text-xs text-muted-foreground">{STATUS_BN[r.status]||r.status}</p>{r.invitation_message&&<p className="mt-2 text-sm">{r.invitation_message}</p>}</div></div><div className="flex gap-2">{r.status==='pending'&&<><Button size="sm" disabled={busy===r.link_id} onClick={()=>respond(r.link_id,true)}><CheckCircle2 className="h-4 w-4"/> গ্রহণ</Button><Button size="sm" variant="outline" disabled={busy===r.link_id} onClick={()=>respond(r.link_id,false)}><XCircle className="h-4 w-4"/> প্রত্যাখ্যান</Button></>}{r.status==='approved'&&<Button size="sm" variant="outline" disabled={busy===r.link_id} onClick={()=>leave(r.link_id)}><Link2Off className="h-4 w-4"/> সংযোগ শেষ</Button>}</div></div></div>)}</div>}</div>;
}
