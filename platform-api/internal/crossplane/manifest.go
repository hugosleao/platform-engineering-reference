package crossplane

import (
	"fmt"
	"strings"
)

type ClaimRequest struct {
	Sigla      string            `json:"sigla"`
	Name       string            `json:"name"`
	Namespace  string            `json:"namespace,omitempty"`
	Kind       string            `json:"kind"`
	Parameters map[string]string `json:"parameters,omitempty"`
}

type ClaimResult struct {
	Name    string `json:"name"`
	Kind    string `json:"kind"`
	Repo    string `json:"repo"`
	GitPath string `json:"git_path"`
	RepoURL string `json:"repo_url"`
	Status  string `json:"status"`
}

// RepoName deriva o nome do repo no padrão: {sigla}_iac-infra_cp-aws-{tipo}
func RepoName(sigla, kind string) string {
	return fmt.Sprintf("%s_iac-infra_cp-aws-%s", sigla, kindToShort(kind))
}

func RepoDescription(sigla, kind string) string {
	return fmt.Sprintf("Crossplane Claims — %s — AWS %s", strings.ToUpper(sigla), kind)
}

func GenerateManifest(req ClaimRequest) (content, gitPath string, err error) {
	ns := req.Namespace
	if ns == "" {
		ns = req.Sigla
	}
	if ns == "" {
		ns = "default"
	}

	params := buildParamsYAML(req.Parameters)
	gitPath = fmt.Sprintf("%s.yaml", req.Name)
	content = fmt.Sprintf(`apiVersion: platform.devopstia.com/v1alpha1
kind: %s
metadata:
  name: %s
  namespace: %s
  labels:
    platform.devopstia.com/sigla: %s
    platform.devopstia.com/managed-by: platform-operator
spec:
  deletionPolicy: Delete
%s`, req.Kind, req.Name, ns, req.Sigla, params)
	return
}

func kindToShort(kind string) string {
	switch kind {
	case "S3Bucket":
		return "s3"
	case "RDSInstance":
		return "rds"
	case "SQSQueue":
		return "sqs"
	default:
		return strings.ToLower(kind)
	}
}

func buildParamsYAML(params map[string]string) string {
	if len(params) == 0 {
		return ""
	}
	var sb strings.Builder
	for k, v := range params {
		fmt.Fprintf(&sb, "  %s: %q\n", k, v)
	}
	return sb.String()
}
