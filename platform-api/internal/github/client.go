package github

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/bradleyfalzon/ghinstallation/v2"
	gogithub "github.com/google/go-github/v60/github"
)

type Client struct {
	gh  *gogithub.Client
	org string
}

func NewClient() (*Client, error) {
	appIDStr := os.Getenv("GITHUB_APP_ID")
	installIDStr := os.Getenv("GITHUB_INSTALLATION_ID")
	privateKeyPath := os.Getenv("GITHUB_APP_PRIVATE_KEY_PATH")

	if appIDStr == "" || installIDStr == "" || privateKeyPath == "" {
		return nil, fmt.Errorf("envs obrigatórias ausentes: GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY_PATH")
	}

	appID, err := strconv.ParseInt(appIDStr, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("GITHUB_APP_ID inválido: %w", err)
	}
	installID, err := strconv.ParseInt(installIDStr, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("GITHUB_INSTALLATION_ID inválido: %w", err)
	}

	itr, err := ghinstallation.NewKeyFromFile(http.DefaultTransport, appID, installID, privateKeyPath)
	if err != nil {
		return nil, fmt.Errorf("erro ao carregar private key: %w", err)
	}

	return &Client{
		gh:  gogithub.NewClient(&http.Client{Transport: itr}),
		org: os.Getenv("GITHUB_ORG"),
	}, nil
}

type CreateRepoRequest struct {
	Name        string
	Description string
	Private     bool
}

type RepoResult struct {
	Name     string `json:"name"`
	FullName string `json:"full_name"`
	HTMLURL  string `json:"html_url"`
	CloneURL string `json:"clone_url"`
}

// EnsureRepo cria o repo se não existe. Idempotente.
func (c *Client) EnsureRepo(ctx context.Context, name, description string) (*RepoResult, error) {
	existing, _, err := c.gh.Repositories.Get(ctx, c.org, name)
	if err == nil {
		return &RepoResult{
			Name:     existing.GetName(),
			FullName: existing.GetFullName(),
			HTMLURL:  existing.GetHTMLURL(),
			CloneURL: existing.GetCloneURL(),
		}, nil
	}

	repo, _, err := c.gh.Repositories.Create(ctx, c.org, &gogithub.Repository{
		Name:        gogithub.String(name),
		Description: gogithub.String(description),
		Private:     gogithub.Bool(true),
		AutoInit:    gogithub.Bool(true),
	})
	if err != nil {
		return nil, fmt.Errorf("erro ao criar repo %s: %w", name, err)
	}

	if err := c.applyBranchProtection(ctx, name); err != nil {
		return nil, err
	}

	return &RepoResult{
		Name:     repo.GetName(),
		FullName: repo.GetFullName(),
		HTMLURL:  repo.GetHTMLURL(),
		CloneURL: repo.GetCloneURL(),
	}, nil
}

func (c *Client) applyBranchProtection(ctx context.Context, repoName string) error {
	_, _, err := c.gh.Repositories.UpdateBranchProtection(ctx, c.org, repoName, "main", &gogithub.ProtectionRequest{
		RequiredPullRequestReviews: &gogithub.PullRequestReviewsEnforcementRequest{
			RequiredApprovingReviewCount: 1,
		},
		RequiredStatusChecks: &gogithub.RequiredStatusChecks{
			Strict:   true,
			Contexts: &[]string{"build"},
		},
		EnforceAdmins: false,
	})
	return err
}

type CommitFileRequest struct {
	Repo    string
	Path    string
	Content string
	Message string
}

// CommitFile commita ou atualiza um arquivo no repo. Idempotente via SHA.
func (c *Client) CommitFile(ctx context.Context, req CommitFileRequest) error {
	existing, _, _, _ := c.gh.Repositories.GetContents(ctx, c.org, req.Repo, req.Path, nil)

	opts := &gogithub.RepositoryContentFileOptions{
		Message: gogithub.String(req.Message),
		Content: []byte(req.Content),
	}
	if existing != nil {
		opts.SHA = existing.SHA
	}

	_, _, err := c.gh.Repositories.CreateFile(ctx, c.org, req.Repo, req.Path, opts)
	if err != nil {
		return fmt.Errorf("erro ao commitar %s/%s: %w", req.Repo, req.Path, err)
	}
	return nil
}

type CreateTeamRequest struct {
	Name     string
	RepoName string
}

type TeamResult struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

func (c *Client) CreateTeam(ctx context.Context, req CreateTeamRequest) (*TeamResult, error) {
	team, _, err := c.gh.Teams.CreateTeam(ctx, c.org, gogithub.NewTeam{
		Name:    req.Name,
		Privacy: gogithub.String("closed"),
		RepoNames: []string{
			fmt.Sprintf("%s/%s", c.org, req.RepoName),
		},
	})
	if err != nil {
		return nil, fmt.Errorf("erro ao criar team: %w", err)
	}

	_, err = c.gh.Teams.AddTeamRepoBySlug(ctx, c.org, team.GetSlug(), c.org, req.RepoName, &gogithub.TeamAddTeamRepoOptions{
		Permission: "push",
	})
	if err != nil {
		return nil, fmt.Errorf("erro ao vincular repo ao team: %w", err)
	}

	return &TeamResult{
		ID:   team.GetID(),
		Name: team.GetName(),
		Slug: team.GetSlug(),
	}, nil
}
