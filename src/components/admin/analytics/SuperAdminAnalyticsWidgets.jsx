import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import StatCard from "@/components/shared/StatCard.jsx";

// ছোট সামারি সংখ্যার কার্ড (Total Users, Total Products ইত্যাদি) — এখন
// শেয়ার্ড StatCard ব্যবহার করে, যাতে ডাক্তার/অ্যাডমিন/সুপার অ্যাডমিন সব
// ড্যাশবোর্ডে একই ডিজাইন বজায় থাকে
export { StatCard };

/**
 * সাধারণ র‍্যাংকড লিস্ট কার্ড — Top Sellers / Top Viewed Products /
 * Top Saved Products / Top Categories — সবগুলোই একই শেপে রেন্ডার করে:
 * items: [{ id, imageUrl?, title, subtitle?, metricValue, metricLabel? }]
 */
export function RankedListCard({ title, icon: Icon, items, emptyLabel, loading }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">
          <Icon className="h-4 w-4 text-primary" />
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent>
        {loading ? (
          <p className="py-6 text-center text-sm text-muted-foreground">লোড হচ্ছে...</p>
        ) : items.length === 0 ? (
          <p className="py-6 text-center text-sm text-muted-foreground">{emptyLabel}</p>
        ) : (
          <div className="space-y-1">
            {items.map((item, idx) => (
              <div
                key={item.id}
                className="flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-secondary/50"
              >
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold text-muted-foreground">
                  {idx + 1}
                </span>
                {item.imageUrl !== undefined && (
                  <div className="h-9 w-9 shrink-0 overflow-hidden rounded-lg bg-secondary">
                    {item.imageUrl && (
                      <img src={item.imageUrl} alt="" className="h-full w-full object-cover" />
                    )}
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <p className="line-clamp-1 text-sm font-medium">{item.title}</p>
                  {item.subtitle && (
                    <p className="line-clamp-1 text-xs text-muted-foreground">{item.subtitle}</p>
                  )}
                </div>
                <span className="flex shrink-0 items-center gap-1 text-sm font-semibold text-primary">
                  {item.metricValue}
                  {item.metricLabel && (
                    <span className="hidden text-xs font-normal text-muted-foreground sm:inline">
                      {item.metricLabel}
                    </span>
                  )}
                </span>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

// Daily / Weekly / Monthly Growth Summary — একটি পিরিয়ডের ৩টা সংখ্যা দেখায়
export function GrowthPeriodCard({ title, icon: Icon, stats, loading }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">
          <Icon className="h-4 w-4 text-primary" />
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-2.5">
        {stats.map((s) => (
          <div key={s.label} className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">{s.label}</span>
            <span className="font-semibold tabular-nums">{loading ? "..." : s.value}</span>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
