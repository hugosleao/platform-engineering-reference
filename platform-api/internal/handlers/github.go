package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/hugosleao/platform-api/internal/audit"
	"github.com/hugosleao/platform-api/internal/github"
)

type GitHubHandler struct {
	client *github.Client
	audit  *audit.Logger
}

func NewGitHubHandler(client *github.Client, audit *audit.Logger) *GitHubHandler {
	return &GitHubHandler{client: client, audit: audit}
}

func (h *GitHubHandler) CreateRepo(w http.ResponseWriter, r *http.Request) {
	var req github.CreateRepoRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "payload inválido")
		return
	}
	if req.Name == "" {
		writeError(w, http.StatusBadRequest, "name é obrigatório")
		return
	}

	result, err := h.client.EnsureRepo(r.Context(), req.Name, req.Description)
	if err != nil {
		h.audit.Record(r.Context(), "github.create_repo", req.Name, "error", err.Error())
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.audit.Record(r.Context(), "github.create_repo", req.Name, "success", result.HTMLURL)
	writeJSON(w, http.StatusCreated, result)
}

func (h *GitHubHandler) CreateTeam(w http.ResponseWriter, r *http.Request) {
	var req github.CreateTeamRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "payload inválido")
		return
	}
	if req.Name == "" || req.RepoName == "" {
		writeError(w, http.StatusBadRequest, "name e repo_name são obrigatórios")
		return
	}

	result, err := h.client.CreateTeam(r.Context(), req)
	if err != nil {
		h.audit.Record(r.Context(), "github.create_team", req.Name, "error", err.Error())
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.audit.Record(r.Context(), "github.create_team", req.Name, "success", result.Slug)
	writeJSON(w, http.StatusCreated, result)
}
