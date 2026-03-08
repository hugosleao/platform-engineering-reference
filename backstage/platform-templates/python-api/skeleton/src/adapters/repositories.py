from src.domain.models.pessoa import Pessoa


class InMemoryPessoaRepository():
    def __init__(self):
        self.database = []
    
    def salvar(self, pessoa:Pessoa):
        self.database.append(pessoa)
        return pessoa

    def buscar_por_cpf(self, cpf: str):
        for p  in self.database:
            if p.cpf == cpf:
                return p

        return None
    
    def listar(self):
        return self.database

    def excluir(self, pessoa:Pessoa):
        self.database.remove(pessoa)

