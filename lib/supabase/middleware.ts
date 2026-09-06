import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import { env } from "@/lib/env";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });

  const supabase = createServerClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({
            request,
          });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isPublicRoute =
    request.nextUrl.pathname.startsWith("/login") ||
    request.nextUrl.pathname.startsWith("/auth") ||
    request.nextUrl.pathname.startsWith("/s/") ||
    request.nextUrl.pathname.startsWith("/api/link-preview") ||
    request.nextUrl.pathname.startsWith("/manifest.json") ||
    request.nextUrl.pathname.startsWith("/icons");

  if (!user && !isPublicRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    // Preserve current URL in returnTo query param if not root
    if (request.nextUrl.pathname !== "/") {
      url.searchParams.set("returnTo", request.nextUrl.pathname + request.nextUrl.search);
    }
    return NextResponse.redirect(url);
  }

  // If user is logged in and visits /login, redirect to /
  if (user && request.nextUrl.pathname.startsWith("/login")) {
    const returnTo = request.nextUrl.searchParams.get("returnTo") || "/";
    const url = request.nextUrl.clone();
    url.pathname = returnTo.startsWith("/") ? returnTo : "/";
    url.searchParams.delete("returnTo");
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
