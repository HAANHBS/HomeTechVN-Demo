const JSON_HEADERS = { "content-type": "application/json" };

function required(env, name) {
  const value = env[name];
  if (!value) throw new Error(`Missing Worker secret/config: ${name}`);
  return value;
}

async function supabaseRpc(env, fn, args = {}) {
  const url = `${required(env, "SUPABASE_URL")}/rest/v1/rpc/${fn}`;
  const key = required(env, "SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetch(url, {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      apikey: key,
      authorization: `Bearer ${key}`,
    },
    body: JSON.stringify(args),
  });

  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (!response.ok) {
    const error = new Error(`Supabase RPC ${fn} failed: HTTP ${response.status}`);
    error.code = `SUPABASE_${response.status}`;
    error.data = data;
    throw error;
  }
  return data;
}

function redactMeta(value) {
  if (Array.isArray(value)) return value.map(redactMeta);
  if (!value || typeof value !== "object") return value;

  const result = {};
  for (const [key, child] of Object.entries(value)) {
    if (/token|secret|password|passphrase|authorization|api[_-]?key|apikey|bearer/i.test(key)) {
      result[key] = "[REDACTED]";
    } else {
      result[key] = redactMeta(child);
    }
  }
  return result;
}

function safeMeta(value) {
  if (!value || typeof value !== "object") return {};
  return redactMeta(value);
}

function textFor(notification) {
  const code = notification.notification_code || "NTF";
  const subject = notification.subject || "HomeTechVN";
  const body = notification.body || "";
  return `[${code}] ${subject}\n${body}`;
}

async function sendTelegram(env, notification) {
  const token = required(env, "TELEGRAM_BOT_TOKEN");
  const chatId = notification.recipient_address;
  if (!chatId) throw new Error("Telegram notification missing chat_id");
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const body = {
    chat_id: chatId,
    text: textFor(notification),
    parse_mode: notification.payload?.parse_mode || "HTML",
  };
  const response = await fetch(url, { method: "POST", headers: JSON_HEADERS, body: JSON.stringify(body) });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data?.ok === false) {
    const error = new Error(data?.description || `Telegram HTTP ${response.status}`);
    error.code = String(data?.error_code || response.status);
    error.meta = safeMeta(data);
    throw error;
  }
  return { externalId: String(data?.result?.message_id || ""), meta: safeMeta(data) };
}

async function sendEmail(env, notification) {
  const url = required(env, "EMAIL_SEND_URL");
  const apiKey = required(env, "EMAIL_API_KEY");
  const from = required(env, "EMAIL_FROM");
  const to = notification.recipient_address;
  if (!to) throw new Error("Email notification missing recipient");
  const body = {
    from,
    to,
    subject: notification.subject || "HomeTechVN",
    text: notification.body || "",
    html: `<p>${String(notification.body || "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll("\n", "<br>")}</p>`,
    metadata: {
      notification_code: notification.notification_code,
      reminder_id: notification.reminder_id,
    },
  };
  const response = await fetch(url, {
    method: "POST",
    headers: { ...JSON_HEADERS, authorization: `Bearer ${apiKey}` },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data?.message || `Email HTTP ${response.status}`);
    error.code = String(data?.code || response.status);
    error.meta = safeMeta(data);
    throw error;
  }
  return {
    externalId: String(data?.id || data?.message_id || ""),
    meta: safeMeta(data),
  };
}

function zaloHeaders(env) {
  const token = required(env, "ZALO_ACCESS_TOKEN");
  const headerName = env.ZALO_AUTH_HEADER || "access_token";
  const scheme = env.ZALO_AUTH_SCHEME || "";
  const headers = { ...JSON_HEADERS };
  headers[headerName] = scheme ? `${scheme} ${token}` : token;
  if (env.ZALO_DPOP_PROOF) headers.DPoP = env.ZALO_DPOP_PROOF;
  return headers;
}

