// Shared Supabase client with Multi-Tab Session Isolation
// Loaded via <script> on every page.
const SUPABASE_URL = "https://flprhrbbllxfcdaornio.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZscHJocmJibGx4ZmNkYW9ybmlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMDk1MzcsImV4cCI6MjEwMTU4NTUzN30._dxfJ8h50eNEIq89m3467Qr4p8Mw5OuqllwkJzSyTDw";

// टॅबनुसार स्वतंत्र सत्र (Session) जतन करण्यासाठी sessionStorage वापरत आहोत,
// ज्यामुळे एकाच ब्राउझरच्या वेगवेगळ्या टॅबमध्ये स्वतंत्र खाती (उदा. दुकानदार व ग्राहक) एकाच वेळी चालवता येतील.
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: window.sessionStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});
