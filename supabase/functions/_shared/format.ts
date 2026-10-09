const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export function fmtDate(d: string | Date | null | undefined) {
  if (!d) return "—";
  const x = typeof d === "string" ? new Date(d.length === 10 ? d + "T00:00:00Z" : d) : d;
  return `${x.getUTCDate()} ${MONTHS[x.getUTCMonth()]} ${x.getUTCFullYear()}`;
}

export function fmtNum(n: number) {
  return new Intl.NumberFormat("en-US").format(n);
}

export function daysBetween(from: Date, to: Date) {
  const a = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate());
  const b = Date.UTC(to.getUTCFullYear(), to.getUTCMonth(), to.getUTCDate());
  return Math.round((b - a) / 86_400_000);
}

export function relativeDays(d: string, now = new Date()) {
  const n = daysBetween(now, new Date(d + "T00:00:00Z"));
  if (n === 0) return "today";
  if (n === 1) return "tomorrow";
  if (n === -1) return "yesterday";
  return n > 0 ? `in ${n} days` : `${-n} days ago`;
}

export function vehicleName(v: { nickname?: string | null; year: number; make: string; model: string }) {
  return v.nickname?.trim() || `${v.year} ${v.make} ${v.model}`;
}

export function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!,
  );
}

export type TaskRow = {
  next_due_at: string | null;
  next_due_mileage: number | null;
  remind_days_before: number;
  remind_mileage_before: number;
};

export function taskStatus(t: TaskRow, mileage: number, now = new Date()) {
  if (!t.next_due_at && t.next_due_mileage === null) return "unscheduled";
  let overdue = false;
  let soon = false;
  if (t.next_due_at) {
    const days = daysBetween(now, new Date(t.next_due_at + "T00:00:00Z"));
    if (days <= 0) overdue = true;
    else if (days <= t.remind_days_before) soon = true;
  }
  if (t.next_due_mileage !== null) {
    if (mileage >= t.next_due_mileage) overdue = true;
    else if (t.next_due_mileage - mileage <= t.remind_mileage_before) soon = true;
  }
  return overdue ? "overdue" : soon ? "due-soon" : "ok";
}

export function documentStatus(d: { expires_at: string | null; remind_days_before: number }, now = new Date()) {
  if (!d.expires_at) return "no-expiry";
  const days = daysBetween(now, new Date(d.expires_at + "T00:00:00Z"));
  if (days <= 0) return "expired";
  if (days <= d.remind_days_before) return "expiring";
  return "valid";
}

export const DOC_TYPES: Record<string, string> = {
  drivers_license: "Driver's license",
  insurance: "Insurance",
  registration: "Vehicle registration",
  roadworthiness: "Roadworthiness certificate",
  inspection: "Inspection / MOT",
  emissions: "Emissions test",
  permit: "Permit",
  warranty: "Warranty",
  receipt: "Receipt",
  other: "Document",
};
