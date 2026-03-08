package handlers

import (
	"encoding/json"
	"net/http"
	"os"

	"github.com/hugosleao/platform-api/internal/argocd"
	"github.com/hugosleao/platform-api/internal/audit"
	"github.com/hugosleao/platform-api/internal/github"
)

type ArgoCDHandler struct {
	gh    *github.Client
	audit *audit.Logger
}

func NewArgoCDHandler(gh *github.Client, audit *audit.Logger) *ArgoCDHandler {
	return &ArgoCDHandler{gh: gh, audit: audit}
}

func (h *ArgoCDHandler) CreateApp(w http.ResponseWriter, r *http.Request) {
	var req argocd.AppRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "payload inválido")
		return
	}
	if req.Name == "" || req.RepoURL == "" {
		writeError(w, http.StatusBadRequest, "name e repo_url são obrigatórios")
		return
	}

	gitopsRepo := req.GitopsRepo
	if gitopsRepo == "" {
		gitopsRepo = os.Getenv("GITOPS_REPO")
	}
	if gitopsRepo == "" {
		writeError(w, http.StatusBadRequest, "gitops_repo é obrigatório (ou configure GITOPS_REPO)")
		return
	}

	// Gera Applications para dev (develop), hml (release/*) e prd (master)
	// feature/* e fix/* não recebem Application — não são deployadas
	apps := argocd.GenerateManifests(req)
	for _, app := range apps {
		if err := h.gh.CommitFile(r.Context(), github.CommitFileRequest{
			Repo:    gitopsRepo,
			Path:    app.GitPath,
			Content: app.Content,
			Message: "feat: register argocd app " + app.Name,
		}); err != nil {
			h.audit.Record(r.Context(), "argocd.create_app", app.Name, "error", err.Error())
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		h.audit.Record(r.Context(), "argocd.create_app", app.Name, "success", app.GitPath)
	}

	result := map[string]any{
		"name":   req.Name,
		"apps":   []string{req.Name + "-dev", req.Name + "-hml", req.Name + "-prd"},
		"status": "committed",
		"note":   "deploy: develop→dev | release/*→hml | master→prd | feature/* e fix/* = CI only",
	}
	writeJSON(w, http.StatusCreated, result)
}
