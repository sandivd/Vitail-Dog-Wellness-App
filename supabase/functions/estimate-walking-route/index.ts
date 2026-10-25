// import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// const corsHeaders = {
//   "Access-Control-Allow-Headers": "authorization, apikey, content-type",
//   "Access-Control-Allow-Methods": "POST, OPTIONS",
//   "Access-Control-Allow-Origin": "*",
//   "Content-Type": "application/json",
// };

// function coordinate(value: unknown): { latitude: number; longitude: number } | null {
//   if (typeof value !== "object" || value === null) return null;
//   const point = value as Record<string, unknown>;
//   const latitude = point.latitude;
//   const longitude = point.longitude;
//   if (
//     typeof latitude !== "number" ||
//     typeof longitude !== "number" ||
//     !Number.isFinite(latitude) ||
//     !Number.isFinite(longitude) ||
//     Math.abs(latitude) > 90 ||
//     Math.abs(longitude) > 180
//   ) {
//     return null;
//   }
//   return { latitude, longitude };
// }

// Deno.serve(async (request: Request) => {
//   if (request.method === "OPTIONS") {
//     return new Response("ok", { headers: corsHeaders });
//   }
//   if (request.method !== "POST") {
//     return Response.json(
//       { error: "Method not allowed." },
//       { status: 405, headers: corsHeaders },
//     );
//   }

//   try {
//     const authorization = request.headers.get("Authorization");
//     const token = authorization?.replace(/^Bearer\s+/i, "");
//     const supabaseUrl = Deno.env.get("SUPABASE_URL");
//     const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
//     const googleRoutesApiKey = Deno.env.get("GOOGLE_ROUTES_API_KEY");
//     if (!token || !supabaseUrl || !supabaseAnonKey) {
//       return Response.json(
//         { error: "Authentication is required." },
//         { status: 401, headers: corsHeaders },
//       );
//     }

//     const supabase = createClient(supabaseUrl, supabaseAnonKey);
//     const { data: { user }, error: authError } =
//       await supabase.auth.getUser(token);
//     if (authError || !user) {
//       return Response.json(
//         { error: "Authentication is required." },
//         { status: 401, headers: corsHeaders },
//       );
//     }

//     if (!googleRoutesApiKey) {
//       console.error("GOOGLE_ROUTES_API_KEY is not configured.");
//       return Response.json(
//         { error: "Walking route service is not configured." },
//         { status: 503, headers: corsHeaders },
//       );
//     }

//     const body = await request.json();
//     const origin = coordinate(body?.origin);
//     const destination = coordinate(body?.destination);
//     if (!origin || !destination) {
//       return Response.json(
//         { error: "Valid origin and destination coordinates are required." },
//         { status: 400, headers: corsHeaders },
//       );
//     }

//     const routeResponse = await fetch(
//       "https://routes.googleapis.com/directions/v2:computeRoutes",
//       {
//         method: "POST",
//         headers: {
//           "Content-Type": "application/json",
//           "X-Goog-Api-Key": googleRoutesApiKey,
//           "X-Goog-FieldMask": "routes.distanceMeters",
//         },
//         body: JSON.stringify({
//           origin: {
//             location: {
//               latLng: {
//                 latitude: origin.latitude,
//                 longitude: origin.longitude,
//               },
//             },
//           },
//           destination: {
//             location: {
//               latLng: {
//                 latitude: destination.latitude,
//                 longitude: destination.longitude,
//               },
//             },
//           },
//           travelMode: "WALK",
//           computeAlternativeRoutes: false,
//         }),
//       },
//     );
//     if (!routeResponse.ok) {
//       console.error(
//         `Google Routes API returned HTTP ${routeResponse.status}.`,
//       );
//       return Response.json(
//         { error: "Walking route could not be estimated." },
//         { status: 502, headers: corsHeaders },
//       );
//     }

//     const result = await routeResponse.json();
//     const distanceMeters = result?.routes?.[0]?.distanceMeters;
//     if (
//       typeof distanceMeters !== "number" ||
//       !Number.isFinite(distanceMeters) ||
//       distanceMeters < 0
//     ) {
//       return Response.json(
//         { error: "No walking route is available for these locations." },
//         { status: 404, headers: corsHeaders },
//       );
//     }

//     return Response.json({ distanceMeters }, { headers: corsHeaders });
//   } catch (error) {
//     console.error("Walking route estimate failed:", error);
//     return Response.json(
//       { error: "Walking route could not be estimated." },
//       { status: 500, headers: corsHeaders },
//     );
//   }
// });
