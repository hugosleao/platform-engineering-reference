package controller

import (
	"context"
	"fmt"
	"os"
	"time"

	"go.uber.org/zap"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	v1alpha1 "github.com/hugosleao/platform-api/api/v1alpha1"
	"github.com/hugosleao/platform-api/internal/argocd"
	"github.com/hugosleao/platform-api/internal/crossplane"
	ghclient "github.com/hugosleao/platform-api/internal/github"
)

// PlatformServiceReconciler implementa o Operator pattern para PlatformService.
// Ciclo: Observe → Diff → Act (escreve Git) → Update Status
type PlatformServiceReconciler struct {
	client.Client
	Scheme *runtime.Scheme
	GH     *ghclient.Client
	Log    *zap.Logger
}

// +kubebuilder:rbac:groups=platform.devopstia.com,resources=platformservices,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=platform.devopstia.com,resources=platformservices/status,verbs=get;update;patch

func (r *PlatformServiceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := r.Log.With(zap.String("resource", req.NamespacedName.String()))

	var svc v1alpha1.PlatformService
	if err := r.Get(ctx, req.NamespacedName, &svc); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Já está Ready e reconciliado recentemente — requeue em 5 min
	if svc.Status.Phase == "Ready" && svc.Status.LastReconciled != nil {
		since := time.Since(svc.Status.LastReconciled.Time)
		if since < 5*time.Minute {
			return ctrl.Result{RequeueAfter: 5*time.Minute - since}, nil
		}
	}

	log.Info("reconciling PlatformService", zap.String("phase", svc.Status.Phase))

	if err := r.setPhase(ctx, &svc, "Provisioning", "iniciando provisionamento"); err != nil {
		return ctrl.Result{}, err
	}

	// 1. Garante que o repo GitHub existe
	repoName := fmt.Sprintf("%s-%s", svc.Spec.Sigla, svc.Name)
	repoDesc := fmt.Sprintf("Serviço %s — time %s — runtime %s", svc.Name, svc.Spec.Team, svc.Spec.Runtime)
	repoResult, err := r.GH.EnsureRepo(ctx, repoName, repoDesc)
	if err != nil {
		log.Error("erro ao garantir repo", zap.Error(err))
		return ctrl.Result{}, r.setPhase(ctx, &svc, "Failed", err.Error())
	}
	log.Info("repo garantido", zap.String("repo", repoResult.HTMLURL))

	// 2. Commita ArgoCD Applications no gitops-repo — um por ambiente
	// develop → dev | release/* → hml | master → prd
	// feature/* e fix/* não recebem Application
	gitopsRepo := os.Getenv("GITOPS_REPO")
	if gitopsRepo == "" {
		gitopsRepo = "gitops-repo"
	}
	argoApps := argocd.GenerateManifests(argocd.AppRequest{
		Name:    svc.Name,
		RepoURL: repoResult.CloneURL,
		Sigla:   svc.Spec.Sigla,
	})
	for _, app := range argoApps {
		if err := r.GH.CommitFile(ctx, ghclient.CommitFileRequest{
			Repo:    gitopsRepo,
			Path:    app.GitPath,
			Content: app.Content,
			Message: fmt.Sprintf("feat: register argocd app %s", app.Name),
		}); err != nil {
			log.Error("erro ao commitar ArgoCD app", zap.String("app", app.Name), zap.Error(err))
			return ctrl.Result{}, r.setPhase(ctx, &svc, "Failed", err.Error())
		}
		log.Info("ArgoCD app registrada", zap.String("app", app.Name), zap.String("env", app.Env))
	}

	// 3. Provisiona recursos de infra (Crossplane Claims)
	provisioned := []string{}
	for _, res := range svc.Spec.InfraResources {
		repoInfra := crossplane.RepoName(svc.Spec.Sigla, res.Kind)
		repoDesc := crossplane.RepoDescription(svc.Spec.Sigla, res.Kind)

		if _, err := r.GH.EnsureRepo(ctx, repoInfra, repoDesc); err != nil {
			log.Error("erro ao garantir repo de infra", zap.String("repo", repoInfra), zap.Error(err))
			return ctrl.Result{}, r.setPhase(ctx, &svc, "Failed", err.Error())
		}

		params := make(map[string]string)
		for k, v := range res.Spec {
			params[k] = v
		}
		content, gitPath, err := crossplane.GenerateManifest(crossplane.ClaimRequest{
			Sigla:      svc.Spec.Sigla,
			Name:       res.Name,
			Kind:       res.Kind,
			Parameters: params,
		})
		if err != nil {
			return ctrl.Result{}, r.setPhase(ctx, &svc, "Failed", err.Error())
		}

		if err := r.GH.CommitFile(ctx, ghclient.CommitFileRequest{
			Repo:    repoInfra,
			Path:    gitPath,
			Content: content,
			Message: fmt.Sprintf("feat: add %s %s", res.Kind, res.Name),
		}); err != nil {
			return ctrl.Result{}, r.setPhase(ctx, &svc, "Failed", err.Error())
		}
		provisioned = append(provisioned, fmt.Sprintf("%s/%s", res.Kind, res.Name))
		log.Info("claim commitado", zap.String("kind", res.Kind), zap.String("name", res.Name))
	}

	// 4. Atualiza status → Ready
	now := metav1.Now()
	svc.Status.Phase = "Ready"
	svc.Status.RepoURL = repoResult.HTMLURL
	svc.Status.ArgoCDApp = svc.Name
	svc.Status.ProvisionedResources = provisioned
	svc.Status.Message = "provisionamento concluído via GitOps"
	svc.Status.LastReconciled = &now

	if err := r.Status().Update(ctx, &svc); err != nil {
		return ctrl.Result{}, err
	}

	log.Info("PlatformService reconciliado com sucesso",
		zap.String("repo", repoResult.HTMLURL),
		zap.Int("infra_resources", len(provisioned)),
	)
	return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}

func (r *PlatformServiceReconciler) setPhase(ctx context.Context, svc *v1alpha1.PlatformService, phase, message string) error {
	svc.Status.Phase = phase
	svc.Status.Message = message
	return r.Status().Update(ctx, svc)
}

func (r *PlatformServiceReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&v1alpha1.PlatformService{}).
		Complete(r)
}
