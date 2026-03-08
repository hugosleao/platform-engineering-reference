from src.adapters.repositories import InMemoryPessoaRepository
from src.domain.models.pessoa import Pessoa

class PessoaRepositoryPort():
    def __init__(self, pessoa_repository):
        self.pessoa_repository = pessoa_repository

    def salvar(self, nome: str, cpf: str):
        pessoa = Pessoa( nome, cpf)
        return self.pessoa_repository.salvar(pessoa)

    def buscar_por_cpf(self, cpf: str):
        return self.pessoa_repository.buscar_por_cpf(cpf)

    def listar(self):
        return self.pessoa_repository.listar()
    
    def excluir(self, pessoa:Pessoa):
        self.pessoa_repository.excluir(pessoa)