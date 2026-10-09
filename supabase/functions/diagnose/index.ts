// AI Mechanic: streams Claude's diagnosis for a driver's message, photos and video frames.
import Anthropic from "npm:@anthropic-ai/sdk@0.132.1";
import { encodeBase64 } from "jsr:@std/encoding@1/base64";
import { adminClient, requestUser } from "../_shared/clients.ts";
import { corsHeaders, json } from "../_shared/cors.ts";
import { fmtDate, fmtNum, taskStatus } from "../_shared/format.ts";

const MODEL = Deno.env.get("AI_MODEL") || "claude-opus-5-5";
const DAILY_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") || 40);
const IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);

type Attachment = { path: string; kind: "image" | "video-frame"; name?: string };

const BASE_PROMPT = `You are the AUTOX AI Mechanic: a senior, ASE-certified-level automotive technician who helps everyday drivers understand and fix problems with their cars. You can see photos the driver sends, and still frames sampled from videos they record (you cannot hear audio from videos; if a sound matters, ask them to describe it).

How to respond:
- Lead with your best assessment in one or two plain sentences. Drivers are often stressed; be calm, clear and direct.
- Then use short sections with these headings when relevant: **What I see**, **Most likely causes** (ranked, with a rough likelihood), **How serious is it** (Safe to drive / Drive with caution / Stop driving), **What to do now**, **DIY or mechanic?**, **Rough cost** (give a range and say it varies by region and parts).
- Ask at most two targeted follow-up questions when the answer would change the diagnosis (e.g. when it happens, warning lights, smells, sounds, recent work).
- If the photo or frames are unclear, say exactly what to capture next (angle, lighting, what part, engine on/off).
- Use the vehicle details and service history below to sharpen your answer (e.g. an overdue oil change, mileage-related wear).
- Safety first: for brake failure, steering problems, fuel leaks, smoke or fire, overheating with steam, airbag lights after a crash, or anything that could hurt someone, clearly tell them to stop driving and get professional help. Never suggest bypassing safety systems.
- Be honest about uncertainty: you're diagnosing remotely and a hands-on inspection is the final word.
- Keep answers focused and skimmable. Use the driver's units and currency where you give numbers.
- Only help with vehicle-related questions. If asked about something unrelated, briefly steer back to the car.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const user = await requestUser(req);
  if (!user) return json({ error: "Please sign in again." }, 401);
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "The AI mechanic isn't configured yet (missing ANTHROPIC_API_KEY)." }, 503);

  let body: { chatId?: string; vehicleId?: string; message?: string; attachments?: Attachment[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request." }, 400);
  }
  const message = String(body.message ?? "").trim().slice(0, 8000);
  const attachments = (Array.isArray(body.attachments) ? body.attachments : [])
    .slice(0, 16)
    .filter((a) => a && typeof a.path === "string")
    .map((a) => ({ path: a.path, kind: a.kind === "video-frame" ? "video-frame" : "image", name: String(a.name ?? "").slice(0, 200) }) as Attachment);
  if (!message && attachments.length === 0) {
    return json({ error: "Describe the problem or attach a photo or video." }, 400);
  }
  if (attachments.some((a) => !a.path.startsWith(`${user.id}/`) || a.path.includes(".."))) {
    return json({ error: "Invalid attachment." }, 400);
  }

  const db = adminClient();

  const since = new Date(Date.now() - 86_400_000).toISOString();
  const { count } = await db
    .from("diagnosis_messages")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .eq("role", "user")
    .gte("created_at", since);
  if ((count ?? 0) >= DAILY_LIMIT) {
    return json({ error: `You've reached today's limit of ${DAILY_LIMIT} AI questions. It resets within 24 hours.` }, 429);
  }

  // Resolve or create the conversation.
  let chat: { id: string; vehicle_id: string | null } | null = null;
  if (body.chatId) {
    const { data } = await db
      .from("diagnosis_chats")
      .select("id, vehicle_id")
      .eq("id", body.chatId)
      .eq("user_id", user.id)
      .maybeSingle();
    if (!data) return json({ error: "Conversation not found." }, 404);
    chat = data;
  } else {
    let vehicleId: string | null = null;
    if (body.vehicleId) {
      const { data } = await db.from("vehicles").select("id").eq("id", body.vehicleId).eq("user_id", user.id).maybeSingle();
      vehicleId = data?.id ?? null;
    }
    const title =
      message.slice(0, 60).trim() ||
      (attachments.some((a) => a.kind === "video-frame") ? "Video diagnosis" : "Photo diagnosis");
    const { data, error } = await db
      .from("diagnosis_chats")
      .insert({ user_id: user.id, vehicle_id: vehicleId, title })
      .select("id, vehicle_id")
      .single();
    if (error) return json({ error: "Couldn't start the conversation." }, 500);
    chat = data;
  }
  const chatId = chat.id;

  await db.from("diagnosis_messages").insert({ chat_id: chatId, user_id: user.id, role: "user", content: message, attachments });

  // Context: profile, vehicle, due maintenance and service history.
  const { data: profile } = await db.from("profiles").select("name, distance_unit, currency").eq("id", user.id).single();
  const unit = profile?.distance_unit === "mi" ? "mi" : "km";
  let car = "The driver hasn't selected a vehicle for this conversation. If the make, model or year matters, ask.";
  if (chat.vehicle_id) {
    const [{ data: v }, { data: tasks }, { data: logs }] = await Promise.all([
      db.from("vehicles").select("*").eq("id", chat.vehicle_id).single(),
      db.from("maintenance_tasks").select("*").eq("vehicle_id", chat.vehicle_id),
      db.from("maintenance_logs").select("*").eq("vehicle_id", chat.vehicle_id).order("performed_at", { ascending: false }).limit(12),
    ]);
    if (v) {
      const due = (tasks ?? [])
        .map((t) => ({ t, s: taskStatus(t, v.mileage) }))
        .filter((x) => x.s === "overdue" || x.s === "due-soon")
        .map((x) =>
          `- ${x.t.name}: ${x.s === "overdue" ? "OVERDUE" : "due soon"}${x.t.next_due_at ? ` (date ${fmtDate(x.t.next_due_at)})` : ""}${x.t.next_due_mileage !== null ? ` (at ${fmtNum(x.t.next_due_mileage)} ${unit})` : ""}`
        );
      const history = (logs ?? []).map(
        (l) => `- ${fmtDate(l.performed_at)}: ${l.title}${l.mileage !== null ? ` at ${fmtNum(l.mileage)} ${unit}` : ""}`,
      );
      car = [
        `Vehicle: ${v.year} ${v.make} ${v.model}${v.trim ? ` ${v.trim}` : ""}${v.fuel_type ? `, ${v.fuel_type}` : ""}`,
        `Odometer: ${fmtNum(v.mileage)} ${unit} (updated ${fmtDate(v.mileage_updated_at)})`,
        due.length ? `Maintenance due or overdue:\n${due.join("\n")}` : "No maintenance currently flagged as due.",
        history.length ? `Recent service history:\n${history.join("\n")}` : "No service history recorded in AUTOX.",
      ].join("\n");
    }
  }
  const system = `${BASE_PROMPT}

