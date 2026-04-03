import React, { useState } from "react";
import {
  Calendar as CalendarIcon,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { fmtDate, TZ } from "@/utils/format";
import { cn } from "@/lib/utils";

interface DateRangePickerProps {
  from?: string | null;
  to?: string | null;
  onChange: (from: string | null, to: string | null) => void;
}

const PRESETS = [
  { label: "Today", days: 0 },
  { label: "7 days", days: 7 },
  { label: "30 days", days: 30 },
  { label: "90 days", days: 90 },
];

// Get current date parts in Cairo timezone
function getCairoNow() {
  const now = new Date();
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = (t: string) => parseInt(parts.find((p) => p.type === t)!.value);
  return { year: get("year"), month: get("month") - 1, day: get("day") };
}

// Build an ISO string representing the start/end of a Cairo calendar day in UTC
function cairoDateToISO(
  year: number,
  month: number,
  day: number,
  endOfDay = false,
): string {
  // Create a date at Cairo midnight/end-of-day, then convert to UTC ISO
  const cairoOffset = 2 * 60; // Cairo is UTC+2 (no DST)
  const time = endOfDay ? (23 * 60 + 59) * 60 * 1000 + 59999 : 0;
  const utcMs = Date.UTC(year, month, day) - cairoOffset * 60 * 1000 + time;
  return new Date(utcMs).toISOString();
}

function MiniCalendar({
  month,
  year,
  selected,
  hovered,
  onSelect,
  onHover,
  onMonthChange,
}: {
  month: number;
  year: number;
  selected: {
    from?: { y: number; m: number; d: number };
    to?: { y: number; m: number; d: number };
  };
  hovered?: { y: number; m: number; d: number };
  onSelect: (parts: { y: number; m: number; d: number }) => void;
  onHover: (parts: { y: number; m: number; d: number } | undefined) => void;
  onMonthChange: (month: number, year: number) => void;
}) {
  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cairo = getCairoNow();

  const MONTHS = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
  const DAYS = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];

  const prev = () =>
    month === 0 ? onMonthChange(11, year - 1) : onMonthChange(month - 1, year);
  const next = () =>
    month === 11 ? onMonthChange(0, year + 1) : onMonthChange(month + 1, year);

  const toNum = (p?: { y: number; m: number; d: number }) =>
    p ? p.y * 10000 + p.m * 100 + p.d : null;
  const dayNum = (d: number) => year * 10000 + month * 100 + d;

  const fromNum = toNum(selected.from);
  const toNum_ = toNum(selected.to ?? hovered);
  const todayNum = cairo.year * 10000 + cairo.month * 100 + cairo.day;
  const isFutureNum = todayNum;

  const cells = [
    ...Array(firstDay).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];

  return (
    <div className="select-none">
      <div className="flex items-center justify-between mb-3">
        <button
          onClick={prev}
          className="p-1 rounded-lg hover:bg-muted transition-colors"
        >
          <ChevronLeft size={14} />
        </button>
        <span className="text-sm font-semibold">
          {MONTHS[month]} {year}
        </span>
        <button
          onClick={next}
          className="p-1 rounded-lg hover:bg-muted transition-colors"
        >
          <ChevronRight size={14} />
        </button>
      </div>

      <div className="grid grid-cols-7 mb-1">
        {DAYS.map((d) => (
          <div
            key={d}
            className="text-center text-[10px] font-semibold text-muted-foreground py-1"
          >
            {d}
          </div>
        ))}
      </div>

      <div className="grid grid-cols-7 gap-y-0.5">
        {cells.map((d, i) => {
          if (!d) return <div key={i} />;
          const dn = dayNum(d);
          const isFuture = dn > isFutureNum;
          const isToday = dn === todayNum;
          const isStart = fromNum !== null && dn === fromNum;
          const isEnd = toNum_ !== null && fromNum !== null && dn === toNum_;
          const lo =
            fromNum !== null && toNum_ !== null
              ? Math.min(fromNum, toNum_)
              : null;
          const hi =
            fromNum !== null && toNum_ !== null
              ? Math.max(fromNum, toNum_)
              : null;
          const inRange = lo !== null && hi !== null && dn > lo && dn < hi;

          return (
            <div
              key={i}
              className={cn(
                "relative flex items-center justify-center h-8",
                inRange && "bg-primary/10",
                isStart && "bg-primary/10 rounded-l-full",
                isEnd && "bg-primary/10 rounded-r-full",
                isStart && !selected.to && !hovered && "rounded-full",
              )}
            >
              <button
                disabled={isFuture}
                onClick={() => !isFuture && onSelect({ y: year, m: month, d })}
                onMouseEnter={() =>
                  !isFuture && onHover({ y: year, m: month, d })
                }
                onMouseLeave={() => onHover(undefined)}
                className={cn(
                  "w-8 h-8 rounded-full text-xs font-medium transition-all flex items-center justify-center",
                  isFuture && "text-muted-foreground/30 cursor-not-allowed",
                  !isFuture && !isStart && !isEnd && "hover:bg-muted",
                  isToday &&
                    !isStart &&
                    !isEnd &&
                    "border border-primary text-primary",
                  (isStart || isEnd) &&
                    "bg-primary text-primary-foreground font-semibold shadow-sm",
                )}
              >
                {d}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

type DayParts = { y: number; m: number; d: number };

export function DateRangePicker({ from, to, onChange }: DateRangePickerProps) {
  const [open, setOpen] = useState(false);
  const [hovered, setHovered] = useState<DayParts | undefined>();

  const isoToParts = (iso: string): DayParts => {
    const parts = new Intl.DateTimeFormat("en-GB", {
      timeZone: TZ,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(new Date(iso));
    const get = (t: string) => parseInt(parts.find((p) => p.type === t)!.value);
    return { y: get("year"), m: get("month") - 1, d: get("day") };
  };

  const [selected, setSelected] = useState<{ from?: DayParts; to?: DayParts }>({
    from: from ? isoToParts(from) : undefined,
    to: to ? isoToParts(to) : undefined,
  });

  const cairo = getCairoNow();
  const [month, setMonth] = useState(cairo.month);
  const [year, setYear] = useState(cairo.year);

  const applyPreset = (days: number) => {
    const now = getCairoNow();
    const start = new Date(
      Date.UTC(now.year, now.month, now.day) - days * 86400000,
    );
    const sp = new Intl.DateTimeFormat("en-GB", {
      timeZone: TZ,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(start);
    const get = (t: string) => parseInt(sp.find((p) => p.type === t)!.value);
    onChange(
      cairoDateToISO(get("year"), get("month") - 1, get("day")),
      cairoDateToISO(now.year, now.month, now.day, true),
    );
  };

  const handleSelect = (p: DayParts) => {
    if (!selected.from || (selected.from && selected.to)) {
      setSelected({ from: p, to: undefined });
    } else {
      const fromNum =
        selected.from.y * 10000 + selected.from.m * 100 + selected.from.d;
      const toNum = p.y * 10000 + p.m * 100 + p.d;
      if (toNum >= fromNum) setSelected({ from: selected.from, to: p });
      else setSelected({ from: p, to: selected.from });
    }
  };

  const handleApply = () => {
    if (selected.from) {
      const f = selected.from;
      const t = selected.to ?? selected.from;
      onChange(
        cairoDateToISO(f.y, f.m, f.d),
        cairoDateToISO(t.y, t.m, t.d, true),
      );
    }
    setOpen(false);
  };

  const handleCancel = () => {
    setSelected({
      from: from ? isoToParts(from) : undefined,
      to: to ? isoToParts(to) : undefined,
    });
    setOpen(false);
  };

  const isPresetActive = (days: number) => {
    if (!from || !to) return false;
    const now = getCairoNow();
    const start = new Date(
      Date.UTC(now.year, now.month, now.day) - days * 86400000,
    );
    const sp = new Intl.DateTimeFormat("en-GB", {
      timeZone: TZ,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(start);
    const get = (t: string) => parseInt(sp.find((p) => p.type === t)!.value);
    return (
      from === cairoDateToISO(get("year"), get("month") - 1, get("day")) &&
      to === cairoDateToISO(now.year, now.month, now.day, true)
    );
  };

  const fmtParts = (p: DayParts) => fmtDate(cairoDateToISO(p.y, p.m, p.d));

  const isAllTime = !from && !to;
  const isCustom =
    from &&
    !isPresetActive(0) &&
    !isPresetActive(7) &&
    !isPresetActive(30) &&
    !isPresetActive(90) &&
    !isAllTime;

  return (
    <div className="flex items-center gap-2 flex-wrap">
      {PRESETS.map((p) => (
        <Button
          key={p.label}
          variant={isPresetActive(p.days) ? "default" : "outline"}
          size="sm"
          onClick={() => applyPreset(p.days)}
          className="h-8 text-xs"
        >
          {p.label}
        </Button>
      ))}

      <Button
        variant={isAllTime ? "default" : "outline"}
        size="sm"
        onClick={() => onChange(null, null)}
        className="h-8 text-xs"
      >
        All time
      </Button>

      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant={isCustom ? "default" : "outline"}
            size="sm"
            className="h-8 text-xs gap-1.5"
          >
            <CalendarIcon size={11} />
            {isCustom
              ? `${fmtDate(from!)} → ${to ? fmtDate(to) : "now"}`
              : "Custom"}
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-auto p-4 shadow-xl" align="start">
          <div className="flex items-center gap-3 mb-4 p-2.5 bg-muted rounded-xl text-xs">
            <div className="flex-1 text-center">
              <p className="text-muted-foreground mb-0.5">From</p>
              <p className="font-semibold">
                {selected.from ? fmtParts(selected.from) : "—"}
              </p>
            </div>
            <div className="w-px h-6 bg-border" />
            <div className="flex-1 text-center">
              <p className="text-muted-foreground mb-0.5">To</p>
              <p className="font-semibold">
                {selected.to
                  ? fmtParts(selected.to)
                  : hovered
                    ? fmtParts(hovered)
                    : "—"}
              </p>
            </div>
          </div>

          <MiniCalendar
            month={month}
            year={year}
            selected={selected}
            hovered={hovered}
            onSelect={handleSelect}
            onHover={setHovered}
            onMonthChange={(m, y) => {
              setMonth(m);
              setYear(y);
            }}
          />

          <div className="flex items-center justify-between mt-4 pt-3 border-t">
            <p className="text-xs text-muted-foreground">
              {!selected.from
                ? "Click a start date"
                : !selected.to
                  ? "Click an end date"
                  : "Range selected"}
            </p>
            <div className="flex gap-2">
              <Button variant="ghost" size="sm" onClick={handleCancel}>
                Cancel
              </Button>
              <Button size="sm" onClick={handleApply} disabled={!selected.from}>
                Apply
              </Button>
            </div>
          </div>
        </PopoverContent>
      </Popover>
    </div>
  );
}
