"use client"

import { Bar, BarChart, CartesianGrid, XAxis, YAxis } from "recharts"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"
import { formatRupiah } from "@/lib/utils"
import type { RevenueChartProps } from "@/components/features/revenue/types/revenue"

const chartConfig = {
  net: {
    label: "Pendapatan Bersih",
    color: "var(--chart-1)",
  },
} satisfies ChartConfig

export function RevenueChart({ data }: RevenueChartProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Pendapatan 30 Hari Terakhir</CardTitle>
        <CardDescription>
          Pendapatan bersih developer per hari (biaya transaksi dikurangi poin
          yang ditukar).
        </CardDescription>
      </CardHeader>
      <CardContent>
        <ChartContainer config={chartConfig} className="h-[300px] w-full">
          <BarChart accessibilityLayer data={data}>
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="date"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
              tickFormatter={(value: string) => value.slice(5)}
            />
            <YAxis
              tickLine={false}
              axisLine={false}
              width={88}
              tickFormatter={(value: number) => formatRupiah(value)}
            />
            <ChartTooltip
              content={
                <ChartTooltipContent
                  formatter={(value) => formatRupiah(Number(value))}
                />
              }
            />
            <Bar dataKey="net" fill="var(--color-net)" radius={4} />
          </BarChart>
        </ChartContainer>
      </CardContent>
    </Card>
  )
}