<driver>
Name: ${profile?.name || "Driver"}
Preferred distance unit: ${unit}
Currency: ${profile?.currency || "USD"}
</driver>

<vehicle_context>
${car}
</vehicle_context>`;

  // Conversation: full text history, images only for the newest user turn.
  const { data: history } = await db
    .from("diagnosis_messages")
    .select("role, content, attachments")
    .eq("chat_id", chatId)
    .order("created_at", { ascending: true })
    .limit(40);
  const messages: Anthropic.Beta.BetaMessageParam[] = [];
  const rows = history ?? [];
  for (let i = 0; i < rows.length; i++) {
    const m = rows[i];
    if (m.role === "assistant") {
      if (m.content.trim()) messages.push({ role: "assistant", content: m.content });
      continue;
    }
    const atts = (m.attachments as Attachment[]) ?? [];
    const content: Anthropic.Beta.BetaContentBlockParam[] = [];
    if (i === rows.length - 1 && atts.length) {
      for (const a of atts) {
        const { data: file } = await db.storage.from("files").download(a.path);
        if (!file || !IMAGE_TYPES.has(file.type)) continue;
        content.push({
          type: "image",
          source: {
            type: "base64",
            media_type: file.type as "image/jpeg" | "image/png" | "image/webp" | "image/gif",
            data: encodeBase64(new Uint8Array(await file.arrayBuffer())),
          },
        });
      }
      const frames = atts.filter((a) => a.kind === "video-frame").length;
      if (frames) content.push({ type: "text", text: `(The ${frames} images above are frames sampled in order from a video the driver recorded.)` });
    } else if (atts.length) {
      content.push({ type: "text", text: `[Earlier the driver attached ${atts.length} image(s); your previous reply describes them.]` });
    }
    content.push({ type: "text", text: m.content || "Please look at this and tell me what's wrong." });
    const prev = messages[messages.length - 1];
    if (prev && prev.role === "user" && Array.isArray(prev.content)) prev.content.push(...content);
    else messages.push({ role: "user", content });
  }

  const anthropic = new Anthropic({ apiKey });
  const encoder = new TextEncoder();
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      let full = "";
      try {
        const s = anthropic.beta.messages.stream({
          model: MODEL,
          max_tokens: 16000,
          system,
          messages,
          output_config: { effort: "medium" },
          betas: ["server-side-fallback-2026-07-01"],
          fallbacks: "default",
        });
        s.on("text", (delta) => {
          full += delta;
          controller.enqueue(encoder.encode(delta));
        });
        const final = await s.finalMessage();
        if (final.stop_reason === "refusal" && !full.trim()) {
          full = "Sorry, I can't help with that request. If this is about your car, try rephrasing or describing the symptoms.";
          controller.enqueue(encoder.encode(full));
        }
      } catch (err) {
        console.error("AI error", err);
        const note = full
          ? "\n\n_(The response was cut off. Please try again.)_"
          : "Sorry, the AI mechanic is unavailable right now. Please try again in a moment.";
        full += note;
        controller.enqueue(encoder.encode(note));
      } finally {
        if (full.trim()) {
          await db.from("diagnosis_messages").insert({ chat_id: chatId, user_id: user.id, role: "assistant", content: full });
        }
        await db.from("diagnosis_chats").update({ updated_at: new Date().toISOString() }).eq("id", chatId);
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store", "x-chat-id": chatId },
  });
});