async function sendZalo(env, notification) {
  const url = required(env, "ZALO_SEND_URL");
  const mode = notification.payload?.mode || (notification.provider === "ZALO_OA_UID" ? "OA_UID" : "ZBS_PHONE");
  const destination = notification.recipient_address;
  if (!destination) throw new Error("Zalo notification missing destination");

  let body;
  if (mode === "OA_UID") {
    body = {
      recipient: { user_id: destination },
      message: { text: notification.body || "" },
    };
  } else {
    if (!notification.template_key) throw new Error("ZBS notification missing template_key");
    body = {
      phone: destination,
      template_id: notification.template_key,
      template_data: notification.payload?.template_data || {},
      tracking_id: notification.notification_code,
    };
  }

  const response = await fetch(url, {
    method: "POST",
    headers: zaloHeaders(env),
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  const apiError = Number(data?.error ?? data?.error_code ?? 0);
  if (!response.ok || apiError !== 0) {
    const error = new Error(data?.message || data?.error_name || `Zalo HTTP ${response.status}`);
    error.code = String(data?.error ?? data?.error_code ?? response.status);
    error.meta = safeMeta(data);
    throw error;
  }
  return {
    externalId: String(data?.data?.message_id || data?.message_id || data?.tracking_id || ""),
    meta: safeMeta(data),
  };
}

async function sendByChannel(env, notification) {
  if (env.DRY_RUN === "true") {
    return { externalId: `dry-${notification.notification_code}`, meta: { dry_run: true, channel: notification.channel } };
  }
  if (notification.channel === "TELEGRAM") return sendTelegram(env, notification);
  if (notification.channel === "EMAIL") return sendEmail(env, notification);
  if (notification.channel === "ZALO") return sendZalo(env, notification);
  throw new Error(`Unsupported external channel: ${notification.channel}`);
}

async function dispatchChannel(env, channel) {
  const batchSize = Math.min(Math.max(Number(env.NOTIFICATION_BATCH_SIZE || 20), 1), 100);
  const claimed = await supabaseRpc(env, "notification_claim_batch", {
    p_channel: channel,
    p_limit: batchSize,
    p_now: new Date().toISOString(),
  });

  const rows = Array.isArray(claimed) ? claimed : [];
  const summary = { channel, claimed: rows.length, sent: 0, failed: 0 };

  for (const notification of rows) {
    try {
      const result = await sendByChannel(env, notification);
      await supabaseRpc(env, "notification_mark_sent", {
        p_notification_id: notification.id,
        p_external_message_id: result.externalId || null,
        p_response_meta: result.meta || {},
      });
      summary.sent += 1;
    } catch (err) {
      const code = err?.code ? String(err.code) : "PROVIDER_ERROR";
      const message = err instanceof Error ? err.message : String(err);
      await supabaseRpc(env, "notification_mark_failed", {
        p_notification_id: notification.id,
        p_error_code: code,
        p_error_message: message,
        p_response_meta: safeMeta(err?.meta || {}),
      });
      summary.failed += 1;
    }
  }

  return summary;
}

async function runPipeline(env) {
  const now = new Date().toISOString();
  const reminder = await supabaseRpc(env, "reminder_generate", { p_now: now });
  const prepared = await supabaseRpc(env, "notification_prepare", { p_now: now });
  const stale = await supabaseRpc(env, "notification_requeue_stale", { p_older_than_minutes: 10 });

  const results = [];
  for (const channel of ["TELEGRAM", "EMAIL", "ZALO"]) {
    results.push(await dispatchChannel(env, channel));
  }

  return { now, reminder, prepared, stale, dispatch: results };
}

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value, null, 2), {
    status,
    headers: { ...JSON_HEADERS, "cache-control": "no-store" },
  });
}

export default {
  async scheduled(_controller, env, ctx) {
    if (env.WORKER_CRON_ENABLED !== "true") {
      console.log("HomeTechVN notification cron skipped: WORKER_CRON_ENABLED is not true");
      return;
    }
    ctx.waitUntil(runPipeline(env).then(
      (result) => console.log("HomeTechVN notification cron:", JSON.stringify(result)),
      (error) => console.error("HomeTechVN notification cron failed:", error),
    ));
  },

  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return jsonResponse({ ok: true, service: "hometechvn-notification-worker" });
    }

    if (request.method === "POST" && url.pathname === "/run") {
      const expected = required(env, "WORKER_TRIGGER_KEY");
      if (request.headers.get("x-hometech-worker-key") !== expected) {
        return jsonResponse({ error: "unauthorized" }, 401);
      }
      try {
        return jsonResponse(await runPipeline(env));
      } catch (error) {
        return jsonResponse({
          error: error instanceof Error ? error.message : String(error),
          code: error?.code || "WORKER_ERROR",
        }, 500);
      }
    }

    return jsonResponse({ error: "not_found" }, 404);
  },
};
