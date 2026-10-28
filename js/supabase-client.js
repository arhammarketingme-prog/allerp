// Shared Supabase client with LocalStorage Persistence
const SUPABASE_URL = "https://flprhrbbllxfcdaornio.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZscHJocmJibGx4ZmNkYW9ybmlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMDk1MzcsImV4cCI6MjEwMTU4NTUzN30._dxfJ8h50eNEIq89m3467Qr4p8Mw5OuqllwkJzSyTDw";

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: window.localStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});
