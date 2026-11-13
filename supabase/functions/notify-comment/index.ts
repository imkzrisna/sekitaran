import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

const serviceAccountValue = Deno.env.get("FCM_SERVICE_ACCOUNT");
const webhookSecret = Deno.env.get("WEBHOOK_SECRET");

if (!serviceAccountValue || !webhookSecret) {
  throw new Error("Required Edge Function secrets are missing.");
}

const sa = JSON.parse(serviceAccountValue);

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function accessToken(): Promise<string> {
  const key = await importPKCS8(sa.private_key, "RS256");

  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const result = await response.json();

  if (!response.ok || !result.access_token) {
    throw new Error("Failed to obtain Firebase access token.");
  }

  return result.access_token;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }

    if (req.headers.get("x-webhook-secret") !== webhookSecret) {
      return jsonResponse({ error: "Forbidden" }, 403);
    }

    const payload = await req.json();

    if (
      payload.type !== "INSERT" ||
      payload.table !== "comments" ||
      payload.schema !== "public"
    ) {
      return jsonResponse({ status: "ignored" });
    }

    const comment = payload.record;

    if (!comment?.id || !comment?.business_id || !comment?.author_id) {
      return jsonResponse({ error: "Invalid comment payload" }, 400);
    }

    // 1. Ambil informasi toko.
    const { data: business, error: businessError } = await admin
      .from("businesses")
      .select("id, name, owner_id")
      .eq("id", comment.business_id)
      .maybeSingle();

    if (businessError) {
      throw new Error("Failed to retrieve business.");
    }

    if (!business) {
      return jsonResponse({ status: "business_not_found" });
    }

    // 2. Ambil username pengomentar.
    // 2. Ambil username pengomentar.
    const { data: author, error: authorError } = await admin
      .from("profiles")
      .select("id, username")
      .eq("id", comment.author_id)
      .maybeSingle();

    if (authorError) {
      console.error("AUTHOR QUERY FAILED:", {
        message: authorError.message,
        code: authorError.code,
        details: authorError.details,
        hint: authorError.hint,
        authorId: comment.author_id,
      });

      throw new Error("Failed to retrieve comment author.");
    }

    console.log("AUTHOR QUERY RESULT:", {
      found: !!author,
      authorId: author?.id,
      usernameFound: !!author?.username,
    });

    if (!author) {
      return jsonResponse({ status: "author_not_found" });
    }

    const username = String(author.username ?? "").trim();

    if (!username) {
      return jsonResponse({ status: "author_username_missing" });
    }

    // 3. Ambil perangkat milik Business Owner.
    const { data: devices, error: devicesError } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", business.owner_id);

    if (devicesError) {
      throw new Error("Failed to retrieve owner devices.");
    }

    if (!devices?.length) {
      return jsonResponse({ status: "no_registered_devices" });
    }

    // 4. Susun notifikasi.
    const title = String(business.name ?? "Toko Sekitaran");
    const body = `Komentar baru: ${String(comment.body ?? "").trim()}`;

    // 5. Buat Firebase OAuth access token.
    const firebaseAccessToken = await accessToken();

    const firebaseUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let successCount = 0;
    let failureCount = 0;

    // 6. Kirim notifikasi ke seluruh perangkat pemilik toko.
    for (const device of devices) {
      const token = device.token;

      if (!token) {
        failureCount++;
        continue;
      }

      const response = await fetch(firebaseUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${firebaseAccessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            fid: token,
            notification: {
              title,
              body,
            },
            data: {
              type: "new_comment",
              business_id: String(comment.business_id),
              comment_id: String(comment.id),
            },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "comments",
                sound: "default",
              },
            },
          },
        }),
      });

      if (response.ok) {
        successCount++;
        continue;
      }

      const errorResult = await response.json().catch(() => ({}));
      const errorCode = errorResult?.error?.details?.find(
        (item: { errorCode?: string }) => item.errorCode,
      )?.errorCode;

      console.error("FCM delivery failed:", {
        status: response.status,
        errorCode,
      });

      failureCount++;

      // Hapus token hanya jika Firebase menyatakan token tidak terdaftar.
      if (errorCode === "UNREGISTERED") {
        const { error: deleteError } = await admin
          .from("device_tokens")
          .delete()
          .eq("token", token)
          .eq("user_id", business.owner_id);

        if (deleteError) {
          console.error("Failed to remove invalid device registration.");
        }
      }
    }

    console.log("Comment notification result:", {
      businessId: comment.business_id,
      successCount,
      failureCount,
    });

    return jsonResponse({
      status: failureCount === 0 ? "success" : "partial_success",
      successCount,
      failureCount,
    });
  } catch (error) {
    console.error("NOTIFY COMMENT ERROR:", error);

    if (error instanceof Error) {
      console.error("ERROR MESSAGE:", error.message);
      console.error("ERROR STACK:", error.stack);
    }

    return new Response(
      JSON.stringify({
        error: "Internal notification processing error",
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  }
});
