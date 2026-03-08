package middleware

import (
	"net/http"
	"os"
	"strings"

	"github.com/hugosleao/platform-api/internal/audit"
)

func BearerAuth(next http.Handler) http.Handler {
	token := os.Getenv("PLATFORM_API_TOKEN")
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if token == "" {
			next.ServeHTTP(w, r)
			return
		}
		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "Bearer ") || strings.TrimPrefix(auth, "Bearer ") != token {
			http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
			return
		}
		actor := r.Header.Get("X-Actor")
		if actor == "" {
			actor = "anonymous"
		}
		ctx := audit.WithActor(r.Context(), actor)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
