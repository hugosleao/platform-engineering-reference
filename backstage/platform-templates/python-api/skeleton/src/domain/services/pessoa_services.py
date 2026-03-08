from src.domain.ports.pessoa_repository_port import PessoaRepositoryPort
from src.exceptions.exceptions_pessoa import ExceptionPessoaJaCadastrada, ExcetionPessoaNaoEstaCadastrada

class PessoaService():
    def __init__(self, pessoa_repository_port:PessoaRepositoryPort):
        self.pessoa_repository_port = pessoa_repository_port

    def salvar (self, nome: str, cpf: str):
        pessoa = self.pessoa_repository_port.buscar_por_cpf(cpf)
        if pessoa is not None:
            raise ExceptionPessoaJaCadastrada(cpf)

        return self.pessoa_repository_port.salvar(nome, cpf)

    def buscar_por_cpf(self, cpf: str):
        return self.pessoa_repository_port.buscar_por_cpf(cpf)
    
    def listar(self):
        return self.pessoa_repository_port.listar()
    
    def excluir(self, cpf):
        pessoa = self.buscar_por_cpf(cpf)
        if pessoa is None :
            raise ExcetionPessoaNaoEstaCadastrada()
            
        self.pessoa_repository_port.excluir(pessoa)