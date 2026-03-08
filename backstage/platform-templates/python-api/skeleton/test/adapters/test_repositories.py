import pytest
from src.domain.models.pessoa import Pessoa
from src.adapters.repositories import InMemoryPessoaRepository

@pytest.fixture(scope='function')
def pessoa_repository():
    return InMemoryPessoaRepository()

class  TestInMemoryPessoaRepository():
    @classmethod
    def setup_class(cls):
        cls.aline_nome = 'Aline da Silva'
        cls.aline_cpf = '139.649.293-36'
        cls.pessoa_aline = Pessoa(cls.aline_nome, cls.aline_cpf)
        cls.pessoa_joao = Pessoa("Joao", "762.263.731-99")

    def test_deve_retornar_sucesso_quando_cadastrar_pessoa(self, pessoa_repository):
        pessoa_cadastrada = pessoa_repository.salvar(self.pessoa_aline)
        
        assert pessoa_cadastrada is not None
        assert pessoa_cadastrada.cpf == self.aline_cpf
        assert pessoa_cadastrada.nome == self.aline_nome

    def test_deve_retornar_sucesso_quando_obter_pessoa_cadastrada_por_cpf(self, pessoa_repository):

        pessoa_repository.salvar(self.pessoa_aline)
        
        pessoa_encontrada:Pessoa = pessoa_repository.buscar_por_cpf(self.aline_cpf)
        assert pessoa_encontrada is not None
        assert pessoa_encontrada.cpf == self.aline_cpf

    def test_deve_retornar_sucesso_quando_obter_lista(self, pessoa_repository):
             
        pessoa_repository.salvar(self.pessoa_aline)
        pessoa_repository.salvar(self.pessoa_joao)

        pessoas = pessoa_repository.listar()
        assert len(pessoas) == 2     

    def test_deve_retornar_sucesso_quando_excluir_pessoa_cadastrada(self, pessoa_repository):
        
        pessoa_repository.salvar(self.pessoa_aline)
        pessoa_repository.salvar(self.pessoa_joao)

        pessoa_repository.excluir(self.pessoa_aline)

        pessoas = pessoa_repository.listar()
        assert len(pessoas) == 1     