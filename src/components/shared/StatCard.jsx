import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

const VARIANT_STYLES = {
  primary: "bg-primary/10 text-primary",
  accent: "bg-accent/15 text-accent",
  destructive: "bg-destructive/10 text-destructive",
  muted: "bg-secondary text-foreground",
};

/**
 * সব ড্যাশবোর্ডে (ডাক্তার/অ্যাডমিন/সুপার অ্যাডমিন) ব্যবহৃত কমন সামারি কার্ড —
 * টাইটেল, আইকন, বড় সংখ্যা এবং ঐচ্ছিক হিন্ট/লিংক একইভাবে দেখায়, যাতে পুরো
 * অ্যাপ জুড়ে ভিজ্যুয়াল ধারাবাহিকতা থাকে।
 */
export default function StatCard({
  title,
  icon: Icon,
  value,
  loading,
  hint,
  variant = "primary",
  highlight = false,
  className,
}) {
  return (
    <Card
      className={cn(
        "overflow-hidden transition-shadow hover:shadow-md",
        highlight && "border-accent/50 bg-accent/5",
        className
      )}
    >
      <CardHeader className="flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-xs font-medium text-muted-foreground sm:text-sm">
          {title}
        </CardTitle>
        {Icon && (
          <span
            className={cn(
              "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg sm:h-9 sm:w-9",
              VARIANT_STYLES[variant] || VARIANT_STYLES.primary
            )}
          >
            <Icon className="h-4 w-4" />
          </span>
        )}
      </CardHeader>
      <CardContent>
        <div className="flex items-end justify-between gap-2">
          <p className="text-2xl font-bold tabular-nums sm:text-3xl">
            {loading ? (
              <span className="inline-block h-7 w-12 animate-pulse rounded bg-secondary sm:h-8" />
            ) : (
              (value ?? 0).toLocaleString?.() ?? value
            )}
          </p>
          {hint && !loading && (
            <span className="whitespace-nowrap pb-1 text-xs font-medium text-muted-foreground">
              {hint}
            </span>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
