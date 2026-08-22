import { createClient } from "@supabase/supabase-js";
import { ENV } from "./env.js";

export const isSupabaseConfigured = Boolean(ENV.supabaseUrl && ENV.supabaseAnonKey);

export const supabase = isSupabaseConfigured ? createClient(ENV.supabaseUrl, ENV.supabaseAnonKey) : null;
