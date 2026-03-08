package argocd

import "fmt"

type AppRequest struct {
	Name       string `json:"name"`
	RepoURL    string `json:"repo_url"`
	Path       string `json:"path,omitempty"`
	Namespace  string `json:"namespace,omitempty"`
	GitopsRepo string `json:"gitops_repo,omitempty"`
	Sigla      string `json:"sigla,omitempty"`
}

type AppResult struct {
	Name    string `json:"name"`
	GitPath string `json:"git_path"`
	Status  string `json:"status"`
}

// envConfig mapeia ambiente → branch + namespace suffix
type envConfig struct {
	branch    string
	namespace string
}

var envMap = map[string]envConfig{
	"dev": {branch: "develop", namespace: "dev"},
	"hml": {branch: "release/*", namespace: "hml"},
	"prd": {branch: "master", namespace: "prd"},
}

// GenerateManifests gera um ArgoCD Application por ambiente (dev, hml, prd).
// Cada Application assiste uma branch diferente — GitFlow completo.
// feature/* e fix/* não têm Application — não são deployadas.
func GenerateManifests(req AppRequest) []GeneratedApp {
	var apps []GeneratedApp
	for env, cfg := range envMap {
		ns := fmt.Sprintf("%s-%s", req.Name, cfg.namespace)
		if req.Namespace != "" {
			ns = fmt.Sprintf("%s-%s", req.Namespace, cfg.namespace)
		}
		path := req.Path
		if path == "" {
			path = fmt.Sprintf("clusters/%s/services/%s", env, req.Name)
		}
		appName := fmt.Sprintf("%s-%s", req.Name, env)
		gitPath := fmt.Sprintf("argocd/apps/%s.yaml", appName)
		content := fmt.Sprintf(`apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: %s
  namespace: argocd
  labels:
    platform.devopstia.com/managed-by: platform-operator
    platform.devopstia.com/sigla: %s
    platform.devopstia.com/env: %s
spec:
  project: default
  source:
    repoURL: %s
    targetRevision: %s
    path: %s
  destination:
    server: https://kubernetes.default.svc
    namespace: %s
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
`, appName, req.Sigla, env, req.RepoURL, cfg.branch, path, ns)

		apps = append(apps, GeneratedApp{
			Name:    appName,
			GitPath: gitPath,
			Content: content,
			Env:     env,
		})
	}
	return apps
}

// GenerateManifest mantém compatibilidade — gera apenas DEV por padrão.
func GenerateManifest(req AppRequest) (content, gitPath string) {
	apps := GenerateManifests(req)
	for _, a := range apps {
		if a.Env == "dev" {
			return a.Content, a.GitPath
		}
	}
	return "", ""
}

type GeneratedApp struct {
	Name    string
	GitPath string
	Content string
	Env     string
}
