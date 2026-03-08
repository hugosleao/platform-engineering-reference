package handlers

import (
	"net/http"

	"github.com/hugosleao/platform-api/internal/audit"
)

type AuditHandler struct {
	audit *audit.Logger
}

func NewAuditHandler(audit *audit.Logger) *AuditHandler {
	return &AuditHandler{audit: audit}
}

func (h *AuditHandler) List(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, h.audit.List())
}
