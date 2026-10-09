// Permanently deletes the signed-in user's files and account (all rows cascade).
import { adminClient, requestUser } from "../_shared/clients.ts";
import { corsHeaders, json } from "../_shared/cors.ts";

async function listAll(db: ReturnType<typeof adminClient>, prefix: string): Promise<string[]> {
  const out: string[] = [];
  const { data } = await db.storage.from("files").list(prefix, { limit: 1000 });
  for (const item of data ?? []) {
    const path = `${prefix}/${item.name}`;
    if (item.id) out.push(path);
    else out.push(...(await listAll(db, path))); // folder
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const user = await requestUser(req);
  if (!user) return json({ error: "Please sign in again." }, 401);
  const db = adminClient();
  const paths = await listAll(db, user.id);
  for (let i = 0; i < paths.length; i += 100) {
    await db.storage.from("files").remove(paths.slice(i, i + 100));
  }
  const { error } = await db.auth.admin.deleteUser(user.id);
  if (error) return json({ error: "Couldn't delete the account. Please try again." }, 500);
  return json({ ok: true });
});
