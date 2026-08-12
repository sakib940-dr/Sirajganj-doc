import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import ChartCard from "./ChartCard.jsx";
import { ChartTooltip } from "./ChartTooltip.jsx";

const DEFAULT_COLORS = ["hsl(var(--primary))", "hsl(var(--accent))", "hsl(var(--muted-foreground))"];

/**
 * ডোনাট চার্ট — কেন্দ্রে মোট সংখ্যা দেখায়, পাশে একটি ছোট লিজেন্ড/ব্রেকডাউন লিস্ট।
 * "এক নজরে" স্ট্যাটাস অনুপাত (যেমন: সক্রিয় বনাম স্টক-আউট ডাক্তার প্রোফাইল) বোঝানোর জন্য উপযোগী।
 * data: [{ label, value, color? }]
 */
export default function DonutStatChart({
  title,
  icon,
  description,
  data = [],
  loading,
  emptyLabel,
  centerLabel = "মোট",
  colors = DEFAULT_COLORS,
  height = 220,
}) {
  const total = data.reduce((sum, d) => sum + (d.value || 0), 0);
  const isEmpty = !loading && (data.length === 0 || total === 0);

  return (
    <ChartCard
      title={title}
      icon={icon}
      description={description}
      loading={loading}
      isEmpty={isEmpty}
      emptyLabel={emptyLabel}
      height={height}
    >
      <div className="flex h-full items-center gap-4">
        <div className="relative h-full flex-1">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={data}
                dataKey="value"
                nameKey="label"
                innerRadius="62%"
                outerRadius="90%"
                paddingAngle={2}
                stroke="hsl(var(--card))"
                strokeWidth={2}
              >
                {data.map((entry, idx) => (
                  <Cell key={idx} fill={entry.color || colors[idx % colors.length]} />
                ))}
              </Pie>
              <Tooltip content={<ChartTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-2xl font-bold tabular-nums">{total.toLocaleString()}</span>
            <span className="text-xs text-muted-foreground">{centerLabel}</span>
          </div>
        </div>
        <div className="flex shrink-0 flex-col gap-2">
          {data.map((entry, idx) => (
            <div key={entry.label} className="flex items-center gap-2 text-xs">
              <span
                className="h-2.5 w-2.5 shrink-0 rounded-full"
                style={{ backgroundColor: entry.color || colors[idx % colors.length] }}
              />
              <span className="text-muted-foreground">{entry.label}</span>
              <span className="font-semibold tabular-nums text-foreground">{entry.value}</span>
            </div>
          ))}
        </div>
      </div>
    </ChartCard>
  );
}
