package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// PlatformServiceSpec define o estado desejado de um serviço na plataforma.
type PlatformServiceSpec struct {
	// Nome do time dono do serviço
	Team string `json:"team"`
	// Linguagem/runtime (java, python, nodejs, golang)
	Runtime string `json:"runtime"`
	// Sigla da squad (ex: xpto)
	Sigla string `json:"sigla"`
	// Ambiente alvo inicial (dev, hml, prd)
	Environment string `json:"environment,omitempty"`
	// Recursos de infra solicitados (S3, RDS, SQS)
	InfraResources []InfraResource `json:"infraResources,omitempty"`
}

type InfraResource struct {
	Kind string            `json:"kind"` // S3Bucket, RDSInstance, SQSQueue
	Name string            `json:"name"`
	Spec map[string]string `json:"spec,omitempty"`
}

// PlatformServiceStatus descreve o estado real após reconciliação.
type PlatformServiceStatus struct {
	// Phase: Pending | Provisioning | Ready | Failed
	Phase string `json:"phase,omitempty"`
	// URL do repo criado no GitHub
	RepoURL string `json:"repoURL,omitempty"`
	// ArgoCD Application registrada
	ArgoCDApp string `json:"argoCDApp,omitempty"`
	// Recursos de infra provisionados
	ProvisionedResources []string `json:"provisionedResources,omitempty"`
	// Última mensagem de status
	Message string `json:"message,omitempty"`
	// Última reconciliação
	LastReconciled *metav1.Time `json:"lastReconciled,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Team",type=string,JSONPath=`.spec.team`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// PlatformService é o CRD central do vision-2026 operator.
// Um dev (via Backstage) cria esse recurso e o operator garante
// que tudo seja provisionado: repo GitHub, pipeline, ArgoCD App, infra Crossplane.
type PlatformService struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   PlatformServiceSpec   `json:"spec,omitempty"`
	Status PlatformServiceStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

type PlatformServiceList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []PlatformService `json:"items"`
}
