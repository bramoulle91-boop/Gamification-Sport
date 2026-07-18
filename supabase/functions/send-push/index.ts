// GymQuest — envoie une vraie notification push (Web Push) quand un
// événement pertinent se produit : nouveau message de tchat de salle,
// nouveau défi reçu, ou défi terminé.
//
// Déclenchée par des Database Webhooks Supabase (Database → Webhooks),
// une par table écoutée : gym_messages (INSERT) et duels (INSERT + UPDATE).
// Le payload envoyé par un Database Webhook a la forme :
//   { type: "INSERT" | "UPDATE" | "DELETE", table: string,
//     record: {...}, old_record: {...} | null }
//
// Variables d'environnement requises (Supabase → Edge Functions → Secrets) :
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY  (générées une fois, voir README)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (déjà disponibles par défaut
//   dans l'environnement d'une Edge Function Supabase)

import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

webpush.setVapidDetails("mailto:contact@gymquest.app", VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function notifyUser(userId: string, title: string, body: string, url: string) {
  const { data: subs } = await supabase
    .from("push_subscriptions")
    .select("endpoint, p256dh, auth_key")
    .eq("user_id", userId);

  for (const sub of subs ?? []) {
    const subscription = {
      endpoint: sub.endpoint,
      keys: { p256dh: sub.p256dh, auth: sub.auth_key },
    };
    try {
      await webpush.sendNotification(subscription, JSON.stringify({ title, body, url }));
    } catch (err) {
      // Abonnement expiré ou révoqué côté navigateur : on le retire pour ne
      // pas réessayer indéfiniment sur un endpoint mort.
      const statusCode = (err as { statusCode?: number }).statusCode;
      if (statusCode === 404 || statusCode === 410) {
        await supabase.from("push_subscriptions").delete().eq("endpoint", sub.endpoint);
      }
    }
  }
}

Deno.serve(async (req) => {
  let payload: {
    type: string;
    table: string;
    record: Record<string, unknown>;
    old_record?: Record<string, unknown> | null;
  };
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Payload JSON invalide" }), { status: 400 });
  }

  const { type, table, record, old_record } = payload;

  try {
    if (table === "gym_messages" && type === "INSERT") {
      const gymId = record.gym_id as string;
      const senderId = record.user_id as string;
      const pseudo = record.pseudo as string;
      const message = record.message as string;

      const { data: gym } = await supabase.from("gyms").select("name").eq("id", gymId).single();
      const { data: recipients } = await supabase
        .from("users")
        .select("id")
        .eq("home_gym_id", gymId)
        .neq("id", senderId);

      for (const recipient of recipients ?? []) {
        await notifyUser(
          recipient.id as string,
          `💬 ${gym?.name ?? "Ta salle"}`,
          `${pseudo}: ${message}`,
          `/#/gyms/${gymId}/chat`,
        );
      }
    } else if (table === "duels" && type === "INSERT" && record.status === "PENDING") {
      const { data: challenger } = await supabase
        .from("users")
        .select("pseudo")
        .eq("id", record.challenger_id as string)
        .single();
      await notifyUser(
        record.opponent_id as string,
        "⚡ Nouveau défi",
        `${challenger?.pseudo ?? "Un ami"} te défie sur ${record.exercise_name}`,
        "/#/duels",
      );
    } else if (
      table === "duels" &&
      type === "UPDATE" &&
      record.status === "FINISHED" &&
      old_record?.status !== "FINISHED"
    ) {
      const [{ data: challenger }, { data: opponent }] = await Promise.all([
        supabase.from("users").select("pseudo").eq("id", record.challenger_id as string).single(),
        supabase.from("users").select("pseudo").eq("id", record.opponent_id as string).single(),
      ]);
      const winnerName =
        record.winner_id === record.challenger_id
          ? challenger?.pseudo
          : record.winner_id === record.opponent_id
            ? opponent?.pseudo
            : null;
      const message = winnerName
        ? `${winnerName} remporte le défi sur ${record.exercise_name} !`
        : `Égalité sur ${record.exercise_name} !`;
      await notifyUser(record.challenger_id as string, "🏁 Défi terminé", message, "/#/duels");
      await notifyUser(record.opponent_id as string, "🏁 Défi terminé", message, "/#/duels");
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
