package main

import (
	"fmt"
	"net/http"
	"os"

	"go.uber.org/zap"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/healthz"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	v1alpha1 "github.com/hugosleao/platform-api/api/v1alpha1"
	"github.com/hugosleao/platform-api/internal/audit"
	"github.com/hugosleao/platform-api/internal/controller"
	ghclient "github.com/hugosleao/platform-api/internal/github"
	"github.com/hugosleao/platform-api/internal/handlers"
	"github.com/hugosleao/platform-api/internal/middleware"
)

var scheme = runtime.NewScheme()

func init() {
	utilruntime.Must(v1alpha1.AddToScheme(scheme))
}

func main() {
	log, _ := zap.NewProduction()
	defer log.Sync()

	// ── GitHub Client (GitHub App JWT) ─────────────────────────────────────
	gh, err := ghclient.NewClient()
	if err != nil {
		log.Fatal("GitHub client falhou — configure GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY_PATH",
			zap.Error(err))
	}

	// ── Operator (controller-runtime) ─────────────────────────────────────
	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 scheme,
		HealthProbeBindAddress: ":8081",
		LeaderElection:         true,
		LeaderElectionID:       "platform-operator.devopstia.com",
	})
	if err != nil {
		log.Fatal("falha ao criar manager", zap.Error(err))
	}

	if err := (&controller.PlatformServiceReconciler{
		Client: mgr.GetClient(),
		Scheme: mgr.GetScheme(),
		GH:     gh,
		Log:    log,
	}).SetupWithManager(mgr); err != nil {
		log.Fatal("falha ao registrar PlatformServiceReconciler", zap.Error(err))
	}

	if err := (&controller.InfraRequestReconciler{
		Client: mgr.GetClient(),
		Scheme: mgr.GetScheme(),
		GH:     gh,
		Log:    log,
	}).SetupWithManager(mgr); err != nil {
		log.Fatal("falha ao registrar InfraRequestReconciler", zap.Error(err))
	}

	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		log.Fatal("falha ao adicionar healthz", zap.Error(err))
	}
	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		log.Fatal("falha ao adicionar readyz", zap.Error(err))
	}

	// ── REST API (para Backstage → Platform API) ───────────────────────────
	auditLog := audit.NewLogger(log)

	ghHandler := handlers.NewGitHubHandler(gh, auditLog)
	argoHandler := handlers.NewArgoCDHandler(gh, auditLog)
	cpHandler := handlers.NewCrossplaneHandler(gh, auditLog)
	auditHandler := handlers.NewAuditHandler(auditLog)

	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.RequestID)
	r.Use(middleware.BearerAuth)

	r.Get("/v1/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintln(w, `{"status":"ok","version":"2.0.0","mode":"operator"}`)
	})
	r.Handle("/metrics", promhttp.Handler())

	r.Route("/v1/github", func(r chi.Router) {
		r.Post("/repos", ghHandler.CreateRepo)
		r.Post("/teams", ghHandler.CreateTeam)
	})
	r.Route("/v1/argocd", func(r chi.Router) {
		r.Post("/apps", argoHandler.CreateApp)
	})
	r.Route("/v1/crossplane", func(r chi.Router) {
		r.Post("/claims", cpHandler.ApplyClaim)
	})
	r.Get("/v1/audit", auditHandler.List)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Sobe REST API em goroutine e operator no processo principal
	go func() {
		log.Info("REST API iniciada", zap.String("port", port))
		if err := http.ListenAndServe(":"+port, r); err != nil {
			log.Fatal("REST API encerrada", zap.Error(err))
		}
	}()

	log.Info("Platform Operator iniciado — aguardando CRDs")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		log.Fatal("operator encerrado", zap.Error(err))
	}
}
