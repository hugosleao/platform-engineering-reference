package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/hugosleao/platform-api/internal/audit"
	"github.com/hugosleao/platform-api/internal/crossplane"
	"github.com/hugosleao/platform-api/internal/github"
)

type CrossplaneHandler struct {
	gh    *github.Client
	audit *audit.Logger
}

func NewCrossplaneHandler(gh *github.Client, audit *audit.Logger) *CrossplaneHandler {
	return &CrossplaneHandler{gh: gh, audit: audit}
}

func (h *CrossplaneHandler) ApplyClaim(w http.ResponseWriter, r *http.Request) {
	var req crossplane.ClaimRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "payload inválido")
		return
	}
	if req.Sigla == "" || req.Name == "" || req.Kind == "" {
		writeError(w, http.StatusBadRequest, "sigla, name e kind são obrigatórios")
		return
	}

	ctx := r.Context()

	// Deriva o repo no padrão: {sigla}_iac-infra_cp-aws-{tipo}
	repoName := crossplane.RepoName(req.Sigla, req.Kind)
	repoDesc := crossplane.RepoDescription(req.Sigla, req.Kind)

	repoResult, err := h.gh.EnsureRepo(ctx, repoName, repoDesc)
	if err != nil {
		h.audit.Record(ctx, "crossplane.ensure_repo", repoName, "error", err.Error())
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("erro ao garantir repo %s: %s", repoName, err))
		return
	}

	content, gitPath, err := crossplane.GenerateManifest(req)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	// ArgoCD ApplicationSet já assiste repos *_iac-infra_cp-aws-* automaticamente
	if err := h.gh.CommitFile(ctx, github.CommitFileRequest{
		Repo:    repoName,
		Path:    gitPath,
		Content: content,
		Message: fmt.Sprintf("feat: add %s %s", req.Kind, req.Name),
	}); err != nil {
		h.audit.Record(ctx, "crossplane.apply_claim", req.Name, "error", err.Error())
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	result := crossplane.ClaimResult{
		Name:    req.Name,
		Kind:    req.Kind,
		Repo:    repoName,
		GitPath: gitPath,
		RepoURL: repoResult.HTMLURL,
		Status:  "committed",
	}
	h.audit.Record(ctx, "crossplane.apply_claim", req.Name, "success",
		fmt.Sprintf("repo=%s path=%s", repoName, gitPath))
	writeJSON(w, http.StatusCreated, result)
}
