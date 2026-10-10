// Daily job: finds maintenance that's due/overdue and documents that are expiring/expired,
// then creates in-app alerts and sends one email digest per user.
// Scheduled with pg_cron (see supabase/migrations/*_reminders_schedule.sql).
import { adminClient } from "../_shared/clients.ts";
import { json } from "../_shared/cors.ts";
import { DOC_TYPES, documentStatus, escapeHtml, fmtDate, fmtNum, relativeDays, taskStatus, vehicleName } from "../_shared/format.ts";

const RENOTIFY_DAYS = 7;
const PAGE = 500;

type Item = { kind: string; title: string; body: string; link: string };

// The cron job sends the secret stored in Vault as `autox_cron_secret`.
// A CRON_SECRET env var is also accepted, for projects that prefer function secrets.
async function authorized(db: ReturnType<typeof adminClient>, given: string | null) {
  if (!given) return false;
  const envSecret = Deno.env.get("CRON_SECRET");
  if (envSecret && given === envSecret) return true;
  const { data } = await db.rpc("verify_cron_secret", { p_secret: given });
  return data === true;
}

Deno.serve(async (req) => {
  const db = adminClient();
  if (!(await authorized(db, req.headers.get("x-cron-secret")))) return json({ error: "Unauthorized" }, 401);

  const now = new Date();
  const cutoff = new Date(now.getTime() - RENOTIFY_DAYS * 86_400_000).toISOString();
  const perUser = new Map<string, Item[]>();
  const add = (uid: string, item: Item) => perUser.set(uid, [...(perUser.get(uid) ?? []), item]);

  const units = new Map<string, string>();
  const unitFor = async (uid: string) => {
    if (!units.has(uid)) {
      const { data } = await db.from("profiles").select("distance_unit").eq("id", uid).single();
      units.set(uid, data?.distance_unit === "mi" ? "mi" : "km");
    }
    return units.get(uid)!;
  };

  // Maintenance
  const taskIds: string[] = [];
  for (let from = 0; ; from += PAGE) {
    const { data: tasks, error } = await db
      .from("maintenance_tasks")
      .select("*, vehicle:vehicles(*)")
      .or("next_due_at.not.is.null,next_due_mileage.not.is.null")
      .or(`last_notified_at.is.null,last_notified_at.lt.${cutoff}`)
      .order("id")
      .range(from, from + PAGE - 1);
    if (error) return json({ error: error.message }, 500);
    for (const t of tasks ?? []) {
      const status = taskStatus(t, t.vehicle.mileage, now);
      if (status !== "overdue" && status !== "due-soon") continue;
      const unit = await unitFor(t.user_id);
      const parts: string[] = [];
      if (t.next_due_at) parts.push(`${status === "overdue" ? "was due" : "due"} ${fmtDate(t.next_due_at)} (${relativeDays(t.next_due_at, now)})`);
      if (t.next_due_mileage !== null) {
        const left = t.next_due_mileage - t.vehicle.mileage;
        parts.push(left > 0 ? `${fmtNum(left)} ${unit} to go` : `${fmtNum(-left)} ${unit} past due`);
      }
      add(t.user_id, {
        kind: status === "overdue" ? "task-overdue" : "task-due",
        title: `${t.name} · ${vehicleName(t.vehicle)} ${status === "overdue" ? "is overdue" : "is due soon"}`,
        body: parts.join(" · "),
        link: `/vehicles/${t.vehicle_id}`,
      });
      taskIds.push(t.id);
    }
    if (!tasks || tasks.length < PAGE) break;
  }

  // Documents
  const docIds: string[] = [];
  for (let from = 0; ; from += PAGE) {
    const { data: docs, error } = await db
      .from("documents")
      .select("*, vehicle:vehicles(*)")
      .not("expires_at", "is", null)
      .or(`last_notified_at.is.null,last_notified_at.lt.${cutoff}`)
      .order("id")
      .range(from, from + PAGE - 1);
    if (error) return json({ error: error.message }, 500);
    for (const d of docs ?? []) {
      const status = documentStatus(d, now);
      if (status !== "expired" && status !== "expiring") continue;
      const owner = d.vehicle ? ` (${vehicleName(d.vehicle)})` : "";
      add(d.user_id, {
        kind: status === "expired" ? "doc-expired" : "doc-expiring",
        title: `${d.title}${owner} ${status === "expired" ? "has expired" : "expires soon"}`,
        body: `${DOC_TYPES[d.type] ?? "Document"} · ${status === "expired" ? "expired" : "expires"} ${fmtDate(d.expires_at)} (${relativeDays(d.expires_at, now)})`,
        link: `/documents/${d.id}`,
      });
      docIds.push(d.id);
    }
    if (!docs || docs.length < PAGE) break;
  }

  // Deliver
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("EMAIL_FROM") || "AUTOX <onboarding@resend.dev>";
  const appUrl = (Deno.env.get("APP_URL") || "").replace(/\/$/, "");
  let emails = 0;
  for (const [uid, items] of perUser) {
    await db.from("notifications").insert(items.map((i) => ({ user_id: uid, ...i })));
    const { data: p } = await db.from("profiles").select("name, email, email_reminders").eq("id", uid).single();
    if (!resendKey || !p?.email || !p.email_reminders) continue;
    const urgent = items.filter((i) => i.kind === "task-overdue" || i.kind === "doc-expired").length;
    const subject = items.length === 1 ? items[0].title : `${items.length} things need attention${urgent ? ` (${urgent} overdue)` : ""}`;
    const rows = items
      .map((i) => `<tr><td style="padding:12px 16px;border-bottom:1px solid #EADFC8"><div style="font-weight:600;color:#3B2618">${escapeHtml(i.title)}</div><div style="color:#7A5C43;font-size:14px;margin-top:2px">${escapeHtml(i.body)}</div></td></tr>`)
      .join("");
    const html = `<!doctype html><html><body style="margin:0;background:#FBF6EC;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="padding:32px 12px"><tr><td align="center">
<table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;background:#FFFDF7;border:1px solid #EADFC8;border-radius:16px;overflow:hidden">
<tr><td style="background:#2B1D14;padding:20px 24px;color:#F3D98B;font-weight:800;font-size:20px;letter-spacing:1px">AUTOX</td></tr>
<tr><td style="padding:28px 24px 8px"><h1 style="margin:0 0 8px;font-size:22px;color:#2B1D14">Hi ${escapeHtml((p.name || "there").split(" ")[0])}, your car needs attention</h1>
<p style="margin:0;color:#5E4532;font-size:15px;line-height:1.5">Here's what's coming up or past due. Taking care of it now saves money later.</p></td></tr>
<tr><td style="padding:16px 24px 0"><table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #EADFC8;border-radius:12px">${rows}</table></td></tr>
<tr><td style="padding:24px">${appUrl ? `<a href="${appUrl}" style="background:#5B3A29;color:#FFF7E3;padding:12px 22px;border-radius:10px;text-decoration:none;font-weight:600;display:inline-block">Open AUTOX</a>` : ""}</td></tr>
</table><p style="color:#9C8269;font-size:12px;margin-top:16px">You're receiving this because email reminders are on in your AUTOX settings.</p></td></tr></table></body></html>`;
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: p.email,
        subject: `AUTOX: ${subject}`,
        html,
        text: items.map((i) => `• ${i.title}: ${i.body}`).join("\n") + (appUrl ? `\n\nOpen AUTOX: ${appUrl}` : ""),
      }),
    });
    if (res.ok) emails++;
    else console.error("email failed", res.status, await res.text());
  }

  const stamp = now.toISOString();
  for (let i = 0; i < taskIds.length; i += 200) {
    await db.from("maintenance_tasks").update({ last_notified_at: stamp }).in("id", taskIds.slice(i, i + 200));
  }
  for (let i = 0; i < docIds.length; i += 200) {
    await db.from("documents").update({ last_notified_at: stamp }).in("id", docIds.slice(i, i + 200));
  }

  const result = { users: perUser.size, tasks: taskIds.length, documents: docIds.length, emails };
  console.log("reminders", result);
  return json({ ok: true, ...result });
});
