import { useEffect, useMemo, useState } from "react";
import { Save, Trash2, Check, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import ImageUploader from "@/components/shared/ImageUploader.jsx";

/**
 * সাধারণ key-value ভিত্তিক CMS সেকশনগুলোর জন্য (General, Hero, About,
 * Contact, Legal, Footer, SEO) একটি reusable ফর্ম গ্রুপ।
 *
 * @param {{
 *   title: string,
 *   description?: string,
 *   fields: Array<{
 *     key: string,
 *     label: string,
 *     type?: "text" | "textarea" | "image",
 *     placeholder?: string,
 *     help?: string,
 *     required?: boolean,
 *     maxLength?: number,
 *     rows?: number,
 *     bucket?: string,   // type=image হলে দরকার
 *     folder?: string,   // type=image হলে দরকার
 *   }>,
 *   values: Record<string,string>,
 *   onSave: (patch: Record<string,string>) => Promise<{error:any}>,
 *   onClearField: (key: string) => Promise<{error:any}>,
 * }} props
 */
export default function SettingsFieldGroup({ title, description, fields, values, onSave, onClearField }) {
  const initial = useMemo(() => {
    const map = {};
    fields.forEach((f) => (map[f.key] = values[f.key] ?? ""));
    return map;
  }, [fields, values]); // eslint-disable-line react-hooks/exhaustive-deps

  const [form, setForm] = useState(initial);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  const [clearingKey, setClearingKey] = useState("");

  // বাইরে থেকে values পাল্টালে (যেমন প্রথম লোড শেষ হলে) ফর্ম sync করা
  useEffect(() => {
    setForm(initial);
  }, [initial]);

  const setField = (key, val) => setForm((f) => ({ ...f, [key]: val }));

  const validate = () => {
    for (const f of fields) {
      const val = (form[f.key] ?? "").trim();
      if (f.required && !val) {
        return `"${f.label}" আবশ্যক — খালি রাখা যাবে না।`;
      }
      if (f.maxLength && val.length > f.maxLength) {
        return `"${f.label}" সর্বোচ্চ ${f.maxLength} অক্ষরের মধ্যে হতে হবে (বর্তমানে ${val.length})।`;
      }
      if (val && f.validate) {
        const msg = f.validate(val);
        if (msg) return `"${f.label}": ${msg}`;
      }
    }
    return "";
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }
    setError("");
    setSaving(true);
    const { error: saveError } = await onSave(form);
    setSaving(false);
    if (saveError) {
      setError("সংরক্ষণ ব্যর্থ হয়েছে: " + saveError.message);
      return;
    }
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  };

  const handleClearField = async (key, label) => {
    if (!window.confirm(`"${label}" মুছে ফেলে ডিফল্টে ফিরিয়ে নিতে চান?`)) return;
    setClearingKey(key);
    const { error: clearError } = await onClearField(key);
    setClearingKey("");
    if (clearError) {
      setError("মুছে ফেলা যায়নি: " + clearError.message);
      return;
    }
    setField(key, "");
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-5 rounded-xl border border-border bg-card p-5">
      <div>
        <h2 className="text-base font-semibold">{title}</h2>
        {description && <p className="mt-0.5 text-sm text-muted-foreground">{description}</p>}
      </div>

      <div className="space-y-4">
        {fields.map((f) => (
          <div key={f.key} className="space-y-1.5">
            <div className="flex items-center justify-between gap-2">
              <Label htmlFor={f.key}>
                {f.label}
                {f.required && <span className="text-destructive"> *</span>}
              </Label>
              {!!(values[f.key] || form[f.key]) && (
                <button
                  type="button"
                  onClick={() => handleClearField(f.key, f.label)}
                  disabled={clearingKey === f.key}
                  className="flex items-center gap-1 text-xs text-muted-foreground hover:text-destructive disabled:opacity-50"
                >
                  <Trash2 className="h-3 w-3" />
                  {clearingKey === f.key ? "মুছে ফেলা হচ্ছে..." : "মুছুন"}
                </button>
              )}
            </div>

            {f.type === "image" ? (
              <ImageUploader
                bucket={f.bucket || "site-assets"}
                folder={f.folder || "cms"}
                value={form[f.key]}
                onUploaded={(url) => setField(f.key, url)}
                aspect={f.aspect || "wide"}
              />
            ) : f.type === "textarea" ? (
              <>
                <Textarea
                  id={f.key}
                  rows={f.rows || 6}
                  placeholder={f.placeholder}
                  value={form[f.key] || ""}
                  onChange={(e) => setField(f.key, e.target.value)}
                />
                {f.maxLength && (
                  <p className="text-right text-xs text-muted-foreground">
                    {(form[f.key] || "").length}/{f.maxLength}
                  </p>
                )}
              </>
            ) : (
              <Input
                id={f.key}
                placeholder={f.placeholder}
                value={form[f.key] || ""}
                onChange={(e) => setField(f.key, e.target.value)}
                maxLength={f.maxLength ? f.maxLength + 20 : undefined}
              />
            )}
            {f.help && <p className="text-xs text-muted-foreground">{f.help}</p>}
          </div>
        ))}
      </div>

      {error && (
        <p className="flex items-start gap-1.5 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          {error}
        </p>
      )}

      <Button type="submit" disabled={saving}>
        {saved ? <Check className="h-4 w-4" /> : <Save className="h-4 w-4" />}
        {saving ? "সংরক্ষণ হচ্ছে..." : saved ? "সংরক্ষিত হয়েছে" : "সংরক্ষণ করুন"}
      </Button>
    </form>
  );
}
