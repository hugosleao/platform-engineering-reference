package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// InfraRequestSpec define uma solicitação de infraestrutura AWS via Crossplane.
type InfraRequestSpec struct {
	// Sigla da squad (ex: xpto)
	Sigla string `json:"sigla"`
	// Kind do recurso Crossplane: S3Bucket, RDSInstance, SQSQueue
	Kind string `json:"kind"`
	// Nome do recurso
	ResourceName string `json:"resourceName"`
	// Parâmetros específicos do recurso
	Parameters map[string]string `json:"parameters,omitempty"`
}

// InfraRequestStatus descreve o estado da provisão.
type InfraRequestStatus struct {
	// Phase: Pending | Provisioning | Ready | Failed
	Phase string `json:"phase,omitempty"`
	// Repo GitHub criado para o claim
	RepoURL string `json:"repoURL,omitempty"`
	// Path do arquivo commitado no repo
	GitPath string `json:"gitPath,omitempty"`
	Message string `json:"message,omitempty"`
	LastReconciled *metav1.Time `json:"lastReconciled,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Kind",type=string,JSONPath=`.spec.kind`
// +kubebuilder:printcolumn:name="Sigla",type=string,JSONPath=`.spec.sigla`

// InfraRequest representa uma solicitação de recurso AWS.
// O operator cria o repo GitHub no padrão {sigla}_iac-infra_cp-aws-{tipo}
// e commita o Crossplane Claim para que o ArgoCD reaja via ApplicationSet.
type InfraRequest struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   InfraRequestSpec   `json:"spec,omitempty"`
	Status InfraRequestStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

type InfraRequestList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []InfraRequest `json:"items"`
}
