import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import ChartCard from "./ChartCard.jsx";
import { ChartTooltip } from "./ChartTooltip.jsx";

const DEFAULT_COLOR = "hsl(var(--primary))";

// লেবেল বেশি লম্বা হলে চার্টে জায়গা বাঁচাতে ছোট করে দেখানো হয় (পুরো নাম টুলটিপে থাকে)
function truncateLabel(label = "", max = 16) {
  return label.length > max ? `${label.slice(0, max - 1)}…` : label;
}

/**
 * একটিমাত্র মেট্রিকের জন্য হরাইজন্টাল বার চার্ট — Top Products / Top Categories /
 * Top Sellers-এর মতো র‍্যাংকড ডেটা মোবাইলেও পরিষ্কার দেখানোর জন্য উপযোগী,
 * কারণ লম্বা নাম Y-axis-এ ভালোভাবে ধরে।
 */
export default function BarStatChart({
  title,
  icon,
  description,
  data = [],
  loading,
  emptyLabel,
  valueLabel,
  color = DEFAULT_COLOR,
  height,
}) {
  const chartHeight = height ?? Math.max(180, data.length * 42 + 20);

  return (
    <ChartCard
      title={title}
      icon={icon}
      description={description}
      loading={loading}
      isEmpty={!loading && data.length === 0}
      emptyLabel={emptyLabel}
      height={chartHeight}
    >
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={data}
          layout="vertical"
          margin={{ top: 4, right: 16, bottom: 4, left: 0 }}
          barCategoryGap={10}
        >
          <CartesianGrid horizontal={false} stroke="hsl(var(--border))" />
          <XAxis
            type="number"
            allowDecimals={false}
            tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
            axisLine={{ stroke: "hsl(var(--border))" }}
            tickLine={false}
          />
          <YAxis
            type="category"
            dataKey="label"
            width={92}
            tick={{ fontSize: 12, fill: "hsl(var(--foreground))" }}
            tickFormatter={(v) => truncateLabel(v, 14)}
            axisLine={false}
            tickLine={false}
          />
          <Tooltip
            cursor={{ fill: "hsl(var(--secondary))" }}
            content={<ChartTooltip valueLabel={valueLabel} />}
          />
          <Bar dataKey="value" name={valueLabel || title} radius={[0, 6, 6, 0]} maxBarSize={22}>
            {data.map((entry, idx) => (
              <Cell key={idx} fill={entry.color || color} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </ChartCard>
  );
}
