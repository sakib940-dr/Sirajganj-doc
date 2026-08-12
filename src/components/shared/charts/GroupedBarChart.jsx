import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import ChartCard from "./ChartCard.jsx";
import { ChartTooltip } from "./ChartTooltip.jsx";

const DEFAULT_COLORS = [
  "hsl(var(--primary))",
  "hsl(var(--accent))",
  "hsl(0 72% 51%)",
  "hsl(217 91% 60%)",
];

// ছোট স্ক্রিনে Legend-এর বদলে কম্প্যাক্ট কালার-ডট লিস্ট দেখানো হয়
function CompactLegend({ series, colors }) {
  return (
    <div className="mb-2 flex flex-wrap items-center gap-x-4 gap-y-1.5 px-1">
      {series.map((s, idx) => (
        <span key={s.key} className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <span
            className="h-2.5 w-2.5 shrink-0 rounded-full"
            style={{ backgroundColor: s.color || colors[idx % colors.length] }}
          />
          {s.label}
        </span>
      ))}
    </div>
  );
}

/**
 * একাধিক মেট্রিক (যেমন: নতুন ইউজার / ডাক্তার / ডাক্তার প্রোফাইল) একসাথে তুলনা করার জন্য
 * গ্রুপড ভার্টিক্যাল বার চার্ট — Growth Summary (দৈনিক/সাপ্তাহিক/মাসিক) বা
 * Engagement (ভিউ/সেভ/ক্লিক) দেখাতে ব্যবহৃত হয়।
 *
 * data: [{ label: "দৈনিক", new_users: 3, new_products: 5, ... }]
 * series: [{ key: "new_users", label: "নতুন ইউজার", color? }]
 */
export default function GroupedBarChart({
  title,
  icon,
  description,
  data = [],
  series = [],
  loading,
  emptyLabel,
  height = 260,
  colors = DEFAULT_COLORS,
}) {
  return (
    <ChartCard
      title={title}
      icon={icon}
      description={description}
      loading={loading}
      isEmpty={!loading && data.length === 0}
      emptyLabel={emptyLabel}
      height={height}
    >
      <div className="flex h-full flex-col">
        <CompactLegend series={series} colors={colors} />
        <div className="min-h-0 flex-1">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
              <CartesianGrid vertical={false} stroke="hsl(var(--border))" />
              <XAxis
                dataKey="label"
                tick={{ fontSize: 12, fill: "hsl(var(--foreground))" }}
                axisLine={{ stroke: "hsl(var(--border))" }}
                tickLine={false}
              />
              <YAxis
                allowDecimals={false}
                tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
                axisLine={false}
                tickLine={false}
                width={36}
              />
              <Tooltip cursor={{ fill: "hsl(var(--secondary))" }} content={<ChartTooltip />} />
              {series.map((s, idx) => (
                <Bar
                  key={s.key}
                  dataKey={s.key}
                  name={s.label}
                  fill={s.color || colors[idx % colors.length]}
                  radius={[4, 4, 0, 0]}
                  maxBarSize={28}
                />
              ))}
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </ChartCard>
  );
}
