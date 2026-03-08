package controller

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	v1alpha1 "github.com/hugosleao/platform-api/api/v1alpha1"
	"github.com/hugosleao/platform-api/internal/crossplane"
	ghclient "github.com/hugosleao/platform-api/internal/github"
)

// InfraRequestReconciler reconcilia solicitações de infra AWS via Crossplane.
type InfraRequestReconciler struct {
	client.Client
	Scheme *runtime.Scheme
	GH     *ghclient.Client
	Log    *zap.Logger
}

// +kubebuilder:rbac:groups=platform.devopstia.com,resources=infrarequests,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=platform.devopstia.com,resources=infrarequests/status,verbs=get;update;patch

func (r *InfraRequestReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := r.Log.With(zap.String("resource", req.NamespacedName.String()))

	var ir v1alpha1.InfraRequest
	if err := r.Get(ctx, req.NamespacedName, &ir); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	if ir.Status.Phase == "Ready" {
		return ctrl.Result{RequeueAfter: 10 * time.Minute}, nil
	}

	log.Info("reconciling InfraRequest", zap.String("kind", ir.Spec.Kind))

	if err := r.setIRPhase(ctx, &ir, "Provisioning", "iniciando"); err != nil {
		return ctrl.Result{}, err
	}

	// 1. Garante repo no padrão {sigla}_iac-infra_cp-aws-{tipo}
	repoName := crossplane.RepoName(ir.Spec.Sigla, ir.Spec.Kind)
	repoDesc := crossplane.RepoDescription(ir.Spec.Sigla, ir.Spec.Kind)

	repoResult, err := r.GH.EnsureRepo(ctx, repoName, repoDesc)
	if err != nil {
		log.Error("erro ao garantir repo", zap.Error(err))
		return ctrl.Result{}, r.setIRPhase(ctx, &ir, "Failed", err.Error())
	}

	// 2. Gera e commita o Crossplane Claim
	content, gitPath, err := crossplane.GenerateManifest(crossplane.ClaimRequest{
		Sigla:      ir.Spec.Sigla,
		Name:       ir.Spec.ResourceName,
		Kind:       ir.Spec.Kind,
		Parameters: ir.Spec.Parameters,
	})
	if err != nil {
		return ctrl.Result{}, r.setIRPhase(ctx, &ir, "Failed", err.Error())
	}

	if err := r.GH.CommitFile(ctx, ghclient.CommitFileRequest{
		Repo:    repoName,
		Path:    gitPath,
		Content: content,
		Message: fmt.Sprintf("feat: add %s %s", ir.Spec.Kind, ir.Spec.ResourceName),
	}); err != nil {
		log.Error("erro ao commitar claim", zap.Error(err))
		return ctrl.Result{}, r.setIRPhase(ctx, &ir, "Failed", err.Error())
	}

	// 3. Atualiza status → Ready
	now := metav1.Now()
	ir.Status.Phase = "Ready"
	ir.Status.RepoURL = repoResult.HTMLURL
	ir.Status.GitPath = gitPath
	ir.Status.Message = fmt.Sprintf("claim commitado em %s/%s", repoName, gitPath)
	ir.Status.LastReconciled = &now

	if err := r.Status().Update(ctx, &ir); err != nil {
		return ctrl.Result{}, err
	}

	log.Info("InfraRequest reconciliado",
		zap.String("repo", repoResult.HTMLURL),
		zap.String("path", gitPath),
	)
	return ctrl.Result{RequeueAfter: 10 * time.Minute}, nil
}

func (r *InfraRequestReconciler) setIRPhase(ctx context.Context, ir *v1alpha1.InfraRequest, phase, message string) error {
	ir.Status.Phase = phase
	ir.Status.Message = message
	return r.Status().Update(ctx, ir)
}

func (r *InfraRequestReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&v1alpha1.InfraRequest{}).
		Complete(r)
}
